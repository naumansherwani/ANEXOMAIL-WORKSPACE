# ADMIN DESK ON ITS OWN HOST: admindesk.anexomail.com (his idea 21 Nov 2026 07:14 PKT) VERDICT + POLISH, NOTHING BUILT

His idea: the Desk lives on its OWN host admindesk.anexomail.com (DNS on his Namecheap), an identity admindesk@anexomail.com, same codes/features as the founder side, LEO works in both, two Chrome tabs (founderworkspace.anexomail.com + admindesk.anexomail.com) must not clash, and if a future employee tries to steal, HE takes the account back from the founder side.
## VERDICT: YES, the right idea, it is the strongest form of the separation design (research: MDN cookie guide, W3C WebAuthn 3 RP ID rule, checked 21 Nov; repo facts checked)
Why it works (facts):
- Cookies: founder code sets NO Domain= cookie in the repo (only a test line), so session cookies are host-only; a host-only cookie of one host is never sent to the other. Rule for the Desk: __Host- prefix, Secure, Path=/, no Domain, SameSite Strict.
- Browser storage, service worker, CSP, HSTS, DBSC session: all PER ORIGIN, so two tabs in ONE Chrome do not see each other.
- PASSKEYS: founder policy rp_id = founderworkspace.anexomail.com exactly (SQL default). A WebAuthn credential is bound to its RP ID, so a founder passkey cannot sign into admindesk and a Desk passkey cannot sign into the founder side. The Desk gets its OWN rp_id admindesk.anexomail.com. Never set an RP ID of the parent anexomail.com (it would span both).
- Two tabs, same time, fine: kernel + WebTransport per origin, own tokens, own audience "desk".
What is NOT free (honest, must be done in order, ports red line + Caddy law + installer-after-cut law apply):
1. DNS at Namecheap (HIS hands, one step at a time, after my read-only check): A/AAAA for admindesk plus an HTTPS record alpn=h3 so the browser finds QUIC; CAA record limiting who may issue certificates.
2. A TLS certificate for the new host (the Rust terminator copies Caddy's cert; the K4.3 refresh timer must cover it).
3. HOST ROUTING in Rust: fproxy.rs has ONE host constant (founderworkspace); the SNI front must route admindesk to the Desk door set and refuse the founder doors there, and refuse the Desk doors on the founder host (host-confusion guard). UDP 443 can serve both by SNI; any new port needs his fresh ss paste.
4. A tab-colour/brand band "ADMIN DESK" on the Desk so he never mistakes the two tabs (also anti-phishing).
New sub-phase (proposed, first because DNS and certs take time): R3a0 HOST = DNS plan, cert, SNI routing, host-confusion tests, CSP/headers; live proof = two tabs open together in my Chrome.
## About admindesk@anexomail.com (my advice)
- Make it the Desk OWNER / ROLE identity label, NOT a shared login for people: every employee later gets their own login (one person one identity), LEO gets its own staff identity "leo".
- A guessable role address attracts phishing and spam: do NOT let it receive public mail (no inbox; at most an alias to resolved@ with strict filtering). The Desk mail addresses stay hello@, moveyourbusiness@, resolved@, leo@.
## LEO in both
LEO = Claude through Chrome as its own staff identity (actor "leo" in every ledger). Founder side: LEO helps him. Desk side: LEO drafts and reads; every real send to a user needs his yes at that moment; LEO has no owner rights, no export, no role change.
## "If an employee tries to steal, I take the account back" (design so this is true)
1. OWNERSHIP ROOT stays with HIM: Desk owner = founder, anchored to his founder passkey/hardware keys. An employee can never become owner, never change owner, never remove him.
2. ONE-CLICK TAKE-BACK from the founder side (Admin > Staff): revoke all sessions, suspend a person, rotate the Desk token-signing key label, rotate the desk_app database password, freeze a mailbox, forbid new logins; ledger entry for each.
3. NOTHING to steal sideways: desk_app has zero grants on founder tables; keys separate; employee never sees founder mail (steps 1-12 in ADMIN-DESK-PHASES-AND-EMPLOYEE-ISOLATION-21NOV.md).
4. THEFT SPEED BRAKES (polish from research): per-staff read-rate caps, no bulk export for employees, no auto-forward rules to outside addresses, attachment downloads logged, off-hours and burst-read alerts to him, visible watermark of the employee's name on the screen, short session life, every read in the hash-chained ledger = proof.
5. HONEST LIMIT: nothing can un-see what an employee has legitimately read or photographed with a phone. Technology limits and PROVES it; the contract/NDA is the legal part. Take-back removes access immediately and proves what was touched.
## More polish (advance, each checkable)
Response headers on the Desk: CSP default-src self + frame-ancestors none, COOP same-origin, CORP same-origin, Fetch-Metadata resource isolation (reject cross-site requests), no CORS between the two hosts, links between hosts use noopener; both hosts HTTP/3 only; WebTransport sessions per origin; DBSC session per origin; Time machine and settings per host; a read-only Desk "health" panel (ledger verify, DNS/mail posture) the same as founder cards.
## Open for him
Approve the own host admindesk.anexomail.com? Keep the name "admindesk" for host and owner label? Desk owner identity without inbox (my advice)? Then: R3a0 HOST becomes the first R3 step (read-only ss + DNS check first, his Namecheap hands later, one step at a time).
