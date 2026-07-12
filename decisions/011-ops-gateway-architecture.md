# ADR-011: Ops gateway v1 architecture

## Date: 2026-07-12
## Status: accepted (build in progress)

## Decision
- Two containers on the NAS, tailnet-only:
  - `docker-socket-proxy` (tecnativa/docker-socket-proxy:0.4.2) — mounts
    the real Docker socket (read-only bind mount) and exposes a
    restricted HTTP API on an internal-only Docker network (not bound
    to any host port, unreachable outside the compose project). Env
    vars restrict it to container inspection/listing/logs only —
    no POST, no exec, no image management, no volume/network
    management. This is what actually enforces "read-only," not
    application-level discipline in the gateway code alone.
  - `ops-gateway` — a small FastAPI app talking to the proxy above,
    bound to the NAS's Tailscale IP only. Exposes exactly four named
    endpoints (service_status, get_logs, disk_usage, backup_health),
    each validated against a fixed enum of known service names — no
    free-form input reaches the Docker API.
- Auth: per-agent bearer tokens (`svc-claude`, `svc-hermes`), checked
  against a fixed mapping loaded from env. No token, no valid token ->
  401. Every request — successful or rejected — is written to a local
  audit log (identity, action, target, result, timestamp).
- `backup_health` doesn't touch Docker or systemd at all: the two
  restic backup scripts now write a timestamp marker file on success,
  and this endpoint just reads those files' mtimes. Simpler than
  reaching into systemd/D-Bus from inside a container, and keeps the
  gateway itself dependency-light.

## Reasoning
- **Why a socket proxy instead of mounting `docker.sock` directly into
  the gateway app**: a raw Docker socket grants root-equivalent host
  access to whatever holds it — there is no partial trust with a bare
  socket mount. `docker-socket-proxy` is a purpose-built, widely-used
  tool specifically for this exact problem: it enforces the
  read-only/no-exec restriction at the network-API level, independent
  of whether the application code above it has a bug. Matches the same
  philosophy as `agent_ops`'s sudoers allowlist (ADR from earlier
  sessions) — narrow at the enforcement layer, not just by convention.
- **Why not reuse `agent_ops` via SSH from inside the gateway
  container**: would require putting `agent_ops`'s SSH private key
  inside a container reachable over the tailnet — a real credential
  with broader blast radius (usable for lateral movement generally,
  not just Docker queries) than a network-scoped, read-only API proxy.
- **Why fixed-enum service names, not free-form**: this is the same
  principle as the Ops Gateway's original spec in the roadmap —
  "service names from fixed enum, no free-form input." Prevents
  parameter injection into `get_logs`/`service_status` from ever being
  a meaningful attack surface, regardless of what's running.

## Consequences
- Scoped to the NAS only for v1 — VPS services aren't queryable through
  this gateway yet. Could be extended later (either a second instance
  on the VPS, or this one reaching across the tailnet) if needed.
- `svc-claude` and `svc-hermes` currently have identical scope (both
  can call all four read-only actions) — the token separation exists
  so they're independently revocable and independently auditable, not
  because they need different permissions yet. Differentiated scope
  can be added later without re-architecting.
- This does not replace `agent_ops` — `agent_ops` remains the
  observation identity for direct SSH-based diagnostics (as used
  throughout Phases 3.5–5); this gateway is the accountable, tokenized,
  audited alternative for agents specifically, per ADR-006.
