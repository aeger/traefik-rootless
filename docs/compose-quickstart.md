# Compose quickstart

This repo now uses `podman-compose` + a canonical `compose.yml` for Traefik.

## Why
A shell “runner” works, until copy/paste, line continuation, or a single quote turns your day into performance art.

Compose gives you:
- a stable, reviewable YAML
- easier updates
- fewer “why is /run/user/${UID} literally not expanded?” moments

## TL;DR
From repo root:

```bash
mkdir -p ~/traefik/{data,secrets,dynamic,certs}
touch ~/traefik/data/acme.json
chmod 600 ~/traefik/data/acme.json

cp cf.env.example ~/traefik/cf.env
nano ~/traefik/cf.env
chmod 600 ~/traefik/cf.env

htpasswd -nbB admin 'STRONG_PASSWORD' > ~/traefik/secrets/traefik.htpasswd
chmod 600 ~/traefik/secrets/traefik.htpasswd

podman network exists proxy || podman network create proxy
systemctl --user enable --now podman.socket

podman-compose up -d
```

## First run sanity checks

```bash
podman ps --filter name=traefik
podman logs traefik --tail=200
curl -I http://127.0.0.1
curl -Ik https://127.0.0.1/ -H "Host: traefik.az-lab.dev"
```

If `curl -I` against a LAN device route returns 400, try GET instead. Some embedded UIs hate HEAD.


## Autostart on reboot (rootless)

Rootless stacks only auto-start on boot if your *user systemd* is running. That requires **linger**.

```bash
sudo loginctl enable-linger $USER
systemctl --user enable --now podman.socket

# Option A: dedicated unit
mkdir -p ~/.config/systemd/user
cp systemd/compose-traefik.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now compose-traefik.service

# Option B: template unit (recommended if you have multiple stacks)
cp systemd/compose-stack@.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now compose-stack@traefik.service
```
