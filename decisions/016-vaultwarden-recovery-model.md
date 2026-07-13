# ADR-016: Vaultwarden master-password loss, reset, and recovery model

## Date: 2026-07-13
## Status: accepted (implemented)

## What happened
Christian lost the Vaultwarden master password. Confirmed via live
diagnosis (tailing the container log during a login attempt): repeated
`Username or password is incorrect` / 400 on `/identity/connect/token`
for `mancinicn@gmail.com`, with no 2FA configured on the account — so
purely a wrong-password rejection, not a 2FA lockout. There is **no
server-side master-password reset by design**: the vault is encrypted
with the master password and Vaultwarden never sees it. Metadata query
of the SQLite DB confirmed a single account, one Chrome device last
seen 2026-07-09, org "homelab-Infra", 9 encrypted items (contents
unreadable). No logged-in client could be found to export from.

## Decision 1: reset by archive, not delete
Rather than destroy the old (still-encrypted) vault, archived it intact
and started fresh:
```
docker stop vaultwarden
mv /srv/appdata/vaultwarden /srv/appdata/vaultwarden.locked-20260713
mkdir -p /srv/appdata/vaultwarden
docker start vaultwarden
```
The archive at `/srv/appdata/vaultwarden.locked-20260713` (VPS) is the
only copy of the original 9 items — still decryptable IF the old
password is ever remembered. Delete only once the new vault is fully
repopulated and nothing is found missing. Reversible by design.

Christian re-registered same email + a NEW master password, written on
paper FIRST (see recovery model below).

## Decision 2: three-layer recovery model
Passkeys/authenticators CANNOT recover or replace a Vaultwarden master
password — they only work as 2FA (a second lock, which if anything adds
lockout risk). Verified against this version (1.32.7): login-with-
passkey is not supported; WebAuthn/TOTP are 2FA-only. So recovery is:

1. **Paper emergency kit** (done): URL + email + master password on
   paper, stored with physical documents. The two truly-unrecoverable
   secrets (n8n encryption key, restic repo password) also go on the
   paper, not just in the vault.
2. **Emergency access**: designate a trusted contact (wife, once her
   account exists) with a wait-period takeover. Not yet set up —
   pending her account.
3. **Periodic encrypted export**: Settings -> Export vault (password-
   protected JSON) into /volume1/appdata/ on the NAS, which the
   append-only B2 backup then carries offsite. Not yet automated —
   manual for now.

## Decision 3: what the vault is FOR (contents checklist)
**Category A — recovery copies** (primary lives in env files on the
boxes; vault is the offsite backup). Imported 2026-07-13 as secure
notes named `env: <host>:<path>`, reprompt-on-view, via the bw CLI run
by Christian on each box (values never passed through chat/scrollback —
see nas/../vps/scripts/import-envfiles-to-vault.sh). 8 files:
- NAS: n8n.env, authentik-outpost.env, ops-gateway.env, notify.env,
  restic b2.env
- VPS: traefik.env, authentik.env, backup-gateway.env
- ⚠️ unrecoverable if lost: n8n encryption key (in n8n.env), restic
  repository password (in b2.env)

**Category B — external account passwords with no env file** (vault is
the PRIMARY store; this is what was actually lost and must be re-entered
by hand in the web vault): UGOS NAS admin, Hostinger, Cloudflare,
Backblaze account + full-capability B2 pruning key, Tailscale, GitHub,
Brevo, Authentik admin + akadmin, Home Assistant admin, n8n admin.
Not yet re-entered — Christian's manual follow-up.

## Gotcha: bw CLI version must match the server
Current Bitwarden CLI (2026) calls `POST /identity/accounts/prelogin/
password`, which Vaultwarden 1.32.7 (late-2024) does not implement ->
404, login fails. Fix: use a 2024-era CLI
(`cli-v2024.9.0/bw-linux-2024.9.0.zip` from bitwarden/clients releases)
which matches. Broader signal: Vaultwarden 1.32.7 is now old enough
that current official clients are starting to break against it — a
pinned Vaultwarden upgrade should be scheduled (fold into the same
future session as the VPS backup job, since a backup should precede a
vault-server upgrade anyway).

## Consequences
- Vault access restored; Category A recovery secrets now backed up
  offsite-capable for the first time
- New standing follow-ups: Category B manual entry, emergency access
  (needs wife's account), automated encrypted export, Vaultwarden
  upgrade, and the still-open VPS application-data backup gap (Vault +
  Authentik DB have NO backup — surfaced during this review, unrelated
  to the password loss but the same blast radius)
- Paper kit is now the actual root of trust for vault recovery —
  losing it plus the master password = the 9→8 items are gone again,
  though Category A is re-derivable from the boxes and Category B from
  each provider's own reset flow