# Homelab Ingress Overview (Rootless Podman + Traefik v3 + Cloudflare + MikroTik)

This document describes the ingress design for this homelab: how public traffic reaches internal services using **Traefik v3** running in **rootless Podman** on Ubuntu, secured with **Cloudflare DNS-01 ACME**, kept reachable via a **Cloudflare DDNS updater container**, and exposed from the edge using a **MikroTik RB5009** router.

It also documents the operational model: **systemd user services** generated from Podman, enabled via **linger**, so everything is resilient across reboots without running containers as root.

---

## TL;DR Architecture

- **Public Internet**
  - Users browse `https://service.example.com`
- **Cloudflare**
  - Authoritative DNS for domain
  - `A` record points to home WAN IP (updated by DDNS container)
  - ACME DNS-01 challenges handled via API token
- **Home WAN**
  - MikroTik RB5009 forwards ports (80/443) to ingress host
- **Ingress Host (Ubuntu, Podman rootless)**
  - Traefik v3 terminates TLS, routes to internal services
  - Certificates issued via Cloudflare DNS-01
- **Internal services**
  - Podman containers behind Traefik
  - Optional LAN services routed via Traefik

---

## Components

### Traefik v3
- Reverse proxy and TLS termination
- ACME DNS-01 with Cloudflare
- Container discovery via Podman socket
- EntryPoints: `web`, `websecure`

Repo: https://github.com/aeger/traefik-rootless

### Cloudflare DNS-01
- Enables wildcard and non-HTTP certificate issuance
- Requires scoped Cloudflare API token

### Cloudflare DDNS Updater
- Keeps DNS `A` record synced with changing WAN IP
- Runs as rootless Podman container

Repo: https://github.com/aeger/Cloudflare-DDNS-Updater

### MikroTik RB5009
- WAN edge router
- NAT port forwards for 80/443
- Optional hairpin NAT for internal access

### Rootless Podman + systemd user services
- Containers run unprivileged
- systemd user units generated via Podman
- `loginctl enable-linger` ensures startup at boot

---

## Traffic Flow

### External HTTPS Request
1. Client resolves DNS via Cloudflare
2. Traffic hits WAN IP
3. MikroTik forwards to ingress host
4. Traefik terminates TLS
5. Request routed to backend service
6. Response returns upstream

### Certificate Issuance (DNS-01)
1. Traefik requests cert
2. TXT record created via Cloudflare API
3. Let’s Encrypt validates DNS
4. Cert stored locally
5. TXT record removed

### WAN IP Change
1. ISP assigns new IP
2. DDNS container detects change
3. Cloudflare record updated
4. New connections resolve correctly

---

## Host Requirements

- Ubuntu with rootless Podman
- systemd user services enabled
- Linger enabled for user
- Inbound 443 permitted

### Privileged Ports
Binding 80/443 in rootless mode requires one of:
- `net.ipv4.ip_unprivileged_port_start`
- authbind
- router-level port translation

---

## Repository Responsibilities

### traefik-rootless
- Traefik container definition
- Static and dynamic config
- ACME storage
- systemd unit generation
- Label examples

### Cloudflare-DDNS-Updater
- Updater container
- Environment variables and secrets
- systemd unit generation

---

## Suggested Directory Layout

```
~/containers/
  traefik/
    traefik.yml
    dynamic/
    acme/
      acme.json
    logs/
  ddns/
    .env
```

---

## systemd User Service Pattern

- Create container with Podman
- Generate unit:
  `podman generate systemd --new --files --name <container>`
- Move to:
  `~/.config/systemd/user/`
- Enable:
  `systemctl --user enable --now <service>`
- Enable linger:
  `sudo loginctl enable-linger <user>`

---

## Security Notes

- Use scoped Cloudflare API tokens
- Protect or disable Traefik dashboard
- Enforce HTTPS-only access
- Apply security headers and rate limits

---

## Failure Scenarios

- DDNS failure: stale WAN IP
- ACME token failure: cert renewal breaks
- Missing port forwards: no ingress
- Socket issues: Traefik can’t see containers

---

## References

- Traefik Rootless: https://github.com/aeger/traefik-rootless
- Cloudflare DDNS Updater: https://github.com/aeger/Cloudflare-DDNS-Updater

---

## Notes to Future You

- Document privileged port handling clearly
- Back up `acme.json` securely
- Don’t expose dashboards publicly
