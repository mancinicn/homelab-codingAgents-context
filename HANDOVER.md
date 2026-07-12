# Claude Code Handover — Homelab Infrastructure Build

Snapshot as of 2026-07-12, end of session 9. This is a point-in-time
summary for starting a new chat — it will go stale. For anything that
matters, verify against the live repos/state rather than trusting this
document blindly (same rule as everywhere else in this project).

**Normal session start**: `git pull` both repos, read `AGENTS.md`, run
`scripts/refresh-state.sh`, read the latest file in `sessions/`. This
document exists in addition to that ritual, not instead of it — read
it first for the big picture, then the latest session log for exact
recent detail.

---

## The Human

Christian (mancinicn). Sole admin. Hannover, Germany. Prefers combined
commands over back-and-forth, values security but pragmatism over
ceremony. Wants Claude to function like a developer/engineering partner
across the whole stack (deploying tools, dashboards, automations,
access policy) — not just narrow infra ops. Explicitly comfortable
extending Claude's access deliberately and incrementally (temporary
elevated tokens for debugging, a standing ops-gateway credential) as
long as each step is an explicit decision, documented, and scoped —
not something that happens silently.

## Repositories

- `homelab-infra` — https://github.com/mancinicn/homelab-infra.git —
  what's deployed (compose files, scripts, runbooks, roadmap at
  `docs/agent-implementation-plan.md`)
- `homelab-codingAgents-context` — https://github.com/mancinicn/homelab-codingAgents-context.git
  — what agents know (this repo: facts/, decisions/, sessions/,
  scripts/refresh-state.sh)
- Both cloned side by side in `C:\Users\jm2_c\HomeInfra\` on Christian's
  Windows laptop (not itself a git repo). Git auth via Windows'
  credential manager, already configured.

## Infrastructure

- **NAS**: UGREEN DXP2800, UGOS (Debian 12), 8GB RAM, 2x4TB btrfs
  RAID1. Tailscale: `nas`, 100.126.31.47. Docker data-root moved to
  `/volume1/docker`, containerd snapshotter disabled — required, see
  ADR-008, breaks image pulls on this box otherwise.
- **VPS**: Hostinger, Ubuntu 24.04, 8GB RAM, 96GB disk. Tailscale
  100.94.111.98, public IP 72.60.36.129. Kept deliberately minimal —
  edge + identity only (Traefik, Authentik, Vaultwarden), the only
  internet-facing box.

## Access model (ADR-006, extended by ADR-009/011)

- **Claude Code has no standing SSH/infra identity** — borrows
  Christian's own session (`ssh nas`/`ssh vps`, his ssh-agent). One
  laptop quirk: Git Bash's ssh can't use the Windows ssh-agent for the
  VPS (works fine for NAS via Tailscale SSH) — use
  `/c/Windows/System32/OpenSSH/ssh.exe` / `scp.exe` explicitly for VPS
  commands from the Bash tool.
- **`agent_ops`** on the NAS: SSH key, narrow NOPASSWD sudoers
  (`docker ps/logs/inspect/stats/restart/start/stop/compose/pull/
  images`, `docker network ls`, `df`, `systemctl status *`,
  `journalctl *`). Commands must match the allowlist exactly — no
  `--format`, no `docker exec`. Good for read-only diagnostics without
  touching Christian's active session.
- **Ops gateway** (Phase 6/7, ADR-011/012/013) — see below. Claude
  holds one standing credential here specifically, an explicit,
  documented exception to "no standing identity," not a general
  policy change.
- **Temporary elevated access** (ADR-009): for debugging that
  genuinely needs broader API access (e.g. Authentik's admin API),
  Christian can generate a personal token, hand it over via a local
  hidden-input script (never pasted in chat), used for the session,
  then revoked. Used successfully once (2026-07-10, Authentik outpost
  403 debugging saga).
- **Identity-sensitive actions stay human-clicked deliberately** —
  creating/resetting user accounts, even post-Phase-8. Not a technical
  limitation, a considered choice (see the `family`-group test-account
  mixup in session 4 as the concrete example of why).

## Services running

### VPS (edge + identity only)
| Service | Image | Access |
|---|---|---|
| Traefik | v3.2.0 | 80/443 public, Cloudflare DNS challenge TLS |
| Vaultwarden | 1.32.7 | vault.christianmancini.de |
| Authentik | 2024.8.3 | auth.christianmancini.de |
| n8n (n8n-zuij) | legacy | tailnet-only — still running, retirement deliberately deferred, not scheduled |
| backup-gateway | rclone/rclone:1.74.4 | tailnet-only 100.94.111.98:8200, append-only B2 relay |

### NAS
| Service | Image | Access |
|---|---|---|
| n8n | 2.29.8 | tailnet 100.126.31.47:5678 (raw) + :5679 (Authentik-gated) |
| n8n-postgres | postgres:16-alpine | internal |
| Home Assistant | 2026.7.1 | LAN + tailnet :8123, host network, native auth |
| n8n-outpost + redis | goauthentik/proxy:2024.8.3 | gates n8n via Authentik, family group |
| ops-gateway + docker-socket-proxy | custom / tecnativa v0.4.2 | tailnet 100.126.31.47:8300 |

## Ops gateway (Phase 6/7/8) — what Claude can actually do right now

`http://100.126.31.47:8300`, NAS-only, tailnet-only, bearer token auth
(`svc-claude`/`svc-hermes`), every call audited to `/data/audit.log`
inside the container.

