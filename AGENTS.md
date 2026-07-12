# Agent Context Repository

Shared memory for all coding agents working on the homelab infrastructure.
Read this before doing anything.

## How to use this repo

### On session start:
1. `git pull` this repo
2. Read `HANDOVER.md` for the current big-picture snapshot (it goes
   stale between updates — treat it as an orientation, not gospel)
3. Run `bash scripts/refresh-state.sh` to capture live infrastructure state
4. Read `facts/` for durable truths about the setup
5. Read `decisions/` for past architectural choices and their reasoning
6. Read the latest file in `sessions/` for where the last agent left off
7. Read `CLAUDE.md` in the `homelab-infra` repo for the implementation plan

### On session end:
1. Run `bash scripts/refresh-state.sh` again
2. Write a session log: `sessions/YYYY-MM-DD-summary.md`
3. If you made an architectural decision, write an ADR: `decisions/NNN-title.md`
4. If a phase completed or the big picture meaningfully shifted, update
   `HANDOVER.md` too — not needed every session, session logs already
   cover fine-grained detail; update it when the snapshot would
   otherwise go noticeably stale
5. `git add . && git commit -m "session: <summary>" && git push`

### Rules
- Never delete files — append and mark old ones superseded
- State files are auto-generated — don't hand-edit them
- Decisions are permanent records — amend with a new ADR, don't edit old ones
- No secrets in this repo — reference Vaultwarden or env file paths instead
- The infra repo (homelab-infra) has the compose files and scripts
- This repo has what agents KNOW, not what the infra IS

## Repos
- `homelab-infra` — compose files, scripts, runbooks (what's deployed)
- `homelab-codingAgents-context` — this repo (what agents know)
