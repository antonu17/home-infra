"""Adapted from .private/pinggy.py; credentials come only from the environment."""
import os
import re
import signal
import subprocess
import time
import httpx

TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
DELAY = int(os.environ.get("RECONNECT_DELAY", "10"))
TCP_RE = re.compile(r"tcp://([A-Za-z0-9.-]+):(\d+)")
COMMAND = ["ssh", "-o", "StrictHostKeyChecking=no",
           "-o", "UserKnownHostsFile=/dev/null",
           "-o", "GlobalKnownHostsFile=/dev/null", "-F", "/home/tunnel/.ssh/config", "-T", "-R",
           "0:127.0.0.1:2222", "pinggy"]


def telegram_api(method, **data):
    response = httpx.post(f"https://api.telegram.org/bot{TOKEN}/{method}",
                          data=data, timeout=15)
    # Exceptions can contain the token-bearing URL; do not log their details.
    if response.status_code != 200:
        raise RuntimeError(f"Telegram {method}: HTTP {response.status_code}")
    body = response.json()
    if not body.get("ok"):
        raise RuntimeError(f"Telegram {method}: API rejected request")
    return body["result"]


def get_chat_id():
    updates = telegram_api("getUpdates", timeout=0)
    for update in reversed(updates):
        message = (update.get("message") or update.get("edited_message")
                   or update.get("channel_post"))
        if message and "chat" in message:
            return message["chat"]["id"]
    raise RuntimeError("Send a message to the bot first")


def send_telegram(chat_id, message):
    telegram_api("sendMessage", chat_id=chat_id, text=message)


def run_tunnel(chat_id):
    process = subprocess.Popen(COMMAND, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)
    try:
        notified = False
        assert process.stdout is not None
        for line in process.stdout:
            # Emit only fixed diagnostic labels, never raw SSH output/config.
            for marker, label in (
                ("Permission denied", "SSH authentication or file permission denied"),
                ("Could not resolve hostname", "SSH hostname resolution failed"),
                ("Connection refused", "SSH connection refused"),
                ("Connection timed out", "SSH connection timed out"),
                ("Bad owner or permissions", "SSH config owner or permissions rejected"),
                ("Bad configuration option", "SSH config contains an unsupported option"),
                ("Host key verification failed", "SSH host key verification failed"),
                ("remote port forwarding failed", "SSH remote forwarding rejected"),
            ):
                if marker in line:
                    print(label, flush=True)
            match = TCP_RE.search(line)
            if notified or not match:
                continue
            host, port = match.groups()
            command = (f"ssh -o ForwardAgent=no -o HostKeyAlias=pinggy-bastion "
                       f"-p {port} tunnel@{host}")
            for attempt in range(3):
                try:
                    send_telegram(chat_id, f"SSH tunnel ready: {host}:{port}\n{command}")
                    notified = True
                    print("Tunnel endpoint delivered to Telegram", flush=True)
                    break
                except Exception as exc:
                    detail = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__
                    print(f"Telegram delivery failed: {detail}", flush=True)
                    if attempt < 2:
                        time.sleep(5)
            if not notified:
                raise RuntimeError("Could not notify tunnel endpoint")
        print(f"SSH tunnel exited ({process.wait()})", flush=True)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if process.stdout is not None:
            process.stdout.close()


def stop(signum, frame):
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        configured_chat = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
        chat_id = int(configured_chat) if configured_chat else None
        if chat_id is not None:
            print("Using Telegram chat configured via environment", flush=True)
        while True:
            try:
                if chat_id is None:
                    print("Discovering Telegram chat via getUpdates", flush=True)
                    chat_id = get_chat_id()
                    print("Telegram chat discovered", flush=True)
                print("Connecting to Pinggy via SSH", flush=True)
                run_tunnel(chat_id)
            except Exception as exc:
                detail = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__
                print(f"Tunnel attempt failed: {detail}; retrying", flush=True)
            time.sleep(DELAY)
    except KeyboardInterrupt:
        print("Tunnel stopped", flush=True)


if __name__ == "__main__":
    main()