**Read** (Phase 6): `service_status/{name}`, `get_logs/{name}`,
`disk_usage`, `backup_health`. Fixed enum of service names — no
free-form input reaches Docker. Plus (Phase 8) `list_removable_containers`,
`list_removable_volumes` — dynamic discovery, not fixed-enum.

**Write** (Phase 7 v1): `restart_service/{name}` (docker-socket-proxy's
`ALLOW_RESTARTS` flag, narrow), `pull_image/{name}` (pulls the exact
pinned tag from `SERVICE_IMAGES` in `app/main.py`, never `:latest`).

**Approval** (ADR-013): `request_approval` sends a Telegram message
(reuses the existing backup-alert bot) with Approve/Deny buttons,
echoes the exact action, 10-minute expiry. `approval_status/{id}`
polls the outcome.

**Destructive, approval-gated** (Phase 8, ADR-014): `remove_container`,
`remove_volume` (cleanup-only — dynamically discovered stopped
containers / dangling volumes, never the named core services),
`prune` (bundled containers+volumes+dangling-images — `volumes/prune`
needs `filters={"all":"true"}` or named volumes survive it, a real bug
found and fixed during testing), `reboot` (file-trigger to a host-side
systemd path unit, `nas/scripts/ops-gateway-reboot.path`/`.service` —
Docker's API has no reboot endpoint, so this is the one capability
outside Docker entirely, and it's exactly one file-create, no SSH key
or privileged container). All four verified with real resources and
real Telegram approvals, including a genuine NAS reboot.

**Real finding from the reboot test**: this NAS's Docker state doesn't
reliably survive a host reboot. Two unrelated pieces of per-container
state (a redis anonymous volume, an outpost container's
auto-generated `resolv.conf`) came back with corrupted
ownership/permissions after boot, both silently, both fixed by
recreating the affected containers. Root cause not identified — see
ADR-014. Don't rely on `reboot` unattended until this is understood.

**Claude's token** lives at `C:\Users\jm2_c\.ops-gateway-token` on the
laptop only — outside both git clones, never committed, never pasted
in chat. Read fresh via Bash each call. `svc-hermes` token is in
Vaultwarden, unused until Hermes exists.

**Not built**: `deploy_from_repo` — needs container creation, which
would require broadening the docker-socket-proxy significantly
(breaks its narrow-scope model) or reusing `agent_ops`'s SSH credential
from inside the gateway (reopens a rejected tradeoff). Needs a real
design decision, not a rushed bundling — see ADR-012.

## Secrets locations (NEVER in git, NEVER in chat)

| Secret | Location |
|---|---|
| Traefik/Cloudflare DNS token | `/etc/vps-secrets/traefik.env` (VPS, 644 — deliberately world-readable so Docker's env_file works, safe since it's DNS-scope-only) |
| Authentik env | `/etc/vps-secrets/authentik.env` (VPS) |
| Backup gateway (B2 key, gateway auth) | `/etc/vps-secrets/backup-gateway.env` (VPS, 600) |
| n8n secrets (Postgres, encryption key, SMTP) | `/etc/nas-secrets/n8n.env` (NAS, 600) — **encryption key is unrecoverable if lost, in Vaultwarden too** |
| Authentik outpost token | `/etc/nas-secrets/authentik-outpost.env` (NAS, 600) |
| Ops gateway tokens | `/etc/nas-secrets/ops-gateway.env` (NAS, 600) |
| Telegram bot (shared: alerts + approvals) | `/etc/nas-secrets/notify.env` (NAS) |
| NAS restic config | `/home/mancinicn/.config/restic/b2.env` (600, mancinicn-owned — no longer holds a real B2 key since the gateway cutover, just gateway auth) |
| Claude's ops-gateway token | `C:\Users\jm2_c\.ops-gateway-token` (laptop only, outside git) |

## Domain / DNS

christianmancini.de via Cloudflare, zone `3df7fbeaa5151f36efef5c350629679f`.
Stale `pretix` (was a Cloudflare Tunnel CNAME) and `chat` records
deleted 2026-07-10 via the existing DNS-scoped Cloudflare token.

