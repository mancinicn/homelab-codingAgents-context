# ADR-025: BentoPDF placement and family exposure

## Date: 2026-07-26
## Status: PROPOSED -- container deployed tailnet-only and verified;
## the public-exposure decision below is NOT yet accepted by Christian

## Decision
Run BentoPDF on the **NAS**, core-net, tailnet-bound
(100.126.31.47:3100 -> 8080), image pinned
ghcr.io/alam00000/bentopdf-simple:v2.8.6.

Proposed next step (still to confirm): expose it to family via its own
public hostname pdf.christianmancini.de through the VPS's Traefik,
gated by the EXISTING n8n-outpost-standalone Authentik outpost with a
new bentopdf-family proxy provider bound to the family group -- i.e.
exactly the pattern n8n already uses.

## Reasoning
- **NAS, not VPS**: the VPS stays edge + identity only (Traefik,
  Authentik, Vaultwarden). Every app so far lives on the NAS. BentoPDF
  is an app. Putting it on the only internet-facing box would widen the
  perimeter for no benefit -- especially pointless here, since the app
  is client-side and gains nothing from being nearer the edge.
- **Client-side changes the risk calculus.** BentoPDF processes PDFs
  entirely in the browser; files are never sent to the server. The
  container serves static assets only. So a public route exposes a
  login page in front of static files -- not a document store. This is
  materially less exposure than publishing a server-side PDF tool
  (e.g. Stirling), and it is why public exposure is even proposable.
- **A hostname is not cosmetic -- it is required.** Authentik proxy
  outposts route by Host header, not by port. The existing outpost
  already serves n8n.christianmancini.de. A second application
  reachable only at the bare tailnet IP could not be distinguished from
  n8n by that outpost. So the options were: give BentoPDF its own
  hostname, or run a second outpost container on another port. The
  hostname wins -- fewer moving parts, and it also solves the HTTPS
  requirement below.
- **HTTPS is functional, not decorative.** Office-file conversion needs
  SharedArrayBuffer, which requires a secure context plus cross-origin
  isolation. Over plain tailnet HTTP that feature is dead. The public
  route via Traefik supplies TLS, so the toolset is complete.

## Findings (measured, not assumed)
- The image ships the isolation headers: verified with curl -sI against
  the running container -- Cross-Origin-Opener-Policy: same-origin and
  Cross-Origin-Embedder-Policy: credentialless.
- credentialless (not the older require-corp) is the modern mode: well
  supported in Chrome/Edge/Firefox, later and weaker in Safari.
  **Untested on iOS.** If family uses iPhones/iPads, office conversion
  specifically must be tested there before being promised. Everything
  else (merge/split/compress/rotate) needs none of this.
- **Still unverified**: whether COOP/COEP survive the Authentik outpost
  proxy. If the outpost strips them, office conversion breaks even over
  HTTPS. Must be re-checked with curl -sI against the gated hostname
  once wired -- before concluding the feature works.
- The official image runs as **root** (the mash-playbook builds its own
  to avoid this). Accepted for now: it is a static file server with no
  volumes, no socket, no secrets. Noted so it is a known tradeoff
  rather than an unexamined default.
- Licence AGPL 3.0 as of v2.0.0; the bentopdf-simple build is the one
  intended for internal/organisation self-hosting.

## Consequences
- **No appdata backup** -- stateless, no database, no volumes, nothing
  persists between runs. Same reasoning that excluded Hermes.
- **DOES belong in the auto-update controller** -- unlike Hermes, this
  has real upstream releases. Pin-and-bump, never :latest, matching the
  convention everywhere else here.
- Register in ops-gateway ALLOWED_SERVICES (status/logs/restart), not
  DEPLOYABLE_SERVICES.
- **Hard prerequisite for the whole point of this**: the family
  Authentik group currently has NO real members -- only a test account;
  the wife's account was never created. Until that exists, binding the
  application to family gates it against nobody. This ADR does not
  unblock family use on its own.
- Adds a second public hostname to the perimeter. Small but real, and
  the reason this ADR exists rather than the change being made silently.
- Rollback is one command:
  docker compose -f ~/compose/bentopdf/compose.yml down

## Rejected alternatives
- **Tailnet-only, no public route**: simplest and zero new exposure,
  but requires Tailscale on every family device (the friction the n8n
  public route was created to remove, 2026-07-15), AND silently loses
  office conversion for lack of HTTPS. Rejected as "deployed but nobody
  uses it."
- **Second outpost container on another tailnet port**: avoids a new
  hostname, but adds containers and still has no TLS, so conversion
  stays broken. More complexity for a worse result.
- **Host on the VPS**: contradicts the VPS-stays-narrow principle for an
  app with no reason to be there.
- **Stirling PDF instead**: server-side, therefore real document upload,
  real storage, real backup and real exposure to design around.
  BentoPDF's client-side model is strictly less risk for this use case.