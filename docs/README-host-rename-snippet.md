## Host rename (svc-docker-01 → svc-podman-01)

If you previously referenced `svc-docker-01` in any documentation, inventories, or examples, update it to `svc-podman-01`.

Note: Traefik routing is typically based on domain Host rules and container labels, so the node hostname rename should not impact traffic. The most common post-rename fixes are internal DNS / SSH config cleanups and doc updates.

Also, Podman log tailing syntax is:

```bash
podman logs --tail 200 traefik
```

(not `podman logs traefik --tail 200`).
