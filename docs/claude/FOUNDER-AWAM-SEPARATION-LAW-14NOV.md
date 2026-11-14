# FOUNDER / AWAM SEPARATION LAW (his order 14 Nov 2026 05:34 PKT) - WRITTEN WORD FOR WORD SO IT IS NEVER DISCUSSED AGAIN

HIS ORDER (verbatim in substance): "write this exactly word to word in the repo for Claude so this problem is not discussed again; awam-side problems are looked at in the AWAM blueprint; this is a rule and it was told: the founder-side codes are PRESERVED, but those codes are used ADAPTED to the awam side (dhal ke), not copied as they are."

THE TEXT (proven on his server, receipt 24 = curl -sI https://anexomail.com, receipts 21/23 = ss and env):
- Awam answers on TCP 443 with `HTTP/2 200`.
- Awam sends `alt-svc: h3=":18443"; ma=2592000`. So awam browsers go to HTTP/3 on UDP 18443, where Caddy is.
- Founder is on UDP 443 (and TCP 443 accept-and-drop), served by the `anexomail-found` binary. No awam browser is sent there.
- RESULT: founder and awam are separate by port AND by process (founder = anexomail-found, awam = caddy). KP3 step 5 changes neither. Removing or keeping UDP 4443 has NO effect on awam.
- Awam is on HTTP/2 today. The "HTTP/3 ONLY" law (K8e) is for the FOUNDER only. Awam technology is a different matter and is not touched by any founder phase.

THE RULES (never mixed, never re-discussed):
1. Awam-side problems (ports, HTTP/2 vs HTTP/3, Caddy, Alt-Svc, awam browsers) are handled ONLY in the AWAM blueprint (docs/claude/AWAM-ENGINE-BLUEPRINT-02NOV.md and docs/claude/ONE-ORDER-27OCT.md), never inside a founder phase.
2. Founder-side code is PRESERVED. When awam later inherits it (docs/claude/AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md) it is ADAPTED to awam's own needs (its ports, its host, its protocol), not copied unchanged and not re-opened as a founder question.
3. Awam never goes into the founder binary. The founder never goes through Caddy's ports (Caddy = 18443). A founder step must never ask "does this affect awam?": it is answered here.
4. Before any founder port step, the fresh ss list is read; the awam ports (18443 caddy, 3443 anexomail-rust) are never touched.
