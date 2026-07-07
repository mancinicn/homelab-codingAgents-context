# ADR-002: Separate context repo from infra repo

## Date: 2026-07-07
## Status: accepted

## Decision
Agent memory lives in homelab-codingAgents-context, not homelab-infra.

## Reasoning
- Different commit cadence (context updates every session, infra changes weekly)
- Session logs and state snapshots would clutter compose files and scripts
- Different consumers (agents read context, humans read infra)
- Context can grow to hundreds of files without affecting infra repo navigation
