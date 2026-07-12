# ADR-015: Traefik requires an explicit network label for multi-homed backends

## Date: 2026-07-12
## Status: resolved

## Problem
`auth.christianmancini.de` (Authentik) was completely unreachable through
Traefik — TLS handshake succeeded, but actual HTTP requests hung
indefinitely or occasionally returned `504 Gateway Timeout`. Discovered
while investigating a Phase 8 side-effect (see ADR-014) but turned out
to be unrelated to that work and, once traced back, unrelated to the
NAS reboot too — this was a latent VPS-side configuration gap.

## Root cause
`authentik-server` is attached to two Docker networks: `proxy` (shared
with Traefik) and `authentik-internal` (private, shared with
`authentik-postgresql`/`authentik-redis`/`authentik-worker`). Traefik's
Docker provider picks a backend IP from whichever of a multi-homed
container's networks it finds — and it was picking
`authentik-internal`'s IP (172.20.0.x), a network Traefik itself isn't
even attached to. Every proxied request tried to dial an unroutable
address and either hung or eventually timed out into a 504, entirely
independent of whether Authentik itself was healthy (it always was —
confirmed via its own embedded outpost, which talks to it over
loopback and was completely unaffected).

`vault.christianmancini.de` (Vaultwarden) never hit this because
Vaultwarden is only on the `proxy` network — no ambiguity for Traefik
to get wrong.

Diagnosed conclusively by enabling Traefik's debug logging temporarily
(`--log.level=DEBUG`), which showed the exact failing dial:
`dial tcp 172.20.0.4:9000: i/o timeout`.

## Fix
Added `traefik.docker.network=proxy` to `authentik-server`'s labels in
`/opt/vps-infra/identity/authentik.yml` (VPS-only file, not tracked in
this repo — see "Consequences" below) — the standard Traefik label for
telling its Docker provider explicitly which network to dial when a
backend container has more than one. Recreating just that one service
picked it up immediately; verified with a real request going from a
complete hang to `HTTP 302` in ~170ms.

## Side-finding, fixed along the way
While recreating Traefik itself (to test the theory, before finding
the real root cause above), discovered its ACME certificate email was
being set to a **blank string** at every `docker compose up` —
`/opt/vps-infra/edge/traefik.yml` interpolates `${LETSENCRYPT_EMAIL}`
directly into its `command:` args, but no `.env` file existed in that
directory for Compose to source it from at parse time. The
container's own `env_file` (`/etc/vps-secrets/traefik.env`) sets the
var *inside* the running container at runtime — a completely separate
mechanism from Compose's own `${...}` interpolation, which only reads
from the shell environment or a `.env` file in the compose project
directory. Fixed by creating `/opt/vps-infra/edge/.env` with just
`LETSENCRYPT_EMAIL` (not the Cloudflare token, which stays exclusively
in the secrets file). Already-issued certificates were unaffected by
the blank email in the meantime (email only matters for *requesting*
new certs, not serving cached ones) — this was a latent gap, not
something actively breaking anything until it was noticed.

## Consequences
- **`/opt/vps-infra/` is not tracked in this git repo at all** — both
  `edge/traefik.yml` and `identity/authentik.yml` (and presumably
  `tools/vaultwarden.yml`) exist live-only on the VPS. This contradicts
  the project's own stated split ("homelab-infra has the compose files
  and scripts" — AGENTS.md) and means changes like this one had to be
  made directly on the box with no git history, no diff review, no
  rollback path. Worth importing these into `homelab-infra` as a
  follow-up — not done in this session to avoid scope creep on an
  already-long investigation, but a real gap
- Any *future* multi-homed service behind this Traefik needs the same
  `traefik.docker.network=<network>` label proactively, not
  reactively after it silently breaks — worth checking when Immich
  (Phase 9) or anything else gets added if it ever needs more than one
  network
- Traefik's log level was returned to `INFO` after diagnosis; the
  temporary `.env` fix and the network label are permanent
