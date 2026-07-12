# ADR-014: Phase 8 destructive actions on the ops gateway

## Date: 2026-07-12
## Status: accepted (built, deployed, verified end-to-end)

## Decision
Four new destructive actions added to the ops gateway, all gated by the
Telegram approval flow (ADR-013) — the first real thing that mechanism
protects:

- **`remove_container` / `remove_volume` — cleanup-only scope.**
  Dynamically discovered stopped containers / dangling (unattached)
  volumes only, via new `list_removable_containers` /
  `list_removable_volumes` read endpoints. No fixed enum of removable
  names — safety comes from Docker's own semantics (stopped-only,
  dangling-only), re-verified server-side at execution time, not from
  a name whitelist. `remove_container` additionally refuses anything in
  `ALLOWED_SERVICES` outright, before even checking for an approval.
- **`prune` — one bundled action**, not three separate approvals:
  `containers/prune` + `volumes/prune` + `images/prune` (dangling only),
  matching `docker system prune`'s intent minus networks/build cache.
- **`reboot` — file-trigger + host systemd path unit, no new
  credential.** Docker's API has no host-reboot endpoint at all, so
  this can't go through docker-socket-proxy no matter what flags are
  set. ops-gateway gets a read-write bind mount to one host directory;
  a root-owned systemd path unit (`nas/scripts/ops-gateway-reboot.path`
  + `.service`) watches for a trigger file and calls `systemctl
  reboot`, removing the trigger file first to avoid a reboot loop on
  the next boot. The container's only new capability is "can create
  one file in one directory" — deliberately avoids reopening the
  credential-in-container tradeoff already rejected twice for
  `deploy_from_repo` (ADR-011/012, reusing `agent_ops`'s SSH key from
  inside a container).

Approval gating: new `require_approved(identity, action, target,
approval_id)` helper checks the approval is `status == "approved"`,
unexpired, and that its stored `action`/`target` match exactly what's
being invoked. No single-use/"consumed" tracking — every one of these
four actions is naturally safe to repeat within the 10-minute approval
window (remove of an already-removed thing 404s, prune of nothing
no-ops, a second reboot-trigger write while already rebooting is a
no-op).

## Finding: docker-socket-proxy has no separate DELETE toggle
Checked the proxy's actual behavior before building (not assumed,
per this project's own precedent from ADR-012's IMAGES+POST finding).
`docker-socket-proxy`'s `POST` flag gates **all** write HTTP methods
(POST/PUT/DELETE) across every enabled resource category — there is no
independent DELETE toggle. Since `POST=1` was already enabled in
Phase 7 for `pull_image`, and `CONTAINERS=1` has been on since Phase 6,
container creation and removal were **already technically reachable**
through the proxy before this phase — not a new grant Phase 8
introduces. Verified for real: `remove_container` worked against the
existing proxy config with only `VOLUMES: 0→1` added for the volume
actions. Accepted for the same reason ADR-012 accepted it for images:
ops-gateway's own API is the real enforcement boundary (it's the only
thing that can reach the proxy at all — internal-only Docker network),
and its endpoints stay narrow even though the proxy's raw reach is
broader.

## Finding: `volumes/prune` defaults to anonymous-only
Found via real testing, not assumed. Docker's `/volumes/prune` API
only removes **anonymous** volumes (no explicit name) by default —
a genuinely named volume created via `docker volume create` (or one
Compose creates with an explicit name) survives a default prune call
untouched. Since `remove_volume`'s whole target class is named-but-
dangling volumes, `prune` needs `filters={"all":["true"]}` to actually
sweep the same class of thing. First test run proved this the hard
way (a real throwaway named volume survived `prune`); fixed and
re-verified with a second real test.

## Finding: this NAS's Docker state doesn't reliably survive a reboot
The real end-to-end `reboot` test (a genuine NAS reboot, approved via
Telegram) surfaced two independent instances of the same underlying
problem: host-side files/directories that Docker manages per-container
came back with corrupted ownership/permissions after boot.

- `n8n-outpost-redis`'s anonymous `/data` volume directory and
  `dump.rdb` came back owned by `dnsmasq:1000` (an unrelated system
  user) with mode `0000` — unreadable by anyone, including root-equivalent
  processes inside the container. Redis crash-looped (`restart_count`
  climbing to 93 within ~90 minutes) trying to read it on every restart
  attempt.
- `n8n-outpost`'s Docker-generated `/etc/resolv.conf` (a per-container
  file Docker bind-mounts in, normally regenerated at container
  *creation*, not on restart) came back unreadable inside the
  container. It fell back to querying a bogus `::1:53` address and
  could never resolve `auth.christianmancini.de`, so the family n8n
  gate was fully non-functional for the ~1h45m between reboot and
  diagnosis — silently, since the container itself stayed "running."

Both fixed by recreating (not restarting) the affected
container — `docker rm -f` + `docker volume rm` + `compose up -d` for
redis (its data is pure session cache, safe to lose), `compose up -d
--force-recreate` for the outpost (config unchanged, so a plain
`up -d` would have skipped it). A *fresh* throwaway container on the
same network resolved DNS correctly throughout, confirming Docker's
embedded DNS resolver itself was healthy — this was per-container
file corruption, not a daemon-wide fault.

**This is a real operational risk for `reboot` going forward**, not
just a one-off: something about this NAS's boot sequence (UGOS,
btrfs RAID1, custom `/volume1/docker` data-root — already the subject
of one storage-driver gotcha in ADR-008) doesn't reliably preserve
correct ownership on Docker-managed per-container state across a
reboot. Not root-caused this session — noted as an open loose end
below, not blocking Phase 8's completion, but worth investigating
before `reboot` is used routinely or by an unattended agent (Hermes,
Phase 10) without a human present to catch and fix fallout like this.

## Consequences
- All four actions verified with real resources, real Telegram
  approvals, and real before/after checks — not just backend logic:
  a genuine throwaway stopped container and dangling volume were
  created, removed, and confirmed gone via an independent read path
  (`agent_ops`); prune was verified twice (once revealing the
  anonymous-only bug, once confirming the fix); reboot genuinely took
  the NAS down and back up, with all `restart: unless-stopped`
  services confirmed running afterward
- `reboot`'s file-trigger mechanism itself worked exactly as designed
  — the systemd path unit fired, removed the trigger file, called
  `systemctl reboot`, and re-armed cleanly on the next boot (confirmed
  `active (waiting)` afterward, no reboot loop)
- New open loose end: root cause of the post-reboot permission
  corruption (redis volume + outpost resolv.conf) not identified —
  candidates include btrfs/mount timing on `/volume1` during boot, or
  something UGOS-specific (this NAS already has one documented
  boot-time quirk: its native SSH service randomly disabling itself).
  Investigate before relying on `reboot` unattended.
- New open loose end (separate, VPS-side, discovered only because the
  above two fixes let the outpost actually reach the VPS): Authentik's
  outpost config-fetch API (`/api/v3/outposts/instances/`) returned a
  consistent 504 Gateway Timeout even though `authentik-server`'s own
  container healthcheck reports healthy. Not related to this phase or
  the NAS reboot — parked for separate investigation, most likely was
  already present and simply invisible while the outpost couldn't
  reach the VPS at all.