## Backup (Phase 5 — DONE, ADR-005/010)

Two daily jobs, both through the append-only gateway on the VPS
(`rclone serve restic --append-only`, B2 key with no `deleteFiles`
capability — NAS literally cannot delete existing backups even if
fully compromised, verified with a real rejected-deletion test):

- `restic-photos-backup.timer` — 03:15, `/volume1/Photos`, runs as mancinicn
- `restic-appdata-backup.timer` — 04:00, n8n data + a fresh `pg_dump` +
  HA config, runs as **root** (different file ownership than mancinicn)

Pruning: laptop only, full-capability key, never through the gateway
or the NAS. Both jobs write success markers
(`/home/mancinicn/ops-gateway-markers/`) that `backup_health` reads.

## Completed phases

0 (stop the bleeding) → 1 (config repos) → 2 (VPS cleanup) → 3 (edge +
identity) → 3.5 (agent access model) → 4 (n8n on NAS, workflow
import/VPS-retirement deliberately deferred) → 4.5 (Home Assistant) →
5 (append-only backup gateway, full coverage) → 6 (ops gateway,
read-only) → 7 v1 (restart_service, pull_image) → Telegram approval
flow (built ahead of schedule) → 8 (destructive actions: remove_container,
remove_volume, prune, reboot — verified end-to-end including a real
NAS reboot).

## Remaining phases

- **Phase 7 remainder**: `deploy_from_repo` design (see above)
- **Phase 8 follow-up** (not blocking, but real): investigate why this
  NAS's Docker state doesn't reliably survive a host reboot (see
  "Ops gateway" section above and ADR-014). The separate Authentik/
  Traefik 504 found during this investigation was resolved the same
  session — see ADR-015
- **New follow-up**: import /opt/vps-infra/ into homelab-infra (not
  currently tracked in git — see ADR-015 "Consequences")
- **Phase 9**: Immich + vault permissions
- **Phase 10**: agentic layer (Hermes goes live)

## Key decisions (ADRs 001–013, full text in `decisions/`)

Notable ones beyond what's already covered above:
- **003**: n8n canonical on NAS, not VPS
- **004**: no ERP monolith — individual tools behind SSO
- **007**: Hermes (when built) runs on NAS, tailnet-only, zero direct
  capability, gateway-mediated only — same philosophy as everything else
- **008**: NAS Docker needs `containerd-snapshotter: false` or image
  pulls fail — UGOS-specific gotcha

## Known issues / open loose ends

- **This NAS's Docker state doesn't reliably survive a host reboot**
  (found 2026-07-12, ADR-014): a real reboot test corrupted ownership/
  permissions on a redis anonymous volume and an outpost container's
  auto-generated resolv.conf, both silently, both fixed by recreating
  the affected containers. Root cause not identified — candidates
  include btrfs/mount timing on /volume1 during boot. Don't rely on
  `reboot` unattended (e.g. Hermes, Phase 10) until understood
- **RESOLVED**: Authentik was unreachable through Traefik (hangs/504s)
  — see ADR-015. Root cause: Traefik's Docker provider picked the
  wrong network IP for multi-homed authentik-server. Fixed with a
  `traefik.docker.network=proxy` label. Also fixed a latent blank-ACME-
  email gap found along the way (missing .env for compose
  interpolation). Family n8n gate (5679) confirmed working again
- **`/opt/vps-infra/` is not tracked in git** (found 2026-07-12,
  ADR-015) — edge/traefik.yml, identity/authentik.yml,
  tools/vaultwarden.yml all live VPS-only. Contradicts this project's
  own stated repo split. Worth importing into homelab-infra as a
  follow-up
- `akadmin` shows `is_active: true` with a real 2026-07-07 login,
  contradicting the documented "disabled" state — never investigated
- Wife's real Authentik account still not created (`family` group has
  a test account only); her Tailscale + n8n invites sent but
  acceptance not confirmed
- Old full-delete-capability B2 key still exists in Backblaze, unused
  now — decide whether to rotate/delete
- Stray expired Authentik token (`authtokenOutpost`) — harmless, low
  priority cleanup
- Mobile dashboard for viewing containers (Dozzle vs Portainer) —
  discussed, parked, not decided
- UGOS's own native SSH service randomly disables itself — Tailscale
  SSH bypasses this, known pre-existing quirk, not investigated further

## Operational gotcha worth repeating (cost ~45 min once already)

`docker restart` does **not** re-read `env_file` — it restarts the
existing process with whatever environment was baked in at container
creation. Updating a secrets file and then `docker restart`-ing keeps
using the OLD value silently. Always `docker compose up -d` (recreate)
after any secrets change.
