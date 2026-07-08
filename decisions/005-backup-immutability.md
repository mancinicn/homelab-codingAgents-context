# ADR-005: Backup immutability approach

## Date: 2026-07-07 (backfilled 2026-07-08 — decided verbally in session 2, never committed)
## Status: accepted

## Decision
- Immutability comes from an append-only gateway on the backup path
  (rclone `serve restic --append-only` or restic REST server
  `--append-only`), built in Phase 5
- The NAS backs up THROUGH the gateway, never directly to B2
- Pruning uses a separate full-capability key, run only from Christian's
  laptop — never from the NAS

## Rejected alternatives
- B2 application key without delete capability: breaks restic's lock
  handling (restic must delete stale locks)
- B2 object lock: complicates retention and pruning

## Consequences
- Until Phase 5 is done, the B2 key on the NAS can delete backups.
  This is the reason for invariant #4: no agent write/destructive
  capability before the gateway exists.
- Do NOT "improve" the current setup by swapping in a no-delete key.
