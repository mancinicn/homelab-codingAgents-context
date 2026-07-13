# ADR-017: VPS self-backup to a separate immutable repo

## Date: 2026-07-13
## Status: accepted (built + verified)

## Context
The VPS held the ONLY copy of Vaultwarden's vault DB and Authentik's
Postgres — a disk failure meant unrecoverable loss of the identity
provider and password vault. Surfaced during the session-9 review;
the same-day master-password incident (ADR-016) made the fragility
concrete. Phase 5 backed up the NAS but never the VPS.

## Decision
- **Separate restic repo, not shared with the NAS.** A second
  `rclone serve restic --append-only` instance (`backup-gateway-vps`,
  port **127.0.0.1:8201**, localhost-only — the VPS backs up to itself,
  the NAS never needs this repo) serving a **subpath** of the same
  bucket (`ugreen-restic-62fdead3d97f/vps`). Its own encryption
  password lives ONLY on the VPS.
  - **Why separate, not shared:** one shared repo would mean either box,
    if compromised, could read the OTHER's backups — a NAS compromise
    could read the vault/Authentik backup (Authentik dump has password
    hashes), and the VPS would hold the NAS repo password. Separate
    repos, separate passwords → no cross-box backup-read exposure.
- **Reuses the existing bucket-scoped, no-delete B2 key** (subpaths are
  covered by the bucket scope) and the same `--append-only`
  immutability. No new B2 key needed.
- **What's backed up** (`vps/scripts/restic-vps-backup.sh`, root, daily
  04:30): Authentik Postgres via `pg_dump` (never raw-copy a live PG
  dir — same reasoning as n8n's dump); Vaultwarden SQLite via host-side
  `sqlite3 .backup` (online-backup API, safe against the container's
  concurrent WAL — never a raw cp); plus Vaultwarden rsa_key/
  attachments/sends and Traefik's `acme.json`.
- **restic installed on the VPS** (was absent) — pinned 0.19.1 binary,
  checksum-verified in the deploy script.
- **Telegram-on-failure** mirrors the NAS pattern
  (`notify-vps-backup-fail.service`, needs `/etc/vps-secrets/notify.env`
  — same bot as the NAS, reused per ADR-013).

## Accepted weakness (documented, not hidden)
ADR-010 placed the NAS's gateway on a DIFFERENT machine so a NAS
compromise couldn't reach the policy-enforcing process. Here the VPS
backs ITSELF up, so that "separate box enforces the policy" property is
weaker — a fully compromised VPS runs both the data and its own
gateway. BUT the core immutability still holds even then, because it's
enforced SERVER-SIDE by two independent layers the VPS can't override:
the B2 key's missing `deleteFiles` capability, and `--append-only` on
the rclone REST layer. A compromised VPS can add backups, never delete
existing ones. Accepted.

## Verification (real, not just exit-0)
- Snapshot created and listed.
- `restic restore` of `acme.json` to /tmp **diffed byte-for-byte
  against the live file** — proves restorability, not just that the job
  ran.
- Immutability proven with a **lock-free, zero-risk** test: a direct
  HTTP DELETE of a non-existent pack object returned **403** (append-
  only rejects the method), while GET config returned 200. An earlier
  restic-forget-based test was a FALSE PASS (it failed on a stale lock,
  not a real rejection) — caught and replaced.

## New unrecoverable secret
The VPS repo's `RESTIC_PASSWORD` is unrecoverable (lose it → VPS backups
undecryptable), same class as the n8n encryption key. Stored in
Vaultwarden (Category A) and on the paper kit (ADR-016).

## Consequences / loose ends
- The immutability test left a couple of throwaway snapshots that can't
  be pruned through the append-only gateway (prune is laptop-only with
  the full-capability key, same as the NAS repo, ADR-005). Harmless.
- The rapid-fire verification left restic locks that had to be cleared
  manually with `restic unlock` (lock removal IS permitted under
  append-only). Watch that the FIRST scheduled nightly run releases its
  own lock cleanly (the NAS does; expected here too).
- notify.env on the VPS not yet populated (Christian deferred the
  Telegram token) — failure alerts are wired but silent until then.
- Vaultwarden was upgraded 1.32.7 → 1.36.0 immediately after this
  backup was verified (backup-before-upgrade). No breaking changes; DB
  migrations auto-ran; login verified; the current bw CLI now works
  again (closes the ADR-016 version-mismatch).
