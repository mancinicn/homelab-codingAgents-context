#!/usr/bin/env bash
# Refresh live infrastructure state snapshots into state/.
#
# Works from the laptop or from the VPS:
#   - VPS section runs locally when this script is executed on the VPS,
#     otherwise over `ssh vps`.
#   - NAS section always connects as agent_ops (narrow sudo allowlist).
#     Commands must match /etc/sudoers.d/agent_ops EXACTLY:
#       `docker ps *` allows extra args; `docker network ls` does NOT
#       (no --format there).
#
# Fail-safe: writes to a temp dir first; a state file is only replaced
# when the new snapshot is non-empty. A failed refresh preserves the
# previous good snapshot and exits non-zero.

set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$REPO_DIR/state"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$STATE_DIR"
FAILED=0

# --- VPS ------------------------------------------------------------------
vps_snapshot() {
  echo '## VPS containers'
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
  echo ''
  echo '## VPS disk'
  df -h /
  echo ''
  echo '## VPS public listeners (expected: 22, 80, 443, 41641/udp)'
  ss -tulpn 2>/dev/null | grep '0\.0\.0\.0' || echo 'none'
  echo ''
  echo '## VPS docker networks'
  docker network ls --format '{{.Name}}'
}

if [ -d /opt/vps-infra ]; then
  # running on the VPS itself
  vps_snapshot > "$TMP_DIR/vps.md" || FAILED=1
else
  ssh vps "$(declare -f vps_snapshot); vps_snapshot" > "$TMP_DIR/vps.md" || FAILED=1
fi

# --- NAS (as agent_ops, sudo allowlist only) --------------------------------
# NOTE: `docker network ls` must be bare — the sudoers rule has no wildcard.
ssh agent_ops@nas 'bash -s' > "$TMP_DIR/nas.md" <<'REMOTE' || FAILED=1
set -u
echo '## NAS containers'
sudo -n /usr/bin/docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo ''
echo '## NAS disk'
/usr/bin/df -h /volume1
echo ''
echo '## NAS docker networks'
sudo -n /usr/bin/docker network ls
echo ''
echo '## Backup timer'
sudo -n /usr/bin/systemctl status restic-photos-backup.timer 2>/dev/null | head -5
REMOTE

# --- Publish only non-empty snapshots ---------------------------------------
publish() {
  local name="$1"
  if [ -s "$TMP_DIR/$name" ]; then
    mv "$TMP_DIR/$name" "$STATE_DIR/$name"
    echo "OK: state/$name updated"
  else
    echo "WARN: $name snapshot empty — keeping previous state/$name" >&2
    FAILED=1
  fi
}

publish vps.md
publish nas.md

if [ "$FAILED" -eq 0 ]; then
  date -Iseconds > "$STATE_DIR/last-refresh.txt"
  echo "Done. State captured in state/"
else
  echo "Refresh incomplete — previous snapshots preserved where refresh failed." >&2
  exit 1
fi
