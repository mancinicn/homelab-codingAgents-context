# ADR-019: Health-gated Docker image auto-update controller (v1)

## Date: 2026-07-14
## Status: accepted (built + verified; v1 = n8n + Home Assistant)

## Context
Christian wants Docker images kept current automatically, but safely.
Chosen model: fully-automatic updates where each update must pass a
service-specific health check or **auto-roll-back** — no unattended
silent breakage (the failure mode this whole project keeps cleaning up).
Never `:latest`: resolve "newest stable" to a concrete pinned tag. First
concrete slice of the Phase 10 watchdog; the thing that makes the stack
(and later Immich) self-maintaining. Sits on the deploy/recreate
capability of deploy_from_repo (ADR-018) but runs as an autonomous
SYSTEM automation (root systemd timer), NOT the human-approval-gated
agent path — because here the health check REPLACES human approval.

## Decisions
- **Weekly** (Sun 05:00, after the nightly backups so a fresh backup
  precedes any update).
- **v1 scope: n8n + Home Assistant only** (NAS; Telegram already wired).
  Config-driven (a table in the script) so adding services is trivial.
  DBs (postgres/redis), the outpost, and all VPS services are out of v1.
- **Never auto-cross a major** — patches/minors within the current major
  line auto-apply; a new major is Telegram-notify-only (n8n = semver
  major; HA = calendar YEAR).

## Mechanism
- **Version state in each compose dir's `./.env`** (`N8N_VERSION`,
  `HA_VERSION`); the compose `image:` line reads `${VAR}`. The updater
  only ever rewrites a flat `KEY=value` line — never edits compose yaml
  (which would risk corrupting the comment-rich files in an unattended
  rollback). Verified: compose v5.3.0 auto-reads the compose-file dir's
  `.env` regardless of CWD, so ALL invocations (manual, deploy_from_repo
  executor, this updater) pick it up with no `--env-file`. These `.env`
  files are version-numbers-only, no secrets, and git-tracked via narrow
  `.gitignore` exceptions.
- **Discovery** via the GitHub releases API: drop prereleases/drafts and
  non-semver tags, strip the tag prefix (`n8n@`), filter to the current
  major line, pick the highest. Real finding: n8n's `/latest` and even
  its tag list are noisy (a prerelease `2.31.0` and a `stable` alias and
  an old `1.x` line all coexist) — the filter correctly picked stable
  `2.30.4`, not the prerelease `2.31.0`.
- **Per-service flow**: record rollback = current (+ image digest);
  write `.env` to new; `compose up -d <svc>` (pull fail → restore, no
  downtime); grace window + app-level health check; PASS → keep +
  Telegram ✅; FAIL → rewrite `.env` to rollback, `up -d`, re-verify →
  Telegram ⚠️; rollback-also-fails → Telegram 🚨, exit non-zero
  (systemd `OnFailure` double-alerts on a script crash).
- **Health checks actually exercise the app** (a port ping would pass a
  broken n8n): n8n `GET /healthz == 200`; HA `GET :8123 ∈ {200,30x}`;
  both also require the container `running` and not restart-looping.
- **Test hook** `IMAGE_AUTOUPDATE_FORCE_HEALTH_FAIL=1` forces one health
  failure to exercise rollback safely; `--only <svc>` and `--dry-run`.

## Verification (real, end-to-end — rollback is the whole point)
- **Dry-run**: correctly reported n8n 2.29.8 → 2.30.4 (stable, not the
  2.31.0 prerelease) and HA 2026.7.1 → 2026.7.2, no major flagged.
- **Rollback (the critical test)**: forced a health failure on a real
  n8n update to 2.30.4 → the updater rolled `.env` back to 2.29.8,
  recreated n8n on 2.29.8 (confirmed via a fresh container + healthz
  200), and sent the Telegram ⚠️. Proven on a live service.
- **Forward update**: real run took n8n → 2.30.4 and HA → 2026.7.2,
  both passed their health checks and were KEPT (confirmed: fresh
  containers, restarts 0, n8n /healthz 200, HA / 200), with Telegram ✅.
  Repo `.env` files reconciled to these versions at commit time.

## Known v1 limitations (documented, not hidden)
- **Git drift**: the updater edits the staged `.env` on the NAS; the
  repo copy drifts until reconciled. v1: the Telegram notices are the
  record + we reconcile the repo `.env` at commit time. v2 (git-on-NAS,
  the deferred deploy_from_repo v2) would auto-commit.
- `ops-gateway`'s `SERVICE_IMAGES` (used by `pull_image`) isn't updated
  by this — its pinned tag can lag. Low harm (pull_image would pull an
  older tag). Reconcile later, or migrate pull_image to read the `.env`.
- HA ships breaking changes monthly, not only on majors — the
  health-check + rollback IS the safety net there, as designed.

## Consequences
- The stack now self-updates weekly within the safety rails. Adding a
  service = one config row + parameterize its compose image + a health
  check. Immich (Phase 9) will join once installed.
- deploy_from_repo (ADR-018, approval-gated) remains the agent-initiated
  path; this is the autonomous system path. Two actors, two mechanisms,
  same recreate capability.
