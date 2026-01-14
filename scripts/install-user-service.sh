#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[*] Creating directories..."
mkdir -p "${HOME}/.config/systemd/user"
mkdir -p "${HOME}/traefik/data" "${HOME}/traefik/secrets"

echo "[*] Copying unit..."
cp -v "${HERE}/systemd/traefik.service" "${HOME}/.config/systemd/user/traefik.service"

echo "[*] Ensuring proxy network exists..."
podman network exists proxy 2>/dev/null || podman network create proxy >/dev/null

echo "[*] Enabling linger (sudo once)..."
sudo loginctl enable-linger "${USER}"

echo "[*] Reloading and enabling Traefik..."
systemctl --user daemon-reload
systemctl --user enable --now traefik.service

echo
systemctl --user --no-pager status traefik.service || true
