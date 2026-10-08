FROM python:3.13.7-alpine3.22
RUN apk add --no-cache openssh-client openssh-server bash su-exec ca-certificates \
    && pip install --no-cache-dir httpx==0.28.1 \
    && addgroup -g 10001 tunnel \
    && adduser -D -u 10001 -G tunnel -h /home/tunnel tunnel \
    && passwd -d tunnel \
    && mkdir -p /var/lib/ssh-host-keys /run/sshd /mnt/ssh \
    && ln -s /run/pinggy/ssh /home/tunnel/.ssh
COPY sshd_config /etc/ssh/sshd_config
ENV HOME=/home/tunnel PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
CMD ["bash", "/app/start.sh"]
