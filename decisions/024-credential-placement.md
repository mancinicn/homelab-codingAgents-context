# ADR-024: Credential placement -- private keys live only where a decision put them

## Date: 2026-07-26
## Status: accepted

## Decision
Private key material lives ONLY where an ADR explicitly places it.
Concretely, for SSH:

- **Laptop only.** Private SSH keys live on Christian's laptop,
  passphrase-protected, used via ssh-agent. That is the single
  authorized location.
- **NAS: none.** NAS access is Tailscale SSH (identity-based, no
  standard sshd listening on :22 at all -- verified 2026-07-26,
  Connection refused on port 22 from the box itself). There is no
  pubkey path to authenticate against, so a private key on the NAS
  serves no purpose and is by definition unauthorized.
- **VPS: none.** The VPS is reached FROM the laptop by pubkey; it does
  not need to hold key material to reach anything else (ADR-021
  deliberately built the VPS auto-updater to avoid cross-box creds).
- **Agents and containers: none.** Already decided -- coding agents get
  no dedicated key (ADR-006), Hermes none (ADR-007), ops-gateway none
  in-container (ADR-011/012/018). This ADR names the general rule those
  were each instances of.

Anything found outside those bounds is treated as drift and removed,
not rationalized after the fact.

## Why this needed writing down
The rule was implicitly followed in every individual decision but never
stated as a rule -- so nothing was checking it, and drift went
unnoticed for three weeks.

**The finding (2026-07-26, session 15):** ~/.ssh/id_ed25519 on the NAS
-- a copy of the LAPTOP's key (comment jm2-laptop, created 2026-07-05
alongside session 1's key setup, evidently copied with the whole ~/.ssh
directory, which is also why a stray ~/.ssh/config with
"Host nas -> 100.126.31.47" -- the NAS pointing at itself -- was there).

Three things were wrong, in increasing order of interest:
1. **Permissions -rwxrwxrwx** -- a private key readable and writable by
   every account on the box, for three weeks (2026-07-05 -> 2026-07-26).
   Root cause was inherited, not set: /home/mancinicn was itself 777.
2. **No passphrase.** Verified with ssh-keygen -y -P "", which
   succeeded. Contradicts session 1's own record ("SSH keys with
   passphrases for NAS and VPS") -- see that log's correction note.
3. **Nobody decided to put it there.** Searched all 23 ADRs, 15 session
   logs, HANDOVER and AGENTS.md: every mention of SSH keys in this
   project is about NOT having them somewhere. No decision authorized
   this placement.

**Actual impact: low.** The key authenticates nowhere -- verified
against NAS mancinicn (no sshd at all), NAS agent_ops, VPS mancinicn,
VPS root, and GitHub; all refused. known_hosts contained only
github.com entries from the test attempts themselves, i.e. the key had
never been used to connect anywhere. Christian is also the only human
account on the NAS. So the exposure window had no realistic exploiter
and no reachable target.

The point is not that this key was dangerous. It is that a project
whose entire model is "every credential placement is an explicit
decision" had an unencrypted private key sitting somewhere nobody
decided to put it, and only found out by accident while investigating
something unrelated. That is exactly the drift the ADR discipline
exists to catch, and it went uncaught because the rule was never
written as a rule.

## Consequences
- The NAS key was **quarantined**, not deleted outright, on the same
  reversibility principle used elsewhere here: ~/.ssh/quarantine/ (0700)
  holds id_ed25519, id_ed25519.pub and the stray config. Delete after a
  confirmation period. Inbound "ssh nas" is unaffected -- that is
  Tailscale SSH, a different mechanism, and ~/.ssh/authorized_keys was
  left untouched.
- **Not rotated.** Rotation is for credentials that grant something;
  this one grants nothing on any reachable host. If evidence ever
  emerges that this keypair IS authorized somewhere untested, rotate
  then.
- **Home directory permissions** (/home/mancinicn = 777) were the
  reason the key was world-readable at all, and are a standing
  privilege-escalation path for anything else on the box (a container
  escape, or agent_ops with its narrow NOPASSWD sudo allowlist).
  Tightened to 750, verified drwxr-x---. getfacl showed only base
  entries -- no inherited UGOS ACLs -- so plain mode bits hold here,
  unlike the ACL-inheritance case suspected first.
- **Open follow-up, laptop side**: session 1 claimed passphrases on the
  keys for both NAS and VPS; at least one had none. The key that
  actually authenticates to the VPS therefore needs re-verifying, and a
  passphrase adding (ssh-keygen -p -f <keyfile>) if it lacks one. That
  one would be a LIVE credential, unlike the inert copy found here.
- Periodic check worth folding into refresh-state.sh eventually: flag
  any id_* private key found outside the laptop, and any
  world-readable/writable file under ~/.ssh or the home directory. Not
  built yet -- noted so it is a decision, not an oversight.

## Rejected alternatives
- **Delete the key immediately instead of quarantining**: faster, but
  irreversible, and this project's habit (backup-first, .bak files,
  archived vaults) is to stage removals when nothing forces urgency.
  Nothing forced urgency: the key was already proven inert.
- **Rotate everything as a precaution**: rotation has a real cost
  (touching authorized_keys on every host, risking lockout) and here it
  would protect against nothing, since no reachable account accepts the
  key. Precaution that buys no security is ceremony.
- **Leave it and just fix permissions**: would have left an
  unauthorized, unencrypted private key on a box with no use for one --
  treating the symptom while keeping the actual policy violation.