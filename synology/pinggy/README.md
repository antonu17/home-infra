# Pinggy SSH container

Prepared project; deployment is operator-run. The container runs its own
OpenSSH server and a Pinggy client. Incoming connections authenticate to the
container account `tunnel`, not DSM. Local forwarding and ProxyJump can reach
home services allowed by the NAS network. No host ports are published and no
host network, Docker socket or NAS data directories are mounted.

The adapted Python script reads TELEGRAM_BOT_TOKEN from the environment,
uses TELEGRAM_CHAT_ID when set, otherwise discovers chat ID using getUpdates,
sends the endpoint and login
command to Telegram, and reconnects after disconnects. The private original is
unchanged. Send a message to the bot before startup. Use a dedicated bot:
the latest eligible message determines the destination. Another update consumer
or an active webhook can prevent discovery; no manual chat ID is required.
The chosen chat is retained until the process restarts.

## Configuration

Upload the project to a directory of your choice on the NAS. Create the private
environment file from the supplied example and fill the Telegram token and,
optionally, TELEGRAM_CHAT_ID. A configured ID skips getUpdates on every restart.
Create the SSH client configuration from its example. Add your work computer's
public login key to authorized_keys in the mounted SSH directory. Private login keys stay on the
work computer. Existing client keys/config can also be mounted, but the
container user will then be able to read them.

The read-only SSH source is copied at startup into temporary container storage.
Only the copy receives container user ownership and restrictive permissions;
NAS ownership and ACLs remain untouched. The container supervisor must be able
to read the source as root. Supply regular files and directories without symlinks.
Client config directives must use the corresponding container filenames.
The Pinggy client automatically accepts server keys without prompting and does
not require or persist known_hosts. These options apply only to the outbound
Pinggy connection and override an existing client config. Pinggy server identity
is not verified. Verify the container SSH server key from the work computer as
described below; that check remains independent.

SSH server host keys are generated once in a persistent named volume. Keep this
volume across updates so client identity remains stable. Password and root login
are disabled. The supervisor starts sshd with the limited capabilities needed
for user switching and privilege separation; the tunnel script and SSH sessions
run as the unprivileged account. SSH sessions have an ephemeral writable temp
directory; the rest of the container filesystem is read-only.

## Get Telegram chat ID

With uv installed, send a new message (for example /start) to your bot in the
chat that should receive notifications. Paste this block into zsh on your Mac.
uv installs httpx automatically. Token input is hidden; only chat IDs and types
are printed.

```sh
uv run --script - <<'PY'
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx==0.28.1"]
# ///

import getpass
import httpx

token = getpass.getpass("Telegram bot token: ").strip()
try:
    response = httpx.post(
        f"https://api.telegram.org/bot{token}/getUpdates",
        data={"timeout": 0}, timeout=15,
    )
    body = response.json()
    if not body.get("ok"):
        print(f"Telegram API error: HTTP {response.status_code}")
    else:
        chats = {}
        for update in body.get("result", []):
            message = (update.get("message") or update.get("edited_message")
                       or update.get("channel_post"))
            if message and "chat" in message:
                chat = message["chat"]
                chats[chat["id"]] = chat.get("type", "")
        for chat_id, kind in chats.items():
            print(f"TELEGRAM_CHAT_ID={chat_id}  # {kind}")
        if not chats:
            print("No messages. Send a new message to your bot and retry.")
except Exception:
    print("Request failed; details hidden to avoid exposing the token.")
PY
```

Add TELEGRAM_CHAT_ID with the intended chat's ID to the private .env beside the
Compose file. Preserve the minus sign for negative IDs. Another update consumer
or an active webhook can prevent lookup through getUpdates; see the
[Telegram API documentation](https://core.telegram.org/bots/api#getupdates).

After editing .env, run this OPERATOR-RUN LIVE CHANGE from the project directory
on the NAS to update the container environment:

```sh
docker compose -p pinggy up -d
```

A plain restart does not reload .env. With a configured ID, the tunnel script
skips getUpdates at startup.

## Operator-run deployment

Run these commands from the uploaded project directory. First validate without
printing interpolated secrets:

```sh
docker compose -p pinggy config --quiet
```

LIVE CHANGE — build and start this project:

```sh
docker compose -p pinggy up -d --build
```

Check status and logs:

```sh
docker compose -p pinggy ps
docker compose -p pinggy logs --tail=30 pinggy
```

Before accepting the first client connection, inspect the persisted server public
key fingerprint through your trusted NAS session and compare it with the client
prompt. The server key location is defined in the supplied SSH server config.

Use the command delivered by Telegram. Confirm login reaches the container and
required home services are reachable. A running process alone is not proof of
successful access. The work network must permit the allocated public TCP port.
If notifications fail, check the bot's pending messages, webhook and token
privately. Never share token-bearing API exceptions or rendered environment.

Script and SSH configuration directories are bind-mounted read-only. At startup,
the supervisor copies the Python script into temporary runtime storage with read
permission for the container user, preserving NAS ownership and ACLs. SSH material is also copied with private permissions for that user. After edits,
LIVE CHANGE — reload by restarting this project's container:

```sh
docker compose -p pinggy restart pinggy
```

Rebuild after dependency changes. The restart policy restores service after a
NAS/Docker restart unless explicitly stopped. The NAS remains the failure domain.

## Stop / rollback

LIVE CHANGE — remove this project's container and network, preserving bind mounts
and the named host-key volume:

```sh
docker compose -p pinggy down
```

Do not remove volumes if retaining the SSH identity. Private environment and SSH
material are excluded from Git and the build context. No DSM SSH configuration,
Kubernetes resources, router rules or other projects are changed by these commands.
