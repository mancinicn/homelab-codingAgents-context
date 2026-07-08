# ADR-008: NAS Docker storage driver — disable containerd snapshotter

## Date: 2026-07-08
## Status: accepted

## Decision
On the NAS (UGOS/UGREEN DXP2800), Docker's `/etc/docker/daemon.json` must
set:

```json
{
  "data-root": "/volume1/docker",
  "features": { "containerd-snapshotter": false }
}
```

This forces the classic `overlay2` graphdriver instead of Docker 29's
default `io.containerd.snapshotter.v1` image store.

## Problem
Fresh Docker 29.6.1 install on UGOS failed to pull any image containing
whiteout files (e.g. `n8n`, based on `node:alpine`) with:

```
failed to extract layer ... to overlayfs as "extract-...":
failed to convert whiteout file "lib/apk/.wh.exec": operation not permitted
```

`postgres:16-alpine` pulled fine — its layers happen to contain no
whiteout files, which masked the problem initially and pointed
suspicion at the filesystem rather than the extraction engine.

## Investigation
- Docker's default data-root (`/var/lib/docker`) sits on UGOS's own root
  filesystem, which is ITSELF an overlayfs (`lowerdir=/rom` — firmware
  image). Overlay-on-overlay cannot create whiteout device nodes there
  at all. Fixed by moving `data-root` to `/volume1` (btrfs RAID1).
- That alone did not fix it — the same error recurred on `/volume1`.
- Ruled out btrfs/UGOS's `ugacl` mount option as the cause: `mknod
  <path> c 0 0` succeeds directly on `/volume1`.
- `docker info` showed `driver-type: io.containerd.snapshotter.v1` —
  Docker 29 defaults to containerd's own snapshotter for image storage,
  which has a stricter/less mature whiteout-extraction codepath than the
  classic overlay2 graphdriver on non-mainstream filesystem stacks.
- Setting `"features": {"containerd-snapshotter": false}` and
  restarting the daemon flips `docker info` back to `Driver: overlay2`.
  Both `n8n` and `home-assistant` images then pulled and extracted
  cleanly.

## Consequences
- Any future container deploy on this NAS depends on this daemon.json
  setting being in place. If `/etc/docker/daemon.json` is ever
  regenerated or reset, this will silently break image pulls again with
  the same whiteout error — recheck this ADR if that happens.
- `data-root: /volume1/docker` also means Docker images/volumes are
  covered by the same btrfs RAID1 as the rest of `/volume1`, and will be
  included once Phase 5 extends restic backup coverage to
  `/volume1/appdata` (Docker's own data-root itself does not need
  backing up — only the bind-mounted `/volume1/appdata/*` volumes do).
- The old `/var/lib/docker` on the firmware partition was removed
  (nothing had ever successfully pulled there).

## Reference
- Scripts: `homelab-infra/nas/scripts/fix-docker-dataroot.sh`,
  `homelab-infra/nas/scripts/disable-containerd-snapshotter.sh`,
  `homelab-infra/nas/scripts/docker-storage-diag.sh`
