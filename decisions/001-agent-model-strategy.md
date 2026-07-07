# ADR-001: Agent model strategy

## Date: 2026-07-07
## Status: accepted

## Decision
- Interactive: Claude Code or OpenAI Codex via subscriptions, switching when tokens run out
- Autonomous (Hermes): DeepSeek API directly, no LiteLLM router
- Context handoff: this repo (homelab-codingAgents-context)

## Reasoning
- LiteLLM adds overhead for a single-provider setup
- DeepSeek is cheap enough for 24/7 autonomous use
- OpenRouter is the upgrade path if multi-provider routing is needed later
