# Homelab Ingress Overview (rootless Podman + Traefik v3)

**Host (VM):** `svc-podman-01` (formerly `svc-docker-01`)  
**Platform:** Proxmox VM → Ubuntu (rootless Podman)  
**Ingress:** Traefik v3 (rootless) + Cloudflare DNS-01 ACME  
**DDNS:** Cloudflare DDNS Updater container (rootless)

This document ties together the moving pieces so Future-You doesn't have to rediscover them at 1:12 AM.

---

## Architecture (high level)

- **Edge router:** MikroTik RB5009
- **Public DNS:** Cloudflare
- **TLS certificates:** Traefik + ACME via Cloudflare DNS-01 challenge
- **Ingress proxy:** Traefik (rootless Podman) publishing **80/443**
- **Service discovery:** container labels / static dynamic-config (depending on your setup)
- **Dynamic public IP:** Cloudflare DDNS updater container keeps your Cloudflare A/AAAA record current

---

## Important operational choice: systemd units vs Podman restart policy

There are two common ways to keep rootless containers running across reboots:

### Option A (Podman-native): use restart policies (what you're currently doing)
- Containers restart via Podman, not via systemd user units.
- `systemctl --user status container-traefik` will **not** exist unless you generated units.

**Health checks:**
```bash
podman ps
ss -lntp | egrep ':80|:443'
podman logs --tail 200 traefik
```

You may see `rootlessport` listening on 80/443, which is normal for rootless low-port publishing:
```bash
ss -lntp | egrep ':80|:443'
# ... users:(("rootlessport",pid=...,fd=...))
```

### Option B (systemd-user): generate and enable user units
This gives you `container-traefik.service` and consistent lifecycle control.

**Generate unit:**
```bash
podman generate systemd --name traefik --files --new
```

**Install it:**
```bash
mkdir -p ~/.config/systemd/user
mv container-traefik.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now container-traefik
```

**Then you can manage it like:**
```bash
systemctl --user status container-traefik
journalctl --user -u container-traefik -n 200 --no-pager
```

> Pick one approach and stick with it. Running restart policies *and* systemd units for the same container is how you get confusing startup races.

---

## Rootless low ports (80/443)

If you're binding privileged ports as a non-root user, you need one of the standard approaches:
- `net.ipv4.ip_unprivileged_port_start=0` (system-wide sysctl), or
- host-level port forwarding (80/443 → high ports), or
- authbind/cap tricks depending on your distro

**Quick verification:**
```bash
ss -lntp | egrep ':80|:443'
```

---

## Cloudflare DNS-01 (ACME)

Traefik obtains certificates via Cloudflare API using DNS-01, so it can validate without exposing a special HTTP path.

Typical requirements:
- Cloudflare API token with the correct DNS permissions for your zone
- Traefik configured with the Cloudflare DNS challenge provider
- Persistent storage for ACME state (e.g., `acme.json`) so certs survive restarts

**Sanity checks:**
```bash
podman logs --tail 200 traefik | egrep -i 'acme|dns|challenge|cert|error'
podman inspect traefik --format '{{json .Mounts}}'
```

---

## Cloudflare DDNS updater

Runs as its own rootless container and updates the desired Cloudflare record when your WAN IP changes.

**Sanity checks:**
```bash
podman ps
podman logs --tail 200 cf-ddns
```

---

## Rename note (svc-docker-01 → svc-podman-01)

Renaming the VM and the guest hostname generally does **not** break Traefik, because:
- Traefik routes based on Host rules / labels, not the node hostname.
- Rootless Podman state lives under the user, not tied to hostname.

Things that *can* break:
- internal DNS entries pointing at the old hostname
- SSH config entries / known_hosts labels
- any docs/scripts/Ansible inventories referencing `svc-docker-01`

---

## Quick “everything is fine” check

Run as the rootless Podman user:

```bash
echo "== hostname =="; hostnamectl --static
echo "== linger =="; loginctl show-user "$USER" -p Linger
echo "== containers =="; podman ps
echo "== traefik logs =="; podman logs --tail 80 traefik
echo "== ports =="; ss -lntp | egrep ':80|:443' || true
```

Last updated: 2026-01-13.
