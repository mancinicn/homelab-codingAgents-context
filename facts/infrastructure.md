# Infrastructure facts

## Machines
- NAS: UGREEN DXP2800, UGOS (Debian 12), 8GB RAM, 2x4TB RAID1 btrfs
  Tailscale: nas (100.126.31.47)
- VPS: Hostinger, Ubuntu 24.04, 8GB RAM, 96GB disk
  Tailscale: 100.94.111.98, public IP: 72.60.36.129

## Domain
- christianmancini.de via Cloudflare
- Zone ID: 3df7fbeaa5151f36efef5c350629679f

## Services
- Traefik v3.2.0: TLS via Cloudflare DNS challenge
- Vaultwarden v1.32.7: vault.christianmancini.de
- Authentik 2024.8.3: auth.christianmancini.de
- n8n: tailnet-only on VPS (moving to NAS in Phase 4)
- Restic backup: NAS → B2, daily timer, verified

## Auth
- Authentik groups: authentik Admins (superuser), users, agents
- MFA: TOTP on admin account
- SMTP: Brevo (FROM mancinicn@gmail.com)
- akadmin: disabled

## Agent access
- agent_ops on NAS: SSH key, narrow sudoers (safe docker ops only)
- docker run/rm/prune BLOCKED until Phase 5 (append-only backup)
- Secrets in /etc/vps-secrets/ and /etc/nas-secrets/ (never in git)

## LLM access
- Interactive: Claude Code + OpenAI Codex (subscriptions)
- Autonomous: DeepSeek API (cheap, OpenAI-compatible)

## Backup
- restic → Backblaze B2, append-only gateway NOT YET (Phase 5)
- Telegram notification on failure (tested)
