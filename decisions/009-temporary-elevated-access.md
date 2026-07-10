# ADR-009: Temporary elevated access for debugging

## Date: 2026-07-10
## Status: accepted

## Decision
ADR-006 established that coding agents get no standing identity — they
borrow Christian's supervised session and observe via `agent_ops`. This
ADR adds one narrow extension: when debugging genuinely requires broader
read/write access than `agent_ops` or the borrowed SSH session provides
(e.g. inspecting/fixing Authentik's internal config via its admin API),
Christian may generate a **temporary, personal, revocable API token**
for the agent to use, under these rules:

- Generated from Christian's own account, explicitly for this purpose
- Never pasted into chat — saved directly to a local file via an
  interactive, hidden-input script (mirrors the existing NAS secrets
  pattern, just run locally instead of server-side)
- Used only for the duration of the debugging session
- Revoked by Christian immediately after, confirmed manually (not
  agent-initiated deletion of its own access token)
- All actions taken with it should still be logged (session log/ADR),
  same as any other change

## Reasoning
Session on 2026-07-10 hit a debugging wall that pure UI-walkthrough
guidance couldn't resolve efficiently: an Authentik proxy outpost kept
failing with 403 errors after every fix attempt, across many rounds of
back-and-forth. Root cause (see facts/infrastructure.md "Operational
gotcha") turned out to be that `docker restart` doesn't reload
`env_file`, so every token "fix" was silently never taking effect — a
problem invisible from the UI side and only discoverable by directly
querying Authentik's API to check outpost/token/provider state.
A temporary admin token, explicitly authorized and revocable by
Christian, cut this from an open-ended UI-relay loop to a few direct
API calls.

## Consequences
- This is an exception process, not a new standing capability — the
  default remains ADR-006's model
- Future sessions can propose this same pattern for similarly
  API-inspectable debugging (Authentik, or any other service with a
  read/write API) rather than reinventing it
- Not a substitute for Phase 6's ops gateway — that will provide
  properly scoped, durable, audited access; this is a stopgap for
  situations the gateway doesn't cover yet

## Related finding (same session)
Authentik proxy outposts must be created as **new, unmanaged** objects
(`managed: null`), not reused from the built-in "authentik Embedded
Outpost" (`managed: goauthentik.io/outposts/embedded`). The embedded
outpost is meant to run inside Authentik's own server process; using it
for an external standalone container is unsupported and led to
config/provider conflicts. See facts/infrastructure.md for the current
outpost's correct pk/config.
