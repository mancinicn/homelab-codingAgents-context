# ADR-023: Hermes v1.1 — conversational chat + Home Assistant (read + control)

## Date: 2026-07-16
## Status: accepted, built, not yet activated

## Decision
Extend Hermes v1 (ADR-022, Watchdog-only) with two capabilities
Christian asked for directly: a real conversation with Hermes, and
Home Assistant integration. Both land in the same code
(`nas/agents/hermes/app/main.py`), sharing one approval mechanism.

**Scope, decided with Christian after real findings, not assumptions**:
- HA: read (entity states) + control (service calls, e.g. turning
  devices on/off) now. Automation/dashboard authoring explicitly
  deferred — see "Findings" below for why that's not a small addition.
- Chat: read (any question) + write (restart a service, call an HA
  service) — Christian chose the fuller-capability option over a
  read-only-first v1. Every write goes through an approval step.

## Findings (checked, not assumed — both changed the design)
- **HA long-lived tokens have no built-in scoping.** Confirmed via
  HA's own community forum — an open, unresolved feature request
  ("Support for permissions on Long-Lived Access Tokens"). A token
  always carries the full permission level of whichever account
  created it. The only lever is a dedicated restricted (non-admin) HA
  user, token generated from that account — coarse, not fine-grained.
- **The HA REST API has no automation/dashboard endpoints at all.**
  Verified against every endpoint in HA's own developer docs
  (`/api/states`, `/api/services/<domain>/<service>`, `/api/history`,
  `/api/calendars`, etc. — nothing for config authoring). Doing that
  would need either direct filesystem writes to HA's live config (a
  malformed automations.yaml can break HA's config loading entirely)
  or HA's undocumented internal WebSocket API. Genuinely a separate,
  bigger increment — not bolted onto this one.

## Design
- **Two Telegram bots, deliberately separate.** The existing shared
  bot (`notify.env`) only ever sends outbound alerts and receives
  structured `callback_query` button presses — narrow, already-audited.
  A chat bot accepts arbitrary free text fed to an LLM that can propose
  real actions — a genuinely larger attack surface, so a leaked
  chat-bot token shouldn't also compromise the approval/notification
  channel. This is a real isolation benefit, unlike the reasoning that
  originally justified reusing one bot everywhere (ADR-013) — that was
  about two bots doing the *same narrow job*, not two different jobs
  with different risk profiles.
- **Unified approval mechanism, built into Hermes itself** — not
  reused from the ops-gateway's own `/request_approval` (that's scoped
  to ops-gateway's own destructive actions; Hermes now needs to gate
  both infra restarts AND HA service calls, an entirely different
  domain ops-gateway knows nothing about). One consistent in-memory
  pending-approval flow, same 10-minute-expiry shape as ops-gateway's,
  Approve/Deny **buttons** on the chat bot (never a free-text "yes" —
  softer, more misinterpretable, same reasoning ops-gateway's own flow
  already uses buttons for).
- **Reads execute immediately, writes always need approval** — same
  split as Watchdog's own defense-in-depth design (ADR-022): the model
  never gets unilateral authority over anything that changes real
  state, whether that's a Docker container or a physical device.
- DeepSeek is given a compact live snapshot (infra service statuses +
  HA entity id/name/state list) on every chat message, so it can
  ground entity_id guesses in what's actually installed rather than
  inventing plausible-looking ones. Classification fails closed to
  `"unclear"` on any error or malformed response — it never silently
  proposes an action it isn't confident about.

## Consequences
- `save-hermes-secrets.sh` now prompts for three more values
  (`HERMES_CHAT_BOT_TOKEN`, auto-detects `HERMES_CHAT_CHAT_ID` from the
  bot's own `getUpdates`, `HA_TOKEN`) alongside the original two — chat
  and HA can be left blank and added later without a rebuild, matching
  how every optional capability in this project rolls out (missing
  secret = that feature silently doesn't run yet).
- Chat's write path and HA's write path share the exact same
  approval/execution code — adding a third write-capable domain later
  (if one ever comes up) is "one more `execute_approved` branch," not a
  new mechanism.
- **Deferred, explicitly**: automation/dashboard authoring. Needs its
  own scoping of the filesystem-vs-WebSocket-API tradeoff and its own
  risk design — most likely "Hermes drafts YAML for Christian to review
  and apply himself" rather than writing live HA config unsupervised,
  given a mistake there can break Home Assistant outright, not just a
  Docker container.
- Not yet running for real — same as ADR-022, blocked on Christian's
  setup steps (new bot + chat_id, restricted HA user + token), not
  urgent.
