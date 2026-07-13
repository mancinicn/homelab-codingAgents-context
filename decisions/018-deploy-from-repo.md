# ADR-018: deploy_from_repo via file-trigger + host systemd

## Date: 2026-07-13
## Status: accepted (built + verified)

## Context
The Phase 7 remainder (ADR-012) — letting an agent deploy/recreate a
service — was punted twice because both options were bad:
- **Broaden docker-socket-proxy** (NETWORKS+VOLUMES+CONTAINERS+POST):
  makes the deliberately-narrow proxy broad enough that its whole
  security model dissolves.
- **SSH key in the gateway container**: reintroduces the
  credential-in-container blast radius ADR-011 already rejected.

## Decision
A **third option**, sidestepping both: the **file-trigger + host-side
systemd pattern already proven for `reboot` in Phase 8 (ADR-014)**.
- ops-gateway's `POST /deploy/{name}?approval_id=…` validates `name`
  against a fixed `DEPLOYABLE_SERVICES` allowlist, requires a Telegram
  approval (`require_approved`, same as Phase 8 destructive actions —
  deploying creates/replaces containers, so it's gated), then writes
  ONLY the validated service name into a trigger file.
- A root-owned host systemd path unit (`ops-gateway-deploy.path` →
  `.service` → `/usr/local/bin/ops-gateway-deploy.sh`) reads the name,
  **re-validates against its own identical allowlist** (defence in
  depth), maps it to a compose file, runs `docker compose up -d
  <service>`, and removes the trigger first to avoid a re-fire loop.
- The container's only new power is "write one service name into one
  file" — **no docker socket, no SSH key, no broadened proxy**. Exactly
  the reboot mechanism's shape.
- **Approval-gated** (Christian's choice) — not un-gated like
  restart/pull, because a deploy is more powerful (creates/replaces).

## Scope: v1 vs v2 (stated explicitly so "from repo" isn't overclaimed)
- **v1 (this):** deploys from the scp-staged `/home/mancinicn/compose/`
  tree, kept current via the existing workflow. The allowlist maps
  service → compose file there.
- **v2 (deferred):** true `git pull`-on-NAS freshness. Needs a git
  credential ON the NAS — its own credential-on-box decision, out of
  scope here. Recorded so the gap is explicit.

## ops-gateway itself is deliberately NOT deployable
Deploying it would recreate the container handling the request
mid-flight. Excluded from the allowlist; deploy it manually.

## Verification (real, end-to-end)
1. Endpoint live; unknown service → 400, missing/invalid approval → 403.
2. Real deploy of `n8n-outpost-redis` with a genuine Telegram approval:
   journal confirms the host unit ran `docker compose -f
   n8n/outpost-compose.yml up -d n8n-outpost-redis`, then cleaned up the
   trigger (no re-fire). First run was a correct no-op (no config
   change → compose recreates nothing).
3. **Forced-recreate demo:** staged a harmless label change, re-deployed
   with approval, confirmed the container actually cycled
   (`started_at` 2026-07-12T13:52 → 2026-07-13T21:41), then reverted the
   staged file. Proves the real recreate path, not just the plumbing.
   (Minor: the running redis kept the inert test label until its next
   deploy — self-heals.)

## Consequences
- This is the **deploy/recreate engine** the health-gated auto-update
  controller (roadmap, Christian's 2026-07-13 request) will sit on top
  of. That controller is its own future ADR — do not improvise it.
- `agent_ops`'s `docker compose *` sudoers is no longer the only deploy
  path, but remains for manual/out-of-allowlist work.
- ops-gateway is now v1.5.
