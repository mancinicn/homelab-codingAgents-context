# Infrastructure facts

## Machines
- NAS: UGREEN DXP2800, UGOS (Debian 12), 8GB RAM, 2x4TB RAID1 btrfs
  Tailscale: nas (100.126.31.47)
- VPS: Hostinger, Ubuntu 24.04, 8GB RAM, 96GB disk
  Tailscale: 100.94.111.98, public IP: 72.60.36.129

## Domain
- christianmancini.de via Cloudflare
- Zone ID: 3df7fbeaa5151f36efef5c350629679f
- DNS API token: CLOUDFLARE_DNS_API_TOKEN in /etc/vps-secrets/traefik.env
  on the VPS (scoped to DNS read/write only). File is 644 (world-readable
  by design — Docker's env_file needs it), readable without sudo
- Stale records `pretix` (was a CNAME to a Cloudflare Tunnel,
  *.cfargotunnel.com — no cloudflared container running anywhere seen
  this session, origin presumed dead) and `chat` (plain A record to the
  VPS, but proxied/orange-cloud, NOT DNS-only as originally assumed)
  were deleted 2026-07-10

## Services
- Traefik v3.2.0: TLS via Cloudflare DNS challenge
- Vaultwarden v1.32.7: vault.christianmancini.de
  - **Master password RESET 2026-07-13** (ADR-016): old one lost, old
    vault archived at /srv/appdata/vaultwarden.locked-20260713 (VPS,
    still encrypted with the old password — keep until sure nothing
    missing). New master password; recovery via paper kit (root of
    trust), future emergency-access + encrypted exports. NO server-side
    reset exists — passkeys/TOTP are 2FA-only, cannot recover a master
    password.
  - **Vault contents**: Category A = recovery copies of 8 env/secret
    files (imported as `env: <host>:<path>` secure notes) — primary
    still lives in the env files on the boxes. Category B = external
    account passwords with no env file (UGOS, Hostinger, Cloudflare,
    Backblaze, Tailscale, GitHub, Brevo, Authentik admin/akadmin, HA,
    n8n) — vault is PRIMARY, not yet re-entered post-reset. See ADR-016.
  - **bw CLI gotcha**: current CLI is incompatible with this server
    version (404 on prelogin/password); use cli-v2024.9.0. Signals a
    Vaultwarden upgrade is due — see ADR-016.
  - **NO backup of VPS app data** (Vaultwarden vault + Authentik DB) —
    open gap surfaced 2026-07-13, unrelated to the password loss but
    same total-loss blast radius. Backlog item.
- Authentik 2024.8.3: auth.christianmancini.de
- n8n 2.29.8: on NAS, tailnet-only (http://100.126.31.47:5678), own
  Postgres 16-alpine. VPS n8n (n8n-zuij) still running — not yet retired.
  Also gated by an Authentik outpost at http://100.126.31.47:5679 (see
  below). SMTP via Brevo (smtp-relay.brevo.com:587, separate SMTP key
  from Authentik's, sender mancinicn@gmail.com) — verified working
  2026-07-10. Tailscale ACL now scopes group:family to ports 8123/5679
  only on the NAS, so 5678 is effectively admin-only via the tailnet
  (still technically bound and reachable by Christian's own devices)
- Home Assistant 2026.7.1: on NAS, host network
  (http://100.126.31.47:8123 + LAN), native auth, config at
  /volume1/appdata/homeassistant

## Authentik outpost (n8n family gate)
- Outpost object: `n8n-outpost-standalone` (pk 58496339-3660-4e26-8c2d-4d7fc7ee358d)
  — a manually-created, unmanaged outpost. NOT the built-in "authentik
  Embedded Outpost" (pk 3df9e0dc-...) — that one was used by mistake
  initially (see decisions/009), its provider binding has been removed,
  leave it alone going forward.
- Provider: `n8n-family` (Proxy mode, internal host http://n8n:5678,
  external host http://100.126.31.47:5679)
- Application: `n8n (Family)` (slug n8n-family), policy_engine_mode
  "any", bound to groups `family` and `authentik Admins`
- Outpost containers on NAS: `n8n-outpost` + `n8n-outpost-redis`
  (compose: nas/automation/n8n/outpost-compose.yml). The outpost needs
  its own Redis for session storage — do NOT point it at the VPS's
  authentik-redis (internal-only to VPS's docker network by design)
- Token: /etc/nas-secrets/authentik-outpost.env on NAS (never in git,
  never in chat — see nas/scripts/save-authentik-outpost-token.sh)
- Groups: `family` group exists but has no real members yet (only a
  test account). Wife's real Authentik account (birteloeckel@gmail.com)
  was never actually created — still to do.
- Restic backup: NAS → B2, daily timer, verified (does NOT yet cover
  /volume1/appdata — that's Phase 5)

## NAS Docker
- data-root: /volume1/docker (moved off UGOS's overlay-on-overlay root fs)
- storage driver: overlay2 (containerd snapshotter explicitly disabled —
  see ADR-008, breaks image extraction on this box otherwise)
- /etc/docker/daemon.json:
  {"data-root": "/volume1/docker", "features": {"containerd-snapshotter": false}}
- **Known issue (2026-07-12, ADR-014)**: /volume1/docker and
  /volume1/appdata are NOT registered as UGOS Shared Folders (set up
  via hand-edited daemon.json instead) — UGOS's own index_serv file-
  indexing daemon can't determine their type
  (`sharefolder.IsShareFolder` fails with a parse error, 748x in 6
  hours on 2026-07-12) and races unpredictably with Docker's own
  writes, especially during the write-burst of a reboot. Root cause
  of the redis/resolv.conf/n8n reboot-survival incidents. UI fix path
  blocked — UGOS's "Create Shared Folder" can't adopt an existing
  directory (confirmed by a real attempt, name-collision error).
  Decision: accept "recreate every container after any reboot" as the
  standing mitigation for now; revisit via UGREEN support later

## Auth
- Authentik groups: authentik Admins (superuser, 2 members: admin,
  akadmin), authentik Read-only (unused), users, agents, family (new,
  see outpost section below)
- MFA: TOTP on admin account
- SMTP: Brevo (FROM mancinicn@gmail.com)
- akadmin: DISCREPANCY — documented as disabled, but confirmed via API
  2026-07-10 as `is_active: true` with a real login on 2026-07-07. Not
  yet resolved; decide whether to actually disable it or investigate
  the July 7 login

## Agent access
- agent_ops on NAS: SSH key, narrow sudoers (safe docker ops only)
- docker run/rm/prune BLOCKED until Phase 5 (append-only backup) — DONE
- Secrets in /etc/vps-secrets/ and /etc/nas-secrets/ (never in git)
- Ops gateway (Phase 6+7+8, ADR-011/012/013/014): http://100.126.31.47:8300,
  NAS-only, tailnet-only. Read: service_status, get_logs, disk_usage,
  backup_health, list_removable_containers, list_removable_volumes.
  Write (Phase 7 v1): restart_service (docker-socket-proxy
  ALLOW_RESTARTS flag, narrow), pull_image (IMAGES+POST, pulls the
  exact pinned tag from SERVICE_IMAGES in app/main.py, never :latest).
  Destructive, approval-gated (Phase 8): remove_container,
  remove_volume (cleanup-only — stopped containers / dangling volumes
  only, never the named core services), prune (bundled
  containers+volumes+dangling-images, requires filters={"all":"true"}
  on volumes/prune or named volumes survive it — real bug found and
  fixed during testing), reboot (file-trigger to a host-side systemd
  path unit — nas/scripts/ops-gateway-reboot.path/.service — Docker's
  API has no reboot endpoint at all, so this is the one capability
  outside Docker entirely, and it's exactly one file-create, no SSH
  key). Telegram approval flow (request_approval, approval_status)
  built ahead of Phase 8 per Christian's choice — reuses the existing
  backup-failure notification bot (/etc/nas-secrets/notify.env), 10min
  expiry, verified end-to-end twice including a message-editing fix so
  the outcome shows visibly in Telegram, not just in the API. Now
  proven against real destructive actions (Phase 8), not just a
  synthetic request. deploy_from_repo still deferred, see ADR-012.
  Bearer token auth (svc-claude, svc-hermes), every call audited.
  Claude holds a standing svc-claude token (a deliberate extension
  beyond ADR-006's borrowed-session model, made explicitly — see
  session 6 / decisions), stored locally on the laptop only
  (C:\Users\jm2_c\.ops-gateway-token, outside both git clones), never
  in git or chat. svc-hermes token generated and in Vaultwarden,
  unused until Hermes exists (Phase 10)
- **Open finding (2026-07-12, ADR-014)**: this NAS's Docker state does
  not reliably survive a host reboot — the real Phase 8 reboot test
  corrupted ownership/permissions on two unrelated pieces of
  per-container state (a redis anonymous volume, an outpost
  container's auto-generated resolv.conf), both silently, both fixed
  by recreating the affected containers. Root cause not identified —
  investigate before relying on `reboot` unattended (e.g. via Hermes,
  Phase 10)
- **Resolved (2026-07-12, ADR-015, VPS-side)**: Authentik was
  completely unreachable through Traefik (hangs / 504s) — root cause
  was Traefik's Docker provider picking the wrong network IP for
  authentik-server, which is multi-homed (proxy + authentik-internal).
  Fixed with an explicit `traefik.docker.network=proxy` label on
  authentik-server. Any future multi-homed service behind Traefik
  needs this same label proactively. Along the way, also fixed a
  latent gap where Traefik's ACME email was silently blank on every
  recreate (missing .env file for compose variable interpolation,
  separate from its env_file mechanism) — see ADR-015 for both.
  /opt/vps-infra/ (edge/traefik.yml, identity/authentik.yml,
  tools/vaultwarden.yml) — previously untracked, live-only on the VPS
  — has since been imported into homelab-infra under vps/edge/,
  vps/identity/, vps/tools/ and pushed back so live and repo match

## LLM access
- Interactive: Claude Code + OpenAI Codex (subscriptions)
- Autonomous: DeepSeek API (cheap, OpenAI-compatible)

## Backup
- restic → Backblaze B2, bucket ugreen-restic-62fdead3d97f, THROUGH the
  append-only gateway (Phase 5 DONE, cutover completed 2026-07-12)
- Append-only gateway (ADR-010): `backup-gateway` container on VPS,
  tailnet-only (100.94.111.98:8200), rclone/rclone:1.74.4 running
  `serve restic --append-only`. NAS can add new backups, cannot delete
  existing ones — enforced independently by both the B2 key's
  capabilities and the gateway's own restic-protocol-aware logic
- NAS config: /home/mancinicn/.config/restic/b2.env — RESTIC_REPOSITORY
  now `rest:http://nas-backup:...@100.94.111.98:8200/`, no longer holds
  any B2 credential directly. Pre-cutover version backed up alongside
  it as `b2.env.pre-gateway-<timestamp>` (contains the OLD full-delete
  B2 key — safe to delete once the new setup has run a few days)
- Secrets: /etc/vps-secrets/backup-gateway.env (VPS, 600 root:root) —
  RCLONE_CONFIG_B2GATEWAY_* (new restricted B2 key, no deleteFiles
  capability) + GATEWAY_USER/GATEWAY_PASS (NAS's credential to the
  gateway, unrelated to B2)
- Backup jobs (both through the gateway, both tagged, both with
  Telegram failure alerts via notify-backup-fail@.service):
  - `restic-photos-backup.timer` — daily 03:15, runs as mancinicn,
    tag "photos", /volume1/Photos
  - `restic-appdata-backup.timer` — daily 04:00, runs as **root**
    (n8n's data dir is uid 1000, HA's config dir has a different
    owner too — mancinicn can't read either), tag "appdata": n8n's
    data dir + a fresh `pg_dump` of n8n's Postgres (dumped to
    /volume1/appdata/n8n/n8n-postgres-dump.sql, overwritten each run —
    raw-copying a live Postgres data dir risks an inconsistent
    snapshot) + Home Assistant's config dir. Verified 2026-07-12: real
    Postgres data confirmed in the dump (301KB via `restic ls --long`,
    not empty), correct paths/tags in the snapshot
- Pruning: still only ever from Christian's laptop, directly against
  B2, using the original full-capability key (unchanged from ADR-005)
- Telegram notification on failure (tested)

## Operational gotcha — env_file changes need recreate, not restart
`docker restart <container>` does NOT re-read `env_file` from disk — it
restarts the existing process with whatever environment was baked in at
container CREATION time. Updating a secrets file and then running
`docker restart` silently keeps using the OLD value; there is no error,
it just doesn't take effect. To pick up an env_file change, run
`docker compose -f <file> up -d` again (recreates the container) —
this is what nas/scripts/deploy-outpost.sh and deploy-phase4.sh do.
Cost ~45 minutes of debugging on 2026-07-10 (see decisions/009)
because a token rotation kept appearing to fail when the container
was simply never seeing the new value. Applies to any service here
using env_file for secrets (n8n, HA if ever needed, the outpost).
