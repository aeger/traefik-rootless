# Traefik v3 (rootless Podman) for a Cloudflare-fronted homelab

This repo is the **reproducible install + runbook** for running **Traefik v3.x** in **rootless Podman** on Ubuntu Server, with **Cloudflare DNS-01 ACME** and a **MikroTik** doing the edge NAT/firewall.

It’s designed for the reality of residential ISPs (ports blocked, flaky inbound) and for people who prefer their “ingress” to not be a surprise security incident.

---

## What this repo gives you

- Rootless Traefik listening on **80/443** on the host (via `rootlessport`)
- Automatic Let’s Encrypt certs using **Cloudflare DNS challenge** (no inbound 80 needed for ACME)
- A **secured dashboard** at `https://traefik.<yourdomain>`:
  - IP allowlist
  - Basic auth via `usersfile` (no hashes in CLI args)
- A clean “Cloudflare-to-origin on 8443” pattern to survive ISP blocks:
  - Cloudflare connects to your public IP on **8443**
  - MikroTik dst-nat **8443 → 443** on the host
  - Traefik terminates TLS on 443 and routes to containers

---

## Architecture (the important bit)

**WAN flow (recommended):**

```
Internet client → Cloudflare (443)
               → Cloudflare Origin Rule sets origin port 8443
               → Your public IP:8443
               → MikroTik dst-nat 8443 → 192.168.1.181:443
               → Traefik (rootless) websecure → containers
```

**LAN flow (hairpin, optional):**

```
LAN client → MikroTik hairpin dst-nat 8443 → 192.168.1.181:443
          → (src-nat masquerade) → Traefik → containers
```

If you want the bigger picture (Traefik + cf-ddns + MikroTik + Cloudflare), see:
- [`docs/homelab-ingress-overview.md`](docs/homelab-ingress-overview.md)
- Cloudflare DDNS companion: https://github.com/aeger/Cloudflare-DDNS-Updater

---

## Prereqs

Target host:
- Ubuntu Server **24.04+**
- Rootless Podman
- `uidmap`, `slirp4netns`, `fuse-overlayfs`
- `apache2-utils` (for `htpasswd`)

Install:

```bash
sudo apt update
sudo apt install -y podman uidmap slirp4netns fuse-overlayfs apache2-utils
```

Enable lingering (so user services/containers survive logout/reboot):

```bash
loginctl enable-linger "$USER"
```

Sanity check:

```bash
podman info | grep -i rootless
```

---

## Files in this repo

```
traefik-rootless/
  README.md
  traefik.run.sh
  cf.env.example
  secrets/
    traefik.htpasswd.example
  mikrotik/
    ingress-8443-example.rsc
  docs/
    homelab-ingress-overview.md
  systemd/
    traefik.container          # Podman Quadlet (recommended autostart)
  .github/workflows/
    shellcheck.yml
  CHANGELOG.md
  LICENSE
```

---

## 1) Create directories

```bash
mkdir -p ~/traefik/{data,secrets}
chmod 700 ~/traefik ~/traefik/secrets
```

---

## 2) Cloudflare API token (DNS-01)

Cloudflare Dashboard → **API Tokens** → Create Token

Permissions:
- Zone → DNS → **Edit**
- Zone → Zone → **Read**

Scope:
- Zone: `yourdomain.tld`

Save the token somewhere safe (not your clipboard history, ideally).

Create your env file:

```bash
cp cf.env.example ~/traefik/cf.env
nano ~/traefik/cf.env
chmod 600 ~/traefik/cf.env
```

---

## 3) Dashboard auth (BasicAuth usersfile)

Generate a bcrypt htpasswd entry:

```bash
htpasswd -nbB admin 'STRONG_PASSWORD' > ~/traefik/secrets/traefik.htpasswd
chmod 600 ~/traefik/secrets/traefik.htpasswd
```

---

## 4) Shared proxy network

```bash
podman network create proxy
```

---

## 5) Run Traefik (manual)

This is the “works now” path. It’s also what you’ll use for quick changes.

```bash
bash ./traefik.run.sh
```

> `traefik.run.sh` assumes:
> - `~/traefik/cf.env` exists
> - `~/traefik/data` exists and is writable
> - `~/traefik/secrets/traefik.htpasswd` exists

---

## 6) Verify (LAN)

Certificate check (forces SNI + routes like the internet would):

```bash
curl -vk --resolve traefik.yourdomain.tld:443:192.168.1.181 https://traefik.yourdomain.tld/ 2>&1 | egrep -i "subject:|issuer:"
```

Dashboard:

```bash
curl -vk --resolve traefik.yourdomain.tld:443:192.168.1.181 https://traefik.yourdomain.tld/
```

---

## 7) MikroTik rules (ingress via 8443)

Import example script and adapt it:

- `mikrotik/ingress-8443-example.rsc`

The intent:
- **dst-nat WAN tcp/8443 → 192.168.1.181:443**
- optional hairpin for LAN
- firewall allow: **Cloudflare IPs → dstnat → 443**
- firewall drop: everyone else trying to hit that dstnat

Cloudflare IP lists change over time. Don’t hardcode once and forget. (Humans love forgetting.)

---

## 8) Cloudflare settings

### DNS
Create these as **proxied** (orange cloud):
- `traefik.yourdomain.tld` → A record to your public IP (or use the DDNS updater repo)

### Origin Rule (key)
Cloudflare → Rules → Origin Rules

“If hostname ends with `yourdomain.tld` → set origin port **8443**”

### SSL/TLS mode
- Temporary: **Full**
- Final: **Full (strict)** (after Traefik has issued a valid cert)

If you see Cloudflare **526**, it’s not “down”, it’s Cloudflare refusing your origin cert. That’s either:
- Traefik still serving the default cert for that hostname, or
- the router rule isn’t matching, or
- the request isn’t reaching Traefik at all.

---

## 9) Autostart properly (Quadlet)

`--restart=unless-stopped` only works if lingering is enabled and your user session is brought up properly.

For “headless and predictable”, use Podman Quadlet.

Install the unit:

```bash
mkdir -p ~/.config/containers/systemd
cp systemd/traefik.container ~/.config/containers/systemd/traefik.container
systemctl --user daemon-reload
systemctl --user enable --now traefik.service
```

Logs:

```bash
journalctl --user -u traefik -f
```

---

## Common mistakes (aka “things humans do”)

- **Wrong Host rule quoting**: Traefik’s router rule uses backticks:
  - ✅ `Host(\`traefik.yourdomain.tld\`)`
  - ❌ `Host('traefik.yourdomain.tld')` (this triggers “illegal rune literal”)
- **acme.json permissions** must be `600` and writable by the container.
- **Cloudflare DNS token** must have Zone Read + DNS Edit for the right zone.
- **No route = default cert**: if your router rule doesn’t match, you’ll see `TRAEFIK DEFAULT CERT`.

---

## Updating Traefik

```bash
podman pull docker.io/traefik:v3.1
podman restart traefik
```

If you’re using Quadlet, restarting the service is fine:

```bash
systemctl --user restart traefik
```

---

## License

MIT. Because life is short and lawyers are exhausting.
