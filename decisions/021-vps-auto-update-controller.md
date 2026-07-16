# ADR-021: VPS auto-update controller (extends ADR-019 to the edge)

## Date: 2026-07-16
## Status: accepted

## Decision
Extend the health-gated auto-update pattern (ADR-019) to the VPS's
three core services — Traefik, Authentik, Vaultwarden — as a **separate
instance** running on the VPS itself (`vps/scripts/image-autoupdate.sh`
+ its own systemd timer), not a remote-controlled extension of the
NAS's existing updater. Same design: discover newest stable within the
current major, apply, health-check with retries, auto-rollback on
failure, majors are notify-only.

All three compose files (`vps/edge/traefik.yml`, `vps/identity/
authentik.yml`, `vps/tools/vaultwarden.yml`) had their image tags
hardcoded directly rather than parameterized via `.env` — refactored to
match the `${VERSION_VAR}` + git-tracked version-pin `.env` pattern
already used everywhere else (n8n, Home Assistant, Immich).

## Reasoning
- **Separate instance, not cross-box control**: matches the access
  model applied everywhere else in this project (no agent/script holds
  SSH keys or remote credentials to reach across boxes — see the two
  independent backup-gateway instances in ADR-017 for the same
  reasoning applied to backups).
- **Real findings from checking actual current versions before wiring
  this in** (not assumed):
  - Traefik was 5 minor versions behind (`v3.2.0`, latest `v3.7.8`,
    same major) — the first real run will want to apply a genuine
    jump, not a trivial patch. Exactly the scenario the health-gate +
    rollback exists for.
  - **Authentik is roughly two years behind** (`2024.8.3` vs. latest
    `version/2026.5.5`) — a calendar-major gap, so the updater will
    only ever notify about it, never auto-apply. This is a real
    security-relevant gap on identity/auth infrastructure specifically
    (not routine drift) — worth a deliberate, backup-first manual
    upgrade at some point, same treatment Vaultwarden got in ADR-017.
    Recorded here, not fixed here.
  - Vaultwarden is already current (`1.36.0` = latest) — wiring it in
    changes nothing immediately, just prevents drifting again.
  - Authentik's GitHub release tags are `version/<year>.<month>.<patch>`
    — genuinely different format from every other service this project
    auto-updates. Verified against the live GitHub API before writing
    the config, not assumed (a previous session already got burned once
    assuming a version/format detail without checking — same mistake,
    avoided this time by just checking).
- **Health checks hit `127.0.0.1` with an explicit `Host:` header**,
  not the public hostname — so a health check never depends on public
  DNS/internet reachability, only on the box actually being healthy.
  Traefik gained a new `--ping=true` flag (wasn't enabled before) to
  give it a real health endpoint of its own, not just "did the
  container start."

## Consequences
- `image-autoupdate.sh`'s generic `TARGETS` mechanism (introduced for
  Immich the same day, ADR-020) is reused as-is for Authentik
  (`authentik-server` + `authentik-worker` share one version) — no new
  code needed, confirms the generalization was the right call.
- Weekly timer, Sunday 05:15 — after the VPS's own 04:30 backup
  (+ up to 5 min random delay), same "fresh backup precedes any
  update" discipline as the NAS.
- Telegram alerts depend on `/etc/vps-secrets/notify.env` actually
  being populated — carried as unpopulated since session 10 (Christian
  deferred it then). Not blocking: the updater still runs and rolls
  back correctly either way, it just won't page anyone. Same caveat as
  VPS backup-failure alerts already had.
- First real (non-dry-run) execution will attempt a real Traefik
  version jump across several minor releases — recommend a `--dry-run`
  first, and ideally watching the first real run rather than trusting
  it silently.

## Two real bugs found deploying this, both fixed same-day
The first live `--dry-run` on the VPS caught a genuine bug: Traefik
showed `best_auto=none` despite `v3.7.8` genuinely existing. Root
cause: `discover()`'s python compared the stored current-version
against candidate tags, but only candidates got their `PREFIX`
stripped before parsing — the current-version string didn't. Worked by
coincidence for every prior service (their stored `.env` values never
happened to include their own `PREFIX`); Traefik is the first service
where the real docker tag and the GitHub release-tag prefix are the
same string (`v`), so it's the first to actually collide. Fixed by
normalizing both sides identically before comparison.

Fixing that surfaced a second, related bug on the write side:
`BEST_AUTO` is always the bare stripped version, but writing it back
as the new `.env` value would have produced `TRAEFIK_VERSION=3.7.8` —
missing the `v` its actual docker tag requires. Caught in dry-run
output before any real update attempt. Also affects **Immich**
(`IMMICH_VERSION=v3.0.3` — same "docker tag needs the same prefix its
release tag has" situation), fixed there too before it ever mattered,
not after. New `IMGPFX` map (separate from `PREFIX`, which is only
about GitHub tag matching — the two don't always coincide) reconstructs
the correct value on write. Both bugs fixed in both
`nas/scripts/image-autoupdate.sh` and `vps/scripts/image-autoupdate.sh`
the same session; re-verified with dry-runs on both boxes afterward,
no regressions on n8n/HA/Vaultwarden/Authentik.
