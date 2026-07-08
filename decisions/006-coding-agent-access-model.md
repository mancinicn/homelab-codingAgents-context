# ADR-006: Coding-agent (Claude Code / Codex) access model

## Date: 2026-07-08
## Status: accepted

## Decision
Supervised coding agents (Claude Code, Codex) get NO standing identity of
their own on the infrastructure. They borrow Christian's:

- They run inside Christian's interactive session (laptop, or VPS tmux)
  and use his ssh-agent with passphrase-protected keys. Every
  infra-touching command therefore requires Christian to have unlocked
  his own session first — a built-in human-in-the-loop control.
- No dedicated Linux account, no dedicated SSH key, no sudoers entry
  for coding agents.
- Read-only observation of the NAS goes through `agent_ops`
  (`ssh agent_ops@nas`, narrow sudo allowlist) — shared with the
  refresh-state script.
- Repo work (compose files, scripts, docs, ADRs) is unrestricted;
  that is their primary job.
- Live changes to VPS/NAS remain gated by the invariants: no agent
  write/destructive capability until the append-only backup gateway
  (Phase 5) exists, and destructive always means stop-and-ask.
- When the Ops Gateway exists (Phase 6), coding agents move to a scoped
  bearer token (svc-claude) for named actions, and direct SSH use
  shrinks accordingly.

## Distinction from agent_ops
- `agent_ops` = maintenance/observation identity (status, logs, disk,
  restart of permitted services). It is not the coding-agent identity.
- Coding agents = infrastructure engineering (repos, config, structure)
  under human supervision.

## Rejected alternatives
- Dedicated privileged account for coding agents: standing credentials
  with broad power, active before the backup safety net exists
- Running coding agents unsupervised on the VPS: puts an agent with
  wide capability on the only internet-facing box
- Containerized dev environment: adds setup cost now for isolation that
  supervision + invariants already provide; revisit if unsupervised
  operation is ever wanted

## Consequences
- Coding-agent capability is exactly Christian's capability, minus what
  the invariants forbid — simple to reason about
- Nothing to rotate or revoke when a session ends
- Autonomous agents (Hermes) need a different model — see ADR-007
