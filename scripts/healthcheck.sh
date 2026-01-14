#!/usr/bin/env bash
set -euo pipefail

echo "== hostname =="
hostnamectl --static || hostname

echo "== linger =="
loginctl show-user "$USER" -p Linger || true

echo "== containers =="
podman ps

echo "== traefik logs (tail 120) =="
podman logs --tail 120 traefik || true

echo "== ddns logs (tail 120) =="
podman logs --tail 120 cf-ddns || true

echo "== listening ports 80/443 =="
ss -lntp | egrep ':80|:443' || true

echo "== done =="
