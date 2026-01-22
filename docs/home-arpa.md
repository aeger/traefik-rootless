# TLS for `*.home.arpa` (LAN)

This repo supports **local TLS** for internal/LAN hostnames like:

- `crs309.home.arpa`
- `proxmox.home.arpa`
- `pve-ms01.home.arpa`

Because Let's Encrypt won't issue certs for `.home.arpa`, this uses a **local certificate** mounted from `./certs/`.

## What you need

1. A certificate + key that covers your LAN names (wildcard is easiest):
   - `certs/home-arpa.crt`
   - `certs/home-arpa.key`

2. Traefik told to load it (already wired up):
   - `dynamic/tls-home-arpa.yml`

3. A router + service file per LAN destination.

## Generate a local wildcard cert

Use whatever PKI you trust (your own CA, step-ca, pfSense CA, etc).

If you don't have one yet, `mkcert` is the lazy-but-effective path (good for your devices if you install its CA):

- Create a wildcard cert for `*.home.arpa`
- Export as `home-arpa.crt` + `home-arpa.key`
- Copy into `certs/`

Traefik just needs PEM files at those paths.

## Add a new `.home.arpa` destination

Copy the template:

```bash
cp dynamic/_template-lan-service.yml dynamic/proxmox.yml
```

Edit it:

- Set the `rule` host: `Host(`proxmox.home.arpa`)`
- Point the backend URL at the actual LAN IP/port

Example:

```yaml
http:
  routers:
    proxmox:
      rule: "Host(`proxmox.home.arpa`)"
      entryPoints: [websecure]
      tls: {}
      middlewares: [lan-allow]
      service: proxmox-svc

  services:
    proxmox-svc:
      loadBalancer:
        servers:
          - url: "https://192.168.1.200:8006"
        # If the backend uses a self-signed cert, you may need a serversTransport with insecureSkipVerify.
```

Reload: Traefik watches `dynamic/` so no restart required, but you can restart if you're suspicious.

## Testing (don't use HEAD)

Many embedded web UIs return **400** to `HEAD` requests (curl `-I` does a HEAD).

So test with GET:

```bash
curl -vk https://proxmox.home.arpa/
```

Or, forcing Host header:

```bash
curl -vk https://127.0.0.1/ -H "Host: proxmox.home.arpa"
```
