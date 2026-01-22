# Adding LAN destinations (*.home.arpa)

This setup uses Traefik’s **file provider** for LAN-only routes.

## Where files go
Traefik watches:

```text
~/traefik/dynamic/
```

Anything you put there ending in `.yml` is loaded automatically. No rebuild. Just restart Traefik if you want to be sure:

```bash
podman restart traefik
```

## Template workflow
1) Copy the template from the repo into your runtime dynamic directory:

```bash
cp dynamic/lan-service.template.yml ~/traefik/dynamic/mydevice.yml
```

2) Edit `mydevice.yml`:
- change router name
- change host rule
- change backend IP/URL

3) Restart Traefik:

```bash
podman restart traefik
```

## Example: CRS309
`dynamic/crs309.yml` is an example that maps:

- `https://crs309.home.arpa` → `http://192.168.1.248`

Important: if the device only speaks HTTP (port 80), use `http://`.
If it speaks HTTPS with a self-signed cert, you’ll need a serversTransport with `insecureSkipVerify` (not recommended unless you absolutely must).

## Allowlist (LAN only)
LAN routes use `lan-allow` middleware defined in:

```text
dynamic/lan-middlewares.yml
```

Update `sourceRange` if your LAN/VPN ranges differ.

Note: with rootless Podman, Traefik may see client IPs as `10.89.0.x` (rootless subnet).
That’s why we include `10.89.0.0/16` by default.

## Testing
Avoid `curl -I` if a device returns 400 for HEAD:

```bash
curl -k https://crs309.home.arpa/ -o /dev/null -v
```
