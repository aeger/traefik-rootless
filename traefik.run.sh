#!/usr/bin/env bash
set -euo pipefail

# Traefik v3 rootless Podman runner
# - Uses a dedicated user-defined network: proxy
# - Reads Cloudflare token + misc from ~/traefik/cf.env
# - Stores ACME data in ~/traefik/data/acme.json
# - Uses BasicAuth usersfile at ~/traefik/secrets/traefik.htpasswd
#
# Edit the variables below for your environment.

#!/usr/bin/env bash
# shellcheck disable=SC1009,SC1073
#!/usr/bin/env bash
# shellcheck disable=SC1009,SC1073


TRAEFIK_HOSTNAME="traefik.az-lab.dev"
CF_ENV_FILE="${HOME}/traefik/cf.env"
DATA_DIR="${HOME}/traefik/data"
SECRETS_DIR="${HOME}/traefik/secrets"
PODMAN_SOCK="/run/user/$(id -u)/podman/podman.sock"

mkdir -p "${DATA_DIR}" "${SECRETS_DIR}"

if [[ ! -f "${CF_ENV_FILE}" ]]; then
  echo "Missing ${CF_ENV_FILE}. Copy cf.env.example to that path and fill it out."
  exit 1
fi

if [[ ! -f "${SECRETS_DIR}/traefik.htpasswd" ]]; then
  echo "Missing ${SECRETS_DIR}/traefik.htpasswd. Create it with:"
  echo "  htpasswd -nbB admin 'STRONG_PASSWORD' > ${SECRETS_DIR}/traefik.htpasswd"
  exit 1
fi

chmod 600 "${CF_ENV_FILE}" || true
chmod 600 "${SECRETS_DIR}/traefik.htpasswd" || true

podman network exists proxy 2>/dev/null || podman network create proxy >/dev/null

podman rm -f traefik 2>/dev/null || true

podman run -d   --name traefik   --restart=unless-stopped   --network proxy   --dns=1.1.1.1 --dns=8.8.8.8   -p 80:80   -p 443:443   -p 8080:8080   --env-file "${CF_ENV_FILE}"   -v "${PODMAN_SOCK}:/var/run/docker.sock:ro"   -v "${DATA_DIR}:/data"   -v "${SECRETS_DIR}:/secrets:ro"   -l "traefik.enable=true"   -l "traefik.http.routers.traefik.rule=Host(\\`${TRAEFIK_HOSTNAME}\\`)"   -l "traefik.http.routers.traefik.entrypoints=websecure"   -l "traefik.http.routers.traefik.tls=true"   -l "traefik.http.routers.traefik.tls.certresolver=le"   -l "traefik.http.routers.traefik.service=api@internal"   -l "traefik.http.middlewares.traefik-auth.basicauth.usersfile=/secrets/traefik.htpasswd"   -l "traefik.http.middlewares.traefik-allow.ipallowlist.sourcerange=192.168.1.0/24,10.7.0.0/24,10.89.0.0/16"   -l "traefik.http.routers.traefik.middlewares=traefik-allow,traefik-auth"   docker.io/traefik:v3.1   --log.level=INFO   --accesslog=true   --api.dashboard=true   --entrypoints.web.address=:80   --entrypoints.websecure.address=:443   --entrypoints.web.http.redirections.entrypoint.to=websecure   --entrypoints.web.http.redirections.entrypoint.scheme=https   --providers.docker=true   --providers.docker.endpoint=unix:///var/run/docker.sock   --providers.docker.exposedbydefault=false   --certificatesresolvers.le.acme.email=YOUREMAIL@example.com   --certificatesresolvers.le.acme.storage=/data/acme.json   --certificatesresolvers.le.acme.dnschallenge=true   --certificatesresolvers.le.acme.dnschallenge.provider=cloudflare   --certificatesresolvers.le.acme.dnschallenge.delaybeforecheck=10   --certificatesresolvers.le.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53

echo "Traefik started."
echo "Dashboard should be at: https://${TRAEFIK_HOSTNAME}/"
