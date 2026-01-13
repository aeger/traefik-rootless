# Homelab ingress overview (Cloudflare + MikroTik + Traefik + rootless Podman)

This doc ties together the moving parts so you don’t have to re-learn them at 2am.

## Components

- **Cloudflare DNS**: public records (`A`/`CNAME`) for your homelab domain
- **Cloudflare proxy**: terminates client TLS, forwards to your origin
- **Cloudflare Origin Rule**: rewrites origin port (e.g. 8443) so you can dodge ISP blocks
- **MikroTik (RB5009)**: dst-nat + firewall policy enforcing “only Cloudflare may talk to origin”
- **Traefik (rootless Podman)**: reverse proxy + ACME DNS-01 + service discovery via Podman socket
- **Workloads**: containers with Traefik labels (Portainer, AMP, etc.)
- **DDNS updater** (optional): keeps Cloudflare `A` records pointing at your changing public IP

Related repos:
- Traefik rootless runbook: https://github.com/aeger/traefik-rootless
- Cloudflare DDNS updater: https://github.com/aeger/Cloudflare-DDNS-Updater

## Traffic flow

### Public ingress (recommended)

```mermaid
flowchart LR
  U[Internet User] --> CF[Cloudflare Edge<br/>TLS 443]
  CF -->|Origin Rule: port 8443| ISP[(Your Public IP:8443)]
  ISP --> MT[MikroTik RB5009<br/>dst-nat 8443->443]
  MT --> T[Traefik (rootless)<br/>:443 websecure]
  T --> S[Container Services]
```

### Why 8443?

Because ISPs love playing gatekeeper with 80/443. Cloudflare can still reach you on whatever port you expose, and your clients will never know.

## Security model

1. **No direct WAN 80/443** to your LAN.
2. **Only Cloudflare IPs** may reach your origin port (8443) via MikroTik forward rules.
3. Traefik issues **real Let’s Encrypt certs** via **DNS-01** (no inbound HTTP challenge needed).
4. Dashboard is protected by:
   - IP allowlist (your LAN + VPN)
   - Basic auth (usersfile)
5. Everything runs rootless where possible.

## Operational notes

### Cert issuance vs Cloudflare SSL mode

- If Cloudflare is set to **Full (strict)** but Traefik is still serving its **default** self-signed cert for that hostname, Cloudflare returns **526**.
- Fix is always the same:
  - make sure Traefik has a router for that hostname
  - ensure the router uses `tls.certresolver=le`
  - confirm the request reaches Traefik (MikroTik counters + host tcpdump)

### DDNS and “proxied” records

If you use the DDNS updater, set your records (e.g. `@`, `*`, `traefik`, `amp`) to proxied. Your clients still hit Cloudflare, not your origin IP directly.

## Debug checklist (fast)

- Cloudflare:
  - Is the record proxied?
  - Does the origin rule match the hostname and set port 8443?
  - SSL mode Full vs Full (strict)?
- MikroTik:
  - dst-nat counter increments?
  - forward accept rule increments (Cloudflare list)?
  - conntrack shows established?
- Host:
  - `ss -lntp | egrep ':(80|443|8080)'` shows rootlessport
  - `tcpdump -ni <iface> 'tcp port 443'` shows inbound SYN from MikroTik
- Traefik:
  - `podman logs traefik | egrep -i 'acme|error|certificate'`
  - `curl -vk --resolve host:443:LANIP https://host/ | egrep -i 'subject:|issuer:'`
