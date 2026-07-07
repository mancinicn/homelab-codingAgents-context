#!/bin/bash
echo "Refreshing state snapshot..."

ssh vps "
echo '## VPS containers'
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo ''
echo '## VPS disk'
df -h /
echo ''
echo '## VPS public ports (should be empty except 80/443/22)'
ss -tulpn 2>/dev/null | grep '0.0.0.0' | grep -v ':80\b\|:443\b\|:22\b' || echo 'clean'
echo ''
echo '## VPS networks'
docker network ls --format '{{.Name}}'
" > state/vps.md 2>/dev/null

ssh nas "
echo '## NAS containers'
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo ''
echo '## NAS disk'
df -h /volume1
echo ''
echo '## NAS networks'
docker network ls --format '{{.Name}}'
echo ''
echo '## Backup timer'
systemctl status restic-photos-backup.timer 2>/dev/null | head -5
" > state/nas.md 2>/dev/null

date -Iseconds > state/last-refresh.txt
echo "Done. State captured in state/"
