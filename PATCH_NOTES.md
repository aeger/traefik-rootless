# traefik-rootless: commit-ready additions

This update bundle is designed to be dropped into your existing `aeger/traefik-rootless` repo.

## Files included
- `HOMELAB-INGRESS-OVERVIEW.md`
- `scripts/healthcheck.sh`
- `docs/README-host-rename-snippet.md` (paste into your README where appropriate)

## What to do
1) Copy these files into your repo.
2) Make `scripts/healthcheck.sh` executable:
   ```bash
   chmod +x scripts/healthcheck.sh
   ```
3) (Optional) Add the README snippet to your main README under an “Operations” or “Notes” section.
4) Commit:
   ```bash
   git add HOMELAB-INGRESS-OVERVIEW.md scripts/healthcheck.sh docs/README-host-rename-snippet.md
   git commit -m "docs: update host rename to svc-podman-01 and add healthcheck"
   ```

## Why systemd unit wasn’t found
If Traefik is running but `container-traefik.service` does not exist, you’re using Podman restart policies rather than systemd user units. The overview doc explains both approaches.
