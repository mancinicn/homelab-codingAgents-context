# ADR-007: Autonomous agent (Hermes) placement and boundaries

## Date: 2026-07-08
## Status: accepted (build deferred to Phase 10)

## Decision
- Hermes runs on the NAS, not the VPS
- Tailnet-only, in its own Docker network segment on lab-net
- Zero direct capability: no Docker socket, no SSH keys, no sudo
- All actions go through intermediaries:
  - n8n for schedules and workflows
  - the Ops Gateway (Phase 6+) with its own scoped token (svc-hermes)
  - Home Assistant via its REST API with a scoped long-lived token
- Model backend: DeepSeek API (per ADR-001)
- Nothing is built until Phase 5 (append-only backup) and Phase 6
  (ops gateway) are done

## Reasoning
- The VPS is the only internet-facing box; its job stays narrow
  (edge + identity). An always-on agent there would be a second live
  attack surface next to the perimeter.
- Hermes' actual work is data-proximate to the NAS: n8n (ADR-003),
  photos/Immich (Phase 9), Home Assistant, family tools.
- Gateway-mediated access means Hermes' blast radius is exactly the
  set of named actions its token allows — auditable and revocable.

## Consequences
- Hermes never appears in sudoers or authorized_keys anywhere
- Compromise of Hermes = compromise of its gateway token scope, nothing more
- NAS RAM budget must account for it (alongside n8n, Home Assistant, Immich)
