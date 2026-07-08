# ADR-004: No Odoo/ERP monolith for life admin

## Date: 2026-07-07 (backfilled 2026-07-08 — decided verbally in session 2, never committed)
## Status: accepted

## Decision
- Life admin is built from lightweight purpose-built tools behind SSO,
  added one at a time (e.g. Grocy, Actual Budget, Vikunja)
- No Odoo or other ERP-style monolith
- n8n + the autonomous agent (Hermes) are the connective tissue that
  makes separate tools feel unified

## Reasoning
- A monolith front-loads complexity and admin burden for features that
  may never be used
- Individual tools can be adopted, replaced, or dropped independently
- Authentik provides the single login layer across all of them
