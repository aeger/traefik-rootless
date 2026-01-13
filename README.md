Traefik v3 (Rootless Podman) – Reproducible Install Guide

Target

Ubuntu Server 24.04+

Rootless Podman

Cloudflare DNS + DNS-01 ACME

Traefik v3

MikroTik router handling NAT

Headless VM (no desktop, no Docker Desktop)

0. Assumptions & Architecture
Network flow
Internet
 → Cloudflare (443)
   → Origin rule rewrites to 8443
     → MikroTik dst-nat 8443 → host:443
       → Traefik websecure
         → containers

Security posture

No public 80/443 on router

Only Cloudflare IPs allowed to origin

Traefik dashboard protected by:

IP allowlist

Basic auth (usersfile)

Rootless containers only

1. Base system prep
Install Podman (rootless)
sudo apt update
sudo apt install -y podman uidmap slirp4netns fuse-overlayfs apache2-utils


Enable lingering so containers survive logout/reboot:

loginctl enable-linger $USER


Verify:

podman info | grep rootless

2. Create required directories
mkdir -p ~/traefik/{data,secrets}
chmod 700 ~/traefik ~/traefik/secrets

3. Create Cloudflare API token

Cloudflare Dashboard → API Tokens

Permissions

Zone → DNS → Edit

Zone → Zone → Read

Scope

Zone: az-lab.dev

Save token.

4. Create Traefik env file (Cloudflare + ACME)

~/traefik/cf.env

CF_DNS_API_TOKEN=REDACTED


Permissions:

chmod 600 ~/traefik/cf.env

5. Create dashboard basic-auth file (NO inline hashes)
htpasswd -nbB admin 'STRONG_PASSWORD' > ~/traefik/secrets/traefik.htpasswd
chmod 600 ~/traefik/secrets/traefik.htpasswd

6. Podman network (shared proxy net)
podman network create proxy

7. Traefik run command (FINAL, WORKING)
podman run -d \
  --name traefik \
  --restart=unless-stopped \
  --network proxy \
  --dns=1.1.1.1 --dns=8.8.8.8 \
  -p 80:80 \
  -p 443:443 \
  --env-file "$HOME/traefik/cf.env" \
  -v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock:ro \
  -v "$HOME/traefik/data:/data" \
  -v "$HOME/traefik/secrets:/secrets:ro" \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.traefik.rule=Host(\`traefik.az-lab.dev\`)" \
  -l "traefik.http.routers.traefik.entrypoints=websecure" \
  -l "traefik.http.routers.traefik.tls=true" \
  -l "traefik.http.routers.traefik.tls.certresolver=le" \
  -l "traefik.http.routers.traefik.service=api@internal" \
  -l "traefik.http.middlewares.traefik-auth.basicauth.usersfile=/secrets/traefik.htpasswd" \
  -l "traefik.http.middlewares.traefik-allow.ipallowlist.sourcerange=192.168.1.0/24,10.7.0.0/24,10.89.0.0/16" \
  -l "traefik.http.routers.traefik.middlewares=traefik-allow,traefik-auth" \
  docker.io/traefik:v3.1 \
  --log.level=INFO \
  --accesslog=true \
  --api.dashboard=true \
  --entrypoints.web.address=:80 \
  --entrypoints.websecure.address=:443 \
  --entrypoints.web.http.redirections.entrypoint.to=websecure \
  --entrypoints.web.http.redirections.entrypoint.scheme=https \
  --providers.docker=true \
  --providers.docker.endpoint=unix:///var/run/docker.sock \
  --providers.docker.exposedbydefault=false \
  --certificatesresolvers.le.acme.email=YOUREMAIL@example.com \
  --certificatesresolvers.le.acme.storage=/data/acme.json \
  --certificatesresolvers.le.acme.dnschallenge=true \
  --certificatesresolvers.le.acme.dnschallenge.provider=cloudflare \
  --certificatesresolvers.le.acme.dnschallenge.delaybeforecheck=10 \
  --certificatesresolvers.le.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53

8. MikroTik NAT & Firewall (summary)
NAT
WAN tcp/8443 → 192.168.1.181:443
LAN tcp/8443 → 192.168.1.181:443 (hairpin)
src-nat masquerade for LAN → host

Firewall forward
allow src=cloudflare dst=192.168.1.181:443 nat=dstnat
drop  dst=192.168.1.181:443 nat=dstnat (everyone else)


No WAN 80. No WAN 443.

9. Cloudflare config
DNS

hello.az-lab.dev → proxied

traefik.az-lab.dev → proxied

Origin Rule
IF hostname ends with az-lab.dev
THEN origin port = 8443

SSL Mode

Temporary: Full

Final: Full (strict) (after cert issued)

10. Verify
podman logs traefik
curl -vk https://192.168.1.181/ -H "Host: traefik.az-lab.dev"


Dashboard:

https://traefik.az-lab.dev

11. Autostart (Headless, reliable)

You already used:

--restart=unless-stopped


That works only if lingering is enabled (you did that).

Verify reboot persistence
reboot
podman ps


If you want absolute systemd-level reliability, convert this to a quadlet later. Optional.

12. Should you put this on GitHub?
Short answer

Yes. Private repo. 100%.

Why

This setup has too many sharp edges to “remember”

You already debugged the hard parts

GitHub becomes your:

disaster recovery doc

versioned infrastructure reference

future migration blueprint

What to put in the repo
traefik-rootless/
├── README.md          ← everything above
├── traefik.run.sh     ← sanitized run command
├── cf.env.example
├── secrets/
│   └── traefik.htpasswd.example
├── mikrotik/
│   └── firewall-nat.rsc


Never commit:

real tokens

real passwords

real IPs if you care

Final verdict

You built:

a Cloudflare-fronted HTTPS edge

behind an ISP that blocks ports

using rootless containers

with proper auth

and zero accidental exposure

That’s not beginner territory. That’s “document it or regret it” territory.

Yes, create the repo.
Future-you will absolutely forget one of these flags and curse present-you for not writing it down.