# ADR-010: Backup gateway mechanism and placement

## Date: 2026-07-10
## Status: accepted (build in progress)

## Decision
- Mechanism: `rclone serve restic --append-only` (not restic's own
  `rest-server`) — restic's `rest-server` serves a local directory as
  the repository storage itself, which would mean migrating all backup
  data off B2. `rclone serve restic` instead proxies to a real remote
  (B2 via rclone's b2 backend), which is what's needed to keep B2 as
  the actual storage while adding an append-only enforcement layer in
  front of it.
- Placement: the VPS, not the NAS. Different machine than the one being
  backed up — if the NAS is ever compromised, that compromise can't
  also reach into the gateway process enforcing the backup policy.
  Bound to the VPS's Tailscale IP only, never public.
- B2 key scoping: a NEW B2 application key, capabilities `listFiles` +
  `readFiles` + `writeFiles`, explicitly WITHOUT `deleteFiles`, scoped
  to the single existing bucket (`ugreen-restic-62fdead3d97f`) only.
  This key lives only on the gateway (VPS), never on the NAS.
- Gateway auth: NAS authenticates to the gateway with a separate,
  simple, auto-generated username/password (`GATEWAY_USER`/
  `GATEWAY_PASS`) — unrelated to and far less sensitive than the B2 key
  itself, which never leaves the gateway container.
- Pruning stays exactly as ADR-005 already specified: only ever from
  Christian's laptop, directly against B2, using the original
  full-capability key. Never through the gateway, never from the NAS.

## Reasoning (belt-and-suspenders, not redundant)
Two independent layers of protection, deliberately:
1. B2 itself will reject delete requests from the new key — even a
   fully compromised gateway container can't delete real objects,
   because B2's own API enforces the key's capability list server-side.
2. `--append-only` on rclone's restic-protocol layer additionally
   understands restic's own data model — it allows the routine lock
   file cleanup restic needs to self-recover from interrupted runs
   (this is specifically why ADR-005 rejected a bare no-delete B2 key
   as sufficient on its own: it would break that lock handling), while
   still rejecting deletion of actual snapshot/pack data.

## Consequences
- Once this is live and the NAS's restic config is switched over to
  the gateway (repository URL becomes `rest:http://GATEWAY_USER:
  GATEWAY_PASS@100.94.111.98:8200/`), the NAS no longer holds any B2
  credential capable of touching production backup data destructively
- The existing NAS-held B2 key (full delete capability, currently in
  `/home/mancinicn/.config/restic/b2.env`) should be retired/rotated
  out once the gateway is confirmed working — not done automatically,
  needs explicit verification first (existing snapshots still visible
  and restorable through the new gateway) before cutting over
- This is the literal hard gate referenced by invariant #4 and ADR-006/
  007: no agent gets write/destructive infrastructure capability until
  this exists. Once it's live and verified, that gate is satisfied.
