# Manual changes / notes for updating the existing repo checkout

This zip is intended to be extracted at the ROOT of the repo (same folder as README.md).

## New files added
- compose.yml
- dynamic/lan-middlewares.yml
- dynamic/tls-home-arpa.yml
- dynamic/crs309.yml
- dynamic/lan-service.template.yml
- docs/compose-quickstart.md
- docs/lan-services.md
- scripts/bootstrap.sh
- systemd/podman-compose@.service.example

## Updated files
- README.md (updated to Compose-first instructions)

## Optional cleanup (manual)
You can keep these, but they’re now “legacy”:
- traefik.run.sh (old bash runner)

If you want to keep history but de-emphasize it:
- move traefik.run.sh -> scripts/legacy/traefik.run.sh
- update any internal links you have
