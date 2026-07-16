# ADR-022: Hermes v1 — Watchdog (Phase 10 first slice)

## Date: 2026-07-16
## Status: accepted, built, not yet activated

## Decision
Build Hermes's first real capability — the Watchdog role from
ADR-006/007 — as a minimal FastAPI service on the NAS
(`nas/agents/hermes/`), triggered by an n8n schedule, using the
already-provisioned `svc-hermes` ops-gateway token against the
already-built `service_status`/`restart_service` endpoints. No new
ops-gateway capability, no new trust boundary, no new Authentik/vault
work.

First playbook: check every managed NAS service's health; if one is
crash-looping or stopped, restart it. DeepSeek proposes the action;
the code independently re-verifies the same hard rule against the real
data before ever acting — the model's own claim is never trusted
alone.

Model backend: DeepSeek (per ADR-001), not amended. Christian raised
OpenAI-primary/DeepSeek-fallback, but only has a ChatGPT subscription
(not separately-billed API access, which is what a programmatic
integration actually needs) — decided to stay with DeepSeek for v1;
switching primary/fallback later is a config change, not a rebuild.

## Reasoning
- **This was corrected framing, not a new finding**: earlier the same
  day, Phase 10 was described to Christian as blocked on calendar/list
  tools that don't exist yet. True for Family Copilot, not for
  Watchdog — ADR-007 only ever required Phase 5 (backup) and Phase 6
  (ops gateway), both done. The `svc-hermes` token has sat unused in
  Vaultwarden since Phase 6 specifically waiting for this.
- **Zero new safety design needed**: `restart_service` was never
  approval-gated in the ops-gateway's own architecture (only Phase 8's
  destructive actions are — remove_container, remove_volume, prune,
  reboot, deploy). Hermes calling it autonomously is exactly the
  authority the gateway already decided was safe for *any* holder of a
  valid token, `svc-claude` or `svc-hermes` alike. "First autonomous
  agent" sounds like it should require new machinery; it didn't,
  because the access model (ADR-006/007) was built specifically so
  that adding an agent is "give it a token already scoped this
  narrowly," not "design new guardrails under time pressure."
- **Playbook chosen from this project's own real history**, not a
  hypothetical: n8n-postgres crash-looped 4.5+ hours silently (found
  during the 2026-07-12 reboot investigation, ADR-014); the
  `universal-capture` legacy stack crash-looped ~2 days before it was
  noticed while auditing n8n-zuij (2026-07-15, session 11). Both are
  exactly the failure mode this playbook watches for.
- **Zero network exposure, stricter than any other service so far**:
  no host port at all, `core-net`-only, reachable only by n8n via
  Docker's internal DNS. `/watchdog/run` has no auth of its own because
  network topology is the actual boundary — the same pattern
  `n8n-outpost-redis` already uses (internal Redis, no host port, no
  auth, because nothing outside the network can reach it to need one).

## Consequences
- Registered in the ops-gateway's `ALLOWED_SERVICES` only (status/
  logs/restart diagnostics) — deliberately not `DEPLOYABLE_SERVICES`
  or `SERVICE_IMAGES`, same reasoning ops-gateway excludes itself:
  custom local code, no upstream image/version to pull, and
  `deploy_from_repo`'s trigger mechanism never passes `--build` anyway
  (confirmed by reading `ops-gateway-deploy.sh`), so it could never
  actually deploy a Hermes code change even if listed.
- Not in the auto-update controller (same "no upstream releases"
  reasoning) and not in appdata backup (stateless — no DB, nothing
  persists between runs, nothing to lose).
- **Known v1 gap, not an oversight**: no escalation if the *same*
  service needs restarting run after run — v1 just keeps following the
  rule every 20 minutes rather than recognizing "this restart isn't
  fixing anything, a human needs to look." Worth a v2, not blocking
  this first slice.
- Home Assistant REST API integration (mentioned in ADR-007) not built
  — not needed until a HA-specific playbook exists, which is Family
  Copilot territory, still blocked on calendar/lists tooling.
- **Not yet running for real**: built, syntax-checked, staged on the
  NAS, but blocked on Christian providing his DeepSeek key and pulling
  the `svc-hermes` token from Vaultwarden — no rush, "when the time
  comes." The n8n workflow imports inactive regardless; he activates
  it himself after a reviewed test run, same as every other real
  change in this project.
- **Found and fixed a real gap while building this**: `save-immich-
  secrets.sh` (written earlier the same day, for ADR-020) had been
  silently caught by `.gitignore`'s blanket `*secret*` rule since the
  moment it was created — deployed fine via scp at the time, but never
  actually tracked in git. The other `save-*-token.sh` scripts only
  avoided this by coincidence (no "secret" in their filenames, not a
  deliberate exception). Added explicit `.gitignore` exceptions for
  both `save-immich-secrets.sh` and the new `save-hermes-secrets.sh` —
  these scripts prompt for and write secrets elsewhere, they never
  contain a secret value themselves.
