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
- Vaultwarden v1.36.0 (upgraded from 1.32.7 on 2026-07-13, ADR-017 —
  backup-verified first; no breaking changes; fixes the bw-CLI version
  mismatch): vault.christianmancini.de
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
- n8n 2.30.4 (auto-updated from 2.29.8 by the ADR-019 controller
  2026-07-14): on NAS, tailnet-only (http://100.126.31.47:5678), own
  Postgres 16-alpine. VPS n8n (n8n-zuij) **retired 2026-07-15** — see
  "n8n-zuij retirement" below. Also gated by an Authentik outpost at
  http://100.126.31.47:5679 (see below). SMTP via Brevo
  (smtp-relay.brevo.com:587, separate SMTP key
  from Authentik's, sender mancinicn@gmail.com) — verified working
  2026-07-10. Tailscale ACL now scopes group:family to ports 8123/5679
  only on the NAS, so 5678 is effectively admin-only via the tailnet
  (still technically bound and reachable by Christian's own devices)
- Home Assistant 2026.7.2 (auto-updated from 2026.7.1 by the ADR-019
  controller 2026-07-14): on NAS, host network
  (http://100.126.31.47:8123 + LAN), native auth, config at
  /volume1/appdata/homeassistant

## Authentik outpost (n8n family gate)
- Outpost object: `n8n-outpost-standalone` (pk 58496339-3660-4e26-8c2d-4d7fc7ee358d)
  — a manually-created, unmanaged outpost. NOT the built-in "authentik
  Embedded Outpost" (pk 3df9e0dc-...) — that one was used by mistake
  initially (see decisions/009), its provider binding has been removed,
  leave it alone going forward.
- Provider: `n8n-family` (Proxy mode, internal host http://n8n:5678,
  external host `https://n8n.christianmancini.de` — updated 2026-07-15,
  see "Public n8n route" below; was `http://100.126.31.47:5679`
  tailnet-only before that)
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

## Public n8n route (2026-07-15)
`n8n.christianmancini.de` now reaches the canonical NAS n8n through the
VPS's Traefik — the first cross-host route in this setup (VPS Traefik
previously had only a Docker provider; the NAS backend isn't Docker-
discoverable at all from the VPS).
- Config: `vps/edge/traefik.yml` (adds `--providers.file.directory=
  /data/dynamic` + `--providers.file.watch=true`) + `vps/edge/dynamic/
  n8n.yml` (two routers on Host(`n8n.christianmancini.de`): `n8n-webhook`,
  higher priority, `PathPrefix(\`/webhook\`)` → straight to n8n's raw
  port 5678, bypassing Authentik entirely for incoming webhooks;
  `n8n-ui`, catch-all, → the existing family-scoped outpost on 5679).
  **Deploy gotcha**: the dynamic config directory must land at
  `/srv/appdata/traefik/dynamic/` (the actual bind-mounted `/data`
  volume) — NOT `/opt/vps-infra/edge/dynamic/` (just where the compose
  file itself lives). Got this wrong once already.
- DNS: Cloudflare record for this hostname existed already (pre-rebuild
  leftover) but was Proxied (orange-cloud) — switched to DNS-only to
  match every other hostname on this domain.
- **Found + fixed a real pre-existing bug along the way**: the bare
  `- CLOUDFLARE_DNS_API_TOKEN` line under `traefik.yml`'s `environment:`
  was silently unsetting whatever `env_file:` provided on every
  recreate (Compose resolves bare entries from its own parse-time
  context, not `env_file:`). Never noticed because existing domains'
  certs were already cached — would have silently broken renewal for
  every domain on this Traefik at their next ~90-day expiry. Fixed by
  removing that line; `env_file:` alone is correct for a secret.
- Verified working: webhook path bypasses auth (hits n8n directly, 404
  on a nonexistent test path — correct n8n behavior, not an auth
  redirect); UI path redirects to the Authentik outpost; TLS cert
  issued cleanly (`cf` resolver); Vaultwarden/Authentik still healthy
  after the Traefik recreates.
- **DONE 2026-07-15**: Christian updated the `n8n-family` provider's
  External host to `https://n8n.christianmancini.de` himself via the
  Authentik admin UI. Verified — the outpost's login redirect now
  correctly targets the public hostname (`.../outpost.goauthentik.io/
  start?rd=https%3A%2F%2Fn8n.christianmancini.de%2F`), not the tailnet
  IP. Public route is fully working end-to-end.

## n8n-zuij retirement (2026-07-15)
The legacy VPS n8n (project `n8n-zuij`, container `n8n-zuij-n8n-1`) is
gone — container, its `n8n-zuij_n8n_data` volume, and the
`n8n-zuij_default` network all removed. Not archived — Christian's
explicit call ("delete all... can do again when needed") after seeing
what was actually in it.

**Why it wasn't just imported/archived**: audited its 8 workflows
first (`n8n export:workflow --all`). Two weren't prefixed `TEMP` — "My
workflow" (an MCP-exposed Notion search tool, inactive, looked benign)
and **"My workflow 2", which was ACTIVE** and genuinely concerning: an
unauthenticated webhook trigger wired directly to an SSH-command node
(stored "SSH Password account" credential) that, on any POST, would
SSH into a remote host and ensure a persistent `tmux` session literally
named `hermes` exists there (`tmux new-session -d -s hermes ...`) —
functionally a standing, webhook-triggerable backdoor/shell, not
something to bring into the canonical instance without understanding
its origin first. The workflow definition (not the credential secret
itself — n8n exports don't include those) is preserved in the
already-delivered export file if this ever needs investigating; the
live instance holding it is gone.

The other 6 `TEMP`-prefixed workflows (3x "Rolodex Postgres Bootstrap",
3x "Hermes SQL Runner pg_datahub_prod") were dropped without import —
looked like disposable scaffolding, not reviewed in depth beyond that.

Also removed with it: the `credentials-export.json` plaintext
credentials dump that had been sitting in its data volume since Oct
2025 (flagged earlier in the day, never opened by an agent).

One untouched leftover: `/docker/n8n-zuij/` on the VPS (just the old
compose file + backups, root-owned, no real data) — couldn't remove
without sudo, low priority, Christian's call whenever.

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
  Destructive/write, approval-gated: remove_container,
  remove_volume (cleanup-only — stopped containers / dangling volumes
  only, never the named core services), prune (bundled
  containers+volumes+dangling-images, requires filters={"all":"true"}
  on volumes/prune or named volumes survive it — real bug found and
  fixed during testing), deploy (Phase 7 remainder, ADR-018 — file-
  trigger to a host systemd unit running `docker compose up -d <svc>`
  against a fixed allowlist DEPLOYABLE_SERVICES = the 5 core services;
  no docker socket/SSH key in the container; ops-gateway itself
  excluded), reboot (file-trigger to a host-side systemd
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

## Auto-update controller (ADR-019, 2026-07-14)
- Weekly root systemd timer on the NAS (image-autoupdate.timer, Sun
  05:00 after backups) → /usr/local/bin/image-autoupdate.sh. Auto-
  updates managed services within their major line, health-checks each,
  AUTO-ROLLS-BACK on failure. v1 manages n8n + Home Assistant only.
- Running version lives in each compose dir's ./.env (N8N_VERSION,
  HA_VERSION) — git-tracked (narrow .gitignore exceptions; version-only,
  no secrets). The compose image line reads ${VAR}; compose auto-reads
  the .env. The updater rewrites the .env line (never edits yaml) and
  `docker compose up -d <svc>`; rollback = rewrite + up -d.
- Never auto-crosses a major (n8n semver major; HA calendar year) —
  Telegram-notify-only for those. Reuses the notify bot. --dry-run and
  --only <svc> flags; IMAGE_AUTOUPDATE_FORCE_HEALTH_FAIL=1 test hook.
- Adding a service: one config row in the script + parameterize its
  compose image via ${VERSION} + a real health check.
- Known v1 gap: git-drift — the updater edits the STAGED .env on the
  NAS; the repo .env is reconciled manually at commit time until the
  git-on-NAS v2 (same v2 as deploy_from_repo). Also ops-gateway
  SERVICE_IMAGES (pull_image) can lag — low harm.

## LLM access
- Interactive: Claude Code + OpenAI Codex (subscriptions)
- Autonomous: DeepSeek API (cheap, OpenAI-compatible)

## Backup
- restic → Backblaze B2, bucket ugreen-restic-62fdead3d97f, THROUGH the
  append-only gateway (Phase 5 DONE, cutover completed 2026-07-12)
- **VPS self-backup (ADR-017, 2026-07-13)**: the VPS now backs ITSELF
  up (Vaultwarden vault + Authentik pg_dump + Traefik acme.json) to a
  SEPARATE restic repo — a `/vps` subpath of the same bucket, served by
  a second rclone instance `backup-gateway-vps` on 127.0.0.1:8201
  (localhost-only, append-only). Separate encryption password held only
  on the VPS (in Vaultwarden + paper kit, unrecoverable). restic 0.19.1
  installed on the VPS. Daily 04:30 via restic-vps-backup.timer.
  Verified: restore-and-diff + a 403-on-DELETE immutability check.
  Telegram-on-failure wired but silent until notify.env is populated.
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
