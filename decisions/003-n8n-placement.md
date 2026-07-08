# ADR-003: n8n placement

## Date: 2026-07-07 (backfilled 2026-07-08 — decided verbally in session 2, never committed)
## Status: accepted

## Decision
- Canonical n8n runs on the NAS (core-net, own Postgres, tailnet-only)
- The VPS gets no n8n unless external webhooks become a real need
- The existing VPS n8n (n8n-zuij) is retired after migration (Phase 4),
  with its volume archived to B2 first

## Reasoning
- n8n's job is family/personal automation — near the data (photos, files,
  future Home Assistant), which lives on the NAS
- Tailnet-only removes the public attack surface entirely
- The VPS stays a narrow edge/identity box (Traefik, Authentik, Vaultwarden)
