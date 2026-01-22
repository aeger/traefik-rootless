# Traefik v3 (rootless Podman) for a Cloudflare-fronted homelab

This repo is a reproducible install + runbook for running **Traefik v3.x in rootless Podman on Ubuntu Server**, with **Cloudflare DNS-01 ACME** and (optionally) a MikroTik doing edge NAT/firewall.

You can treat this repo like a “I lost the VM, rebuild from scratch” kit:
- install base packages
- drop in your Cloudflare token + htpasswd
- start Traefik with `podman-compose`
- add more routes/services by editing YAML files

---

## What this repo gives you

- Rootless Traefik listening on **80/443** on the host (via `rootlessport`)
- Automatic Let’s Encrypt certs using **Cloudflare DNS challenge** (no inbound 80 needed for ACME)
- A secured dashboard at `https://traefik.<yourdomain>`:
  - IP allowlist
  - Basic auth via `usersfile` (no hashes in CLI args)
- Optional internal-only LAN reverse proxy (example: `crs309.home.arpa`) using the **file provider**
- A clean “Cloudflare-to-origin on 8443” pattern to survive ISP blocks:
  - Cloudflare connects to your public IP on 8443
  - MikroTik dst-nat 8443 → 443 on the host
  - Traefik terminates TLS on 443 and routes to containers

If you want the bigger picture (Traefik + cf-ddns + MikroTik + Cloudflare), see:
- `docs/homelab-ingress-overview.md`
- Cloudflare DDNS companion: https://github.com/aeger/Cloudflare-DDNS-Updater

---

## Prereqs

Target host:
- Ubuntu Server 24.04+
- Rootless Podman
- `uidmap`, `slirp4netns`, `fuse-overlayfs`
- `apache2-utils` (for `htpasswd`)
- `podman-compose` (we use Compose YAML to run Traefik)

Install:

```bash
sudo apt update
sudo apt install -y podman podman-compose uidmap slirp4netns fuse-overlayfs apache2-utils
```

Enable lingering (so user services survive logout/reboot):

```bash
loginctl enable-linger "$USER"
```

Enable the Podman API socket (Traefik uses it via `/var/run/docker.sock`):

```bash
systemctl --user enable --now podman.socket
```

Sanity check:

```bash
podman info | grep -i rootless
ls -la /run/user/$(id -u)/podman/podman.sock
```

---

## Files in this repo (new structure)

```text
traefik-rootless/
  compose.yml                      # NEW: canonical launcher (podman-compose)
  cf.env.example                   # Cloudflare token env file template
  README.md
  CHANGELOG.md
  LICENSE
  .github/workflows/...
  docs/
    homelab-ingress-overview.md
    compose-quickstart.md          # NEW
    lan-services.md                # NEW: how to add *.home.arpa routes
  mikrotik/
    ingress-8443-example.rsc
  scripts/
    bootstrap.sh                   # NEW: “fresh VM” bootstrap helper
  secrets/
    traefik.htpasswd.example
  dynamic/                         # NEW: file provider configs (routers/services/middlewares/tls)
    lan-middlewares.yml
    tls-home-arpa.yml
    crs309.yml                     # example LAN destination
    lan-service.template.yml       # copy/paste template for new destinations
  systemd/
    podman-compose@.service.example # NEW: optional autostart
  traefik.run.sh                   # Legacy runner (still here, but deprecated)
```

---

## 0) Clone the repo

```bash
git clone https://github.com/aeger/traefik-rootless
cd traefik-rootless
```

---

## 1) Create runtime directories

This repo is config. Runtime state lives in `~/traefik/`:

```bash
mkdir -p ~/traefik/{data,secrets,dynamic,certs}
chmod 700 ~/traefik ~/traefik/secrets
```

Create the ACME store file (Traefik requires it to exist and be writable):

```bash
touch ~/traefik/data/acme.json
chmod 600 ~/traefik/data/acme.json
```

---

## 2) Cloudflare API token (DNS-01)

Cloudflare Dashboard → API Tokens → Create Token

Permissions:
- Zone → DNS → Edit
- Zone → Zone → Read

Scope:
- Zone: `yourdomain.tld`

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

This network is where Traefik and your proxied containers meet.

```bash
podman network exists proxy || podman network create proxy
```

---

## 5) TLS for `*.home.arpa` (optional, for LAN-only names)

If you want internal names like `crs309.home.arpa`, you need a cert that covers them.

The included example expects these files on the host:

```text
~/traefik/certs/home-arpa.crt
~/traefik/certs/home-arpa.key
```

Generate with `mkcert` on a trusted workstation if you want, then copy them over.
(Or use your own CA. The point is: browsers must trust it.)

---

## 6) Start Traefik with Compose (recommended)

The `compose.yml` is designed to be edited safely:
- set your public dashboard hostname
- set your ACME email
- keep paths consistent

Start:

```bash
podman-compose up -d
podman ps --filter name=traefik
```

Logs:

```bash
podman logs traefik --tail=200
```

Dashboard:

```text
https://traefik.az-lab.dev/
```

---

## 7) Add LAN destinations (`*.home.arpa`)

Copy the template and edit it:

```bash
cp dynamic/lan-service.template.yml ~/traefik/dynamic/mydevice.yml
nano ~/traefik/dynamic/mydevice.yml
podman restart traefik
```

Full guide: `docs/lan-services.md`

---

## Notes and gotchas (because reality is rude)

### “curl -I” returns 400 but browser works
Some embedded device web UIs behave badly with `HEAD /` requests.
`curl -I` uses HEAD. Browsers use GET.

Use:

```bash
curl -k https://crs309.home.arpa/ -o /dev/null -v
```

instead of `-I` if you’re sanity-checking.

### Rootless source IP and allowlists
Rootless networking can make Traefik see client IPs like `10.89.0.x`.
That’s why the allowlist includes both LAN ranges *and* your rootless subnet.

If you change your Podman network/subnet, update `dynamic/lan-middlewares.yml`.

---

## Legacy runner

`traefik.run.sh` is still present for reference, but Compose is now the canonical way.

If you want a systemd user service to auto-start the Compose stack, see:
- `systemd/podman-compose@.service.example`
