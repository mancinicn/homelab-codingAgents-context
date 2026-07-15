# ADR-020: Immich placement, auth model, and deferred import

## Date: 2026-07-16
## Status: accepted

## Decision
- Immich runs on the NAS, tailnet-only, native app auth — NOT behind
  an Authentik proxy-outpost. Reachable at `http://100.126.31.47:2283`.
  Same class of exception Home Assistant already has to ADR-004's
  "everything behind SSO" default: a mobile app needs direct API/token
  access, not a browser-redirect SSO flow. This project's only real
  precedent for that mismatch (the n8n public-route webhook bypass,
  2026-07-15) involved building a second unauthenticated path around an
  existing outpost — evidence that fighting a proxy-outpost for a
  non-browser client is real, recurring friction, not a one-off. Native
  auth sidesteps it entirely, at the cost of one more login a family
  member has to remember instead of a single Authentik SSO session.
- Legacy photo import from `/volume1/Photos` is explicitly deferred,
  not decided. This is a fresh install — no existing photos were
  imported. Christian wants per-user accounts adding their own photos,
  with sharing between accounts, and wasn't confident the existing
  folder structure (numbered dirs, loose files, a mixed-in "Important
  documents" folder, a barely-started `_sorted/{2025,2026}` attempt) is
  even the right source. That whole question — external library vs.
  managed store, which folder(s), how to exclude non-photo content —
  is punted to a future decision once the app's actually in use.
- Registered with every existing piece of machinery a NAS service goes
  through: ops-gateway (`ALLOWED_SERVICES`/`DEPLOYABLE_SERVICES` for
  all four containers, `SERVICE_IMAGES` for the two tag-versioned ones
  only — see "Consequences"), the auto-update controller (one
  `immich` row, both app containers recreated together since they
  share `IMMICH_VERSION`), and appdata backup (pg_dump + library,
  model-cache excluded).

## Reasoning
- Data locality: Immich must live where the photos live (NAS, 4TB
  array) — this part was already decided (roadmap Phase 9, 2026-07-14
  RAM reassessment) and isn't new here.
- RAM: already reassessed and found feasible on the current 8GB
  (ML unloads after 5 min idle, peak load is inference-only) — holds up
  against a fresh `free -h` taken 2026-07-16 immediately before this
  build (4.2GB available, consistent with the 2026-07-14 figure).
  Post-deploy, available RAM settled to ~3GB with all four containers
  running — within the validated envelope.
- Deferring the import avoided a real, unresolved question (is
  `/volume1/Photos`'s current structure even what Christian wants
  Immich to reflect?) from blocking getting the app running and usable
  today. Nothing about running Immich now forecloses any future import
  approach — the existing folder is untouched.

## Consequences
- `immich-redis` and `immich-database` are deliberately excluded from
  `SERVICE_IMAGES` (and therefore from `pull_image`) — their upstream
  images are digest-pinned (`name@sha256:...`), which the gateway's
  `pull_image` endpoint would parse incorrectly (`image.rpartition(":")`
  splits at the colon inside `sha256:<hex>`, not the one before a tag).
  They're still fully diagnosable via `service_status`/`get_logs`/
  `restart_service`. Fixing the parsing to handle digest references
  generally is a separate, small hardening task if it's ever needed for
  another service.
- Compose service keys were renamed from upstream's generic `redis`/
  `database` to `immich-redis`/`immich-database`, kept identical to
  their `container_name` (matching every other service in this repo).
  Upstream's own defaults (`DB_HOSTNAME=database`, `REDIS_HOSTNAME=redis`)
  no longer apply — set explicitly instead. Reason: `deploy_from_repo`
  (ADR-018) runs `docker compose up -d <name>` against a single flat
  allowlist shared by every NAS service; a generic key like `redis`
  would silently collide with any future service that names its own
  cache the same thing.
- The auto-update controller's `compose_up`/`container_stable` functions
  were generalized to support one config row mapping to more than one
  compose service (a new `TARGETS` array, defaulting to the row's own
  key when unset) — needed because `immich-server` and
  `immich-machine-learning` share `IMMICH_VERSION` and must be
  recreated together. n8n and Home Assistant are unaffected (their row
  key already equals their one container name).
- Family members need the Tailscale app on their phones to reach
  Immich, same as Home Assistant today — no new public exposure was
  added for this.
- Import model, access-control granularity between family accounts,
  and what (if anything) happens to `/volume1/Photos` all remain open —
  intentionally, see "Decision" above.
