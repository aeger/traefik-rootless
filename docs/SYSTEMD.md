# systemd (user) service for Traefik rootless Podman

This adds a reproducible systemd **user** unit for Traefik v3 on rootless Podman.

## Files you must provide on the host
- `~/traefik/cf.env` (Cloudflare token/env for DNS-01)
- `~/traefik/secrets/traefik.htpasswd` (BasicAuth usersfile)
- `~/traefik/data/acme.json` (created automatically on first run)

## Install
```bash
make install
```

## Verify
```bash
make status
make ps
make logs
```

## Dashboard
- URL: `https://traefik.az-lab.dev/`
- Protected by:
  - IP allowlist: `192.168.1.0/24,10.7.0.0/24,10.89.0.0/16`
  - BasicAuth usersfile: `~/traefik/secrets/traefik.htpasswd`

## Why “linger”
The install enables `loginctl enable-linger $USER` so the user service starts at boot even when nobody logs in.
