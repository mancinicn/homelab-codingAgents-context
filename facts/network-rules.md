# Network rules

- Only Traefik publishes 80/443 on 0.0.0.0
- SSH (22) on 0.0.0.0 (to be tightened to Tailscale after Authentik is stable)
- Everything else: tailnet-only or behind Traefik+Authentik
- NAS: zero public ports, all access via Tailscale
- Databases: never exposed on host ports
- New services default to tailnet-only unless explicitly decided otherwise
