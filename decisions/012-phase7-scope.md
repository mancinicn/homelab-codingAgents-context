# ADR-012: Phase 7 v1 scope — restart_service and pull_image only

## Date: 2026-07-12
## Status: accepted (build in progress)

## Decision
Phase 7 v1 adds two new WRITE actions to the existing ops gateway
(same app, same auth, same audit log as Phase 6):

- **`restart_service`** — via `docker-socket-proxy`'s dedicated
  `ALLOW_RESTARTS=1` flag. `POST` stays `0` globally; this flag grants
  *only* the restart operation, nothing else. Same fixed-enum service
  names as the read-only actions.
- **`pull_image`** — via `IMAGES=1` + `POST=1` on the proxy. Checked
  the proxy's actual behavior first (not assumed): there is no
  granular "pull-only" flag — `IMAGES=1`+`POST=1` technically also
  permits image push and removal at the Docker API level, even though
  the gateway's own API only ever exposes a `pull_image` endpoint.
  Accepted this tradeoff for v1: no registry push credentials are
  configured anywhere on this NAS (push would fail regardless), and
  image removal of anything in use is blocked by Docker itself. Real
  but low residual risk, documented rather than silently accepted.

## Deferred: `deploy_from_repo`
Investigated and deliberately NOT built in this pass. A real
`docker compose pull && up -d` needs container CREATION (not just
restart of an existing one), which under the docker-socket-proxy model
means enabling `NETWORKS`, `VOLUMES`, and `CONTAINERS`+`POST` — at that
point the proxy's grant is broad enough that the narrow-scope model
this whole gateway is built on stops meaning much. The alternative
(reusing `agent_ops`'s existing `docker compose *` sudoers rule via
SSH from inside the gateway container) reintroduces the credential
concern already rejected in ADR-011 (a real SSH key with broader reach
than the specific action, sitting inside a container). Neither option
is clean enough to ship without more thought — this needs its own
design pass, not a rushed bundling into today's work.

## Deferred: Telegram approval flow
The original Phase 7 spec paired "operate scope" actions with building
the approval-flow infrastructure for destructive requests. Since no
destructive action exists yet (that's Phase 8), there's nothing real
to gate — building the approval mechanism now would mean testing it
against a synthetic/fake request rather than a real one. Deferred to
Phase 8, built and proven against the actual first destructive action
rather than in isolation.

## Consequences
- `agent_ops`'s sudoers remains the only path to `docker compose`,
  broader image management, and anything else not covered by these two
  new gateway actions — unchanged from before this phase
- `restart_service`/`pull_image` are logged in the same audit log as
  read actions — no new logging mechanism needed
- Revisit `deploy_from_repo` as its own piece of work once there's a
  clearer answer to the proxy-scope-vs-SSH-credential tradeoff above
