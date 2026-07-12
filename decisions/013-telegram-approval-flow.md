# ADR-013: Telegram approval flow

## Date: 2026-07-12
## Status: accepted (build in progress)

## Note on sequencing
ADR-012 said this should be built once Phase 8 has a real destructive
action to test it against, not in isolation. Christian explicitly
chose to build it now anyway, ahead of Phase 8. Recorded here as a
deliberate change from the prior plan, not a silent contradiction of
it. Consequence: this gets verified with a synthetic/dry-run request
(no real action behind it) rather than a genuine destructive operation
— re-verify against a real Phase 8 action once one exists.

## Decision
- **Reuse the existing Telegram bot/chat** (`TELEGRAM_TOKEN`,
  `TELEGRAM_CHAT_ID` in `/etc/nas-secrets/notify.env`, already used by
  `notify-backup-fail@.service`) rather than provisioning a separate
  bot. Unlike the Brevo/B2 cases, there's no meaningful isolation
  benefit to a second bot for the same administrative channel
  (Christian's own Telegram, already the trusted destination for
  backup failure alerts) — it would just be credential sprawl.
- **New endpoints on the same ops-gateway app**: `POST
  /request_approval` (authenticated, same bearer tokens as every other
  action) creates a pending request, sends a Telegram message with
  inline Approve/Deny buttons, returns a request ID. `GET
  /approval_status/{request_id}` lets the calling agent poll for the
  outcome.
- **In-memory pending-request store**, not persisted to disk. Requests
  expire in 10 minutes; a lost gateway restart losing in-flight
  requests is an acceptable tradeoff for something this short-lived —
  simpler than persistence for marginal benefit.
- **A background long-poll task** (started at app startup) calls
  Telegram's `getUpdates` continuously, matches `callback_query`
  responses to pending requests by an ID embedded in `callback_data`.
- **Only the authorized `chat_id` can approve/deny** — any
  `callback_query` from a different chat is ignored outright, not
  just logged. Prevents anyone else who somehow messages the bot from
  approving anything.
- **The Telegram message echoes the exact operation** (action, target,
  details, request ID, expiry) — per the original Phase 7 spec, so
  Christian is never approving something vague.

## Consequences
- This mechanism exists and is provably correct, but nothing calls it
  for a real action yet — Phase 8's destructive actions are what will
  actually use it
- The gateway container needs a second `env_file` (notify.env) added
  to its compose service — a new dependency on a secrets file it
  didn't previously read
- If the gateway restarts while a request is pending, that specific
  request is lost (the requesting agent's poll of `/approval_status`
  would need to handle "unknown request ID" as effectively "denied/
  expired", not hang indefinitely)
