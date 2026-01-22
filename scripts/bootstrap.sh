#!/usr/bin/env bash
set -euo pipefail

# Fresh-VM bootstrap helper for rootless Podman + Traefik compose setup.
# Safe to run multiple times.

echo "== Installing packages =="
sudo apt update
sudo apt install -y podman podman-compose uidmap slirp4netns fuse-overlayfs apache2-utils

echo "== Enable linger for user services =="
loginctl enable-linger "$USER" || true

echo "== Enable Podman API socket (user) =="
systemctl --user enable --now podman.socket

echo "== Create proxy network (if missing) =="
podman network exists proxy || podman network create proxy

echo "== Create runtime directories in ~/traefik =="
mkdir -p "$HOME/traefik"/{data,secrets,dynamic,certs}
chmod 700 "$HOME/traefik" "$HOME/traefik/secrets"

echo "== Ensure acme.json exists with correct perms =="
touch "$HOME/traefik/data/acme.json"
chmod 600 "$HOME/traefik/data/acme.json"

echo
echo "Bootstrap complete."
echo "Next:"
echo "  1) cp cf.env.example ~/traefik/cf.env && edit it"
echo "  2) htpasswd -nbB admin 'STRONG_PASSWORD' > ~/traefik/secrets/traefik.htpasswd"
echo "  3) (optional) copy home-arpa.crt/key into ~/traefik/certs/"
echo "  4) podman-compose up -d"
