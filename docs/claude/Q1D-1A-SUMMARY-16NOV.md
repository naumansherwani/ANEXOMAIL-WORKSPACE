# >>> Q1d SUB-PHASE PLAN (his 16 Nov 05:22: one thing at a time, sub-phases, plan at the TOP) <<<
ONE sub-phase at a time. The next starts only when the one before has its proof. Never two commands for two sub-phases.
- Q1d-A  SQL clean: E178 (selftest scoped to its own row; E167 selftest failed on HIS real queued mail, not a code bug) -> sql-run (AUTO) -> sql-run CHECK_E178 = all OK. DONE when: his paste shows 3/3 OK.
- Q1d-B  New Rust installed: founder-install (no-touch send, exact-time sender). DONE when: his paste ends OK and healthz 200.
- Q1d-C  Outgoing probe (read-only): fmail-send-probe.sh. DONE when: his paste says port 25 open or a loopback relay exists.
- Q1d-D  DNS: r2611a re-check (panel Check DNS) -> both rows "DNS record confirmed" -> switch "DNS record must be confirmed" (touch). DONE when: both confirmed + switch ON.
- Q1d-E  Sender ON: fmail-send-on.sh (backup + rollback). DONE when: journal "mail sender ON" + healthz.
- Q1d-F  First real mail to his Gmail (30 s hold, then out in ~50 ms, Outbox -> Sent) + Gmail Show original pasted (Record proof) = dkim=pass. ONLY THEN Q1d-1a/1b/2a/2b = GREEN (WIRED: YES / REAL: YES).
- Then AUDIT-Q1d, Q1b4, Q3, F-series O,P,R,S,V to 30 NOV (docs/claude/FOUNDER-F-SERIES-ORDER-16NOV.md).
Where we are 16 Nov 05:50: Q1d-A DONE (his paste: E178 applied, selftest177 5/0, CHECK_E178 3/3 OK, CHECK_E65 all OK). NEXT = Q1d-B founder-install. Q1d-C..F not started.

# Q1d-1a SUMMARY (16 Nov 2026 02:35) - what the phase is, features, advance technology
Phase: Q1d-1a = the founder mail DKIM lifecycle (key, DNS TXT, signing, proof). Sub-phase 1 of Q1d (1a, 1b, 2a, 2b). Plan: Q1D-PLAN-16NOV.md. Contract + EXECUTION RECORD: tech-contracts/CURRENT.md.
## Status (a1..a4)
- a1 DONE (repo): oversigning in server/founder/src/fmail_dkim.rs (From/To/Subject/Date/Message-ID listed once extra in h=, twice if absent; header added after signing breaks Ed25519 AND RSA; cargo 10/10).
- a2 DONE and ON HIS SERVER (his paste 16 Nov 02:3x: E175 selftest 28 ok, 0 failed; CHECK_E175 7/7 OK, E65 sweep OK; sha 3dd4fbff6069e7a9). Written in sandbox PG16 first: docs/cursor-work/sql/E175_founder_mail_dkim_lifecycle.sql (513 lines, needs E167/E169/E170) + CHECK_E175.sql (7 checks). selftest 28 ok. Chain tables hold 0 rows until a3 wires Rust (0 rows checked, 0 broken).
- a3 DONE in repo 16 Nov 02:5x (cargo 408/408 incl. 5 new tests; NOT on his server until founder-install): Rust wiring in fmail_out.rs: call fmail_dkim_send_gate175 before claiming; fmail_dkim_sign_record175 after each signature; read-only DNS probe -> fmail_dkim_dns_record175; proof door -> fmail_dkim_proof175; policy/health door. Contract note in CURRENT.md FIRST.
- a4 AFTER (needs his haan, additive only): new React file + one-line mount: key, TXT, DNS state, rotation, proof paste.
- Then: founder-install (oversign Rust live), his Compose key touch (hands), his Namecheap TXT (hands), Q1d-1b Gmail Show original paste, Q1d-2a, Q1d-2b (FMAIL_SEND=on only with his haan).
## Features
1 Dual signature Ed25519-SHA256 (RFC 8463) + RSA-2048 (RFC 6376 relaxed/relaxed), x= expiry 7 days, private key AES-256-GCM wrapped under vault master, creation needs passkey touch (action mail.key).
2 Oversigning (RFC 6376 8.15).
3 Policy ratchets: switches go on once, never off (trigger-enforced); rotate_days; passkey touch to change (ledger dkim_policy).
4 Dated selectors (e.g. e2611a) + rotation report: when the old key's DNS record may be removed.
5 DNS observation: hash-chained fmail_dkim_dns_obs; SQL decides match.
6 Signature log: hash-chained fmail_dkim_sign_log; over-sign is re-computed in SQL from h=, the signer is not trusted.
7 Proof: pasted receiver header (Gmail Show original) parsed in SQL, hash-chained fmail_dkim_proof (for Q1d-1b).
8 Health + send gate: no send if DKIM would fail. 9 chain_verify + selftest. All tables append-only, forced RLS, service_role only.
## Advance technology by layer
Rust = signer (ring/mail-auth). Tokio = sender worker, blocking RSA keygen thread, SQL doors. WASM kernel = signs/verifies browser requests and answers, later re-hashes the sign-log chain; NEVER holds a DKIM private key. WebTransport = browser<->server doors only (Compose, key touch, health); mail itself leaves by SMTP STARTTLS TLS 1.3 (Q1d-2a proves X25519MLKEM768). PostgreSQL 16 RLS, SHA-256 hash chains, triggers.
## DKIM2 / ML-DSA-44 sirf tracked | IETF draft, FIPS 204 | Q1d (OPEN)
draft-ietf-dkim-dkim2-spec-09 (WG draft, expires 5 May 2027): per-hop chain, mf=/rt= binding, RSA-SHA256, Ed25519-SHA256, ML-DSA-44. No receiver verifies it: NOT built. Build later in Rust + kernel verify when a receiver does. qstate step Q1d-DKIM2 (deferred).
## His command: DONE (sql-run AUTO). NO founder-install asked yet: Rust oversign + wiring go live with the founder-install AFTER a3. Next command to him = founder-install, only then.
## (old) His ONE command was
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25
Expect: E175 selftest 28 ok + CHECK_E175 7 OK. No awam pull (kernel unchanged).

## a3 as built: fmail_out.rs process() = send gate (fmail_dkim_send_gate175) -> sign_all_rec -> fmail_dkim_sign_record175 per signature BEFORE SMTP (refusal = Retry). Doors: GET mail/dkim/health, POST mail/dkim/check (DNS TXT probe), POST mail/dkim/proof, POST mail/dkim/policy (touch). fmail_dkim::parse_sig. Contract = CURRENT.md Q1d-1a a3 CONTRACT. NEXT: his founder-install (sender is still OFF, FMAIL_SEND not on), then a4 UI (additive, needs his haan: mail_api.ts door calls + DkimSetup panel), then his Compose key touch, Namecheap TXT, Q1d-1b.

## PENDING (gate SERVER FIRST): the 4 route lines in main.rs are saved as docs/claude/state/PENDING-main-rs-dkim-routes.patch (git apply it). main.rs is a server-surface file: needs a fresh read-only paste from him (ss -tulpn | grep -E ':443|:25|:8443' style), then `python3 docs/cursor-work/server/serverfirst.py record "<cmd>" <paste file>`, then git apply the patch, cargo test, rec.sh, THEN give him founder-install. Without these routes the doors are dead code; send gate + sign log in fmail_out.rs already work.

## UPDATE 02:36: his ss paste recorded (SERVER-FIRST receipt 42), 4 routes applied in main.rs, patch file removed, cargo 408/408. a3 COMPLETE in repo. NEXT = his founder-install line (sender stays OFF), then my check that /mail/dkim/health answers, then a4 UI (needs his haan).

## UPDATE 02:55: founder-install OK on his server (his paste: SPA 200, healthz 200, signing ON, 4/4 saboot). My Chrome (founderworkspace.anexomail.com/#/mail): bundle index-B5pJDX1M + css CYOquduq = repo build (UI untouched, correct: a3 has no UI); GET /founder/v1/mail/dkim/health = 401 (route LIVE, auth enforced), /mail/dkim = 401, /mail/dkim/nope = 404. NOT proven yet: a real signature through the send gate (sender OFF, no key). Q1d-1a is NOT green: needs key (his Compose touch), TXT at Namecheap, dkim=pass paste. HIS HAAN for a4 UI (16 Nov 02:49) with law: EXISTING UI INTACT (new file + one-line mount), founder separate from awam. 30 NOV deadline: a4 now -> key touch -> TXT -> Q1d-1b (Gmail dkim=pass) -> Q1d-2a -> Q1d-2b FMAIL_SEND=on (his haan) = first real mail.

## UPDATE 03:15: a4 UI WRITTEN (repo, NOT on his server): founder-web/src/DkimPanel.tsx + dkim_api.ts + dkim_pure.ts(+test 6/6) + dkimpanel.css; MailBox.tsx NOT edited (preserved for awam, gate): DkimDock.tsx mounted by App.tsx beside MailBox, under the mailbox. Existing UI untouched. Sandbox look 390/820/1280 OK (no overflow, buttons >= 44 px). NEXT = his founder-install, then my live Chrome look of the panel, then his Compose key touch (panel button New Ed25519 key / New RSA-2048 key, dated selector e2611a), Namecheap TXT, Check DNS, Gmail proof paste, Q1d-1b.

## UPDATE 03:40: SYSTEMS PAGE (his word): Mail speed + Mail health + lanes + DKIM panel moved OFF the mailbox screen into Systems > Mail health / Mail signing (founder_mail_quiet.css hides them in the mailbox, MailBox.tsx untouched). Heartbeat + Brain panel there (brain.py -> system_brain.json + HEARTBEAT.json, run by rec.sh, which now also rebuilds founder-web/dist). LESSON: the server installs founder-web/dist from git, so dist MUST be rebuilt before commit (the first install delivered a stale dist). Avatar colours calmed. NEXT = his founder-install, my live Chrome look at Systems (mail health, heartbeat, brain, DKIM), then the key touch in Systems > Mail signing.

## UPDATE 04:05 (his paste: E176 on his server) + HIS ORDERS + THE PLAN TO 30 NOV (READ THIS AFTER A COMPACTION)
- E176 ON HIS SERVER: selftest 4 ok, CHECK_E176 3/3 OK, E65 sweep OK (sha d807ff0c9f629eff). My live Chrome (Systems > Mail signing, bundle index-5UaK8Jzq = repo dist): panel answers "No signing key yet" + 3 one-way policy switches (all OFF by default) + two key buttons + proof paste. The Systems Mail health, Heartbeat, Brain are live-proven too.
- HIS ORDERS (16 Nov 03:39): (1) GATE DATES BEND TO THE ORDER: the founder project must be COMPLETE by 30 NOV, then back to the awam business packages. TECH-LAW-GATE fail_after dates moved: Q3 items (Q-att-wt, Q-live-wt, D-clamav, D-hetzner-storagebox) 26 Nov, Q-pqmail 29 Nov, M-moq + A-tanstack-start 30 Nov (A-tanstack-start still needs HIS decision: Router-only static SPA, because TanStack Start needs an SSR runtime = Node/Bun, banned). (2) AUDIT-Q1d after Q1d is complete: if a listed advance technology is NOT in the code, AUTO FIX it (no asking), research on the web when needed. (3) Backend/system things live in Systems, never on the mailbox screen (founder_mail_quiet.css). (4) Mobile tests are with him: never claim 390/820 live-seen unless his phone screenshot shows it. (5) Mail must go TODAY: HIS HAAN is given for the whole sequence below, I only give him one step at a time.
- ORDER OF STEPS (each closes with proof, then the next): 
  1 HIS HANDS: Systems > Mail signing > New Ed25519 key (touch), New RSA-2048 key (touch); then turn on the 3 policy switches one by one (each a touch): over-sign now, both keys now, DNS-match AFTER step 3.
  2 ME: read the two TXT records from the panel in live Chrome, give him name + value.
  3 HIS HANDS: paste the 2 TXT records at Namecheap; press Check DNS in the panel (must say DNS record confirmed); then switch on DNS-match.
  4 Q1d-2a (me, read-only probe of outgoing TLS to a real server, X25519MLKEM768).
  5 Q1d-2b: FMAIL_SEND=on (his haan IS given) -> first real mail to his Gmail, then Q1d-1b: he pastes Authentication-Results from Show original into the panel (dkim=pass).
  6 AUDIT-Q1d (auto fix gaps), then Q1b4, Q3 (attachments: Tokio + Rust + WebTransport, 1 MiB chunks, 8 streams, resumable, AES-256-GCM chunks, ClamAV, Hetzner Storage Box), Qtls, U1U2, Q4, U5, Q1e, M-moq, then D-series; everything founder GREEN by 30 NOV.
- GREEN rule unchanged: Q1d-1a GREEN only after key + TXT confirmed + a real signed mail with dkim=pass seen in the panel.

## UPDATE 04:15: HIS DECISION TANSTACK = Router-only (docs/claude/DECISION-TANSTACK-ROUTER-ONLY-16NOV.md; gate A-tanstack-start now ok, enforces @tanstack/react-router). NAMECHEAP STEP TOOL: docs/cursor-work/server/dkim-dns-print.sh (READ-ONLY, sandbox-tested): after his key touches it prints for every active key: Host (selector._domainkey), Type TXT, Value (v=DKIM1; k=...; p=...), the nameservers of the domain and what DNS answers now. HIS COMMAND: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/dkim-dns-print.sh) 2>&1 | tail -25  . NOTE: the founder DNS is also run by his own Rust (founder-dns on 62.238.98.98:53): the script prints the nameservers so the record goes where the domain is really answered (Namecheap only if its nameservers are Namecheap's). The Namecheap steps are written in the chat reply to him (Advanced DNS > Add New Record > TXT Record > Host, Value, TTL Automatic > save). RSA value is ~400 characters: Namecheap accepts it in one box.

## 16 Nov 04:20 SYSTEMS LAYOUT FIX = LIVE (his founder-install paste 04:07 + my live Chrome)
Live bundle index-DWFDojyK (was index-5UaK8Jzq). Measured live at 1536: .sysmh present, old .mh gone, Mail speed box left-aligned under its heading, Tap 1/2 sheet is a child of document.body (not in a card), fully on screen, on top, closes cleanly. 390/820 = sandbox measurement only (his phone screenshot still welcome). The Mail signing card is a collapsed panel ("Signing (DKIM)", "Keys, DNS, proof"): he opens it, then presses the key buttons.

## NAMECHEAP STEPS = STILL OPEN (his 16 Nov 04:07 word: keep it open in the repo, give the steps in chat)
Order: keys (touch) -> dkim-dns-print.sh (one line, his paste) -> TXT at the DNS that answers anexomail.com (Namecheap only if the NS lines say Namecheap) -> Check DNS -> switch "DNS record must be confirmed". Do not close this item until Check DNS shows confirmed for BOTH keys.

## 16 Nov 04:25 FOUNDER LIVE AUDIT: 21 OPEN CARDS (real gaps, not green)
These cards read the old app's /api/founder/* and answer 404 on the founder host (no Rust door yet): People: org/list, crm/state, security/overview. AI: ai-agents. Systems: admin/overview, storage/volumes, perf/overview, integrations/overview, analytics/overview. Control: settings/overview, org/state. Finance: revenue/overview, revenue/pipeline, billing/revenue, support/replies, ai/credits/overview. Release: release/overview, checklist, deployments, checks, roadmap. Fix = the Rust doors listed in founder-web/src/catalog.ts (F3 release/finance, F4 people, F6 systems, F8 control), each with E-series SQL; due before 30 Nov, order after Q1d. The card text is now honest ("Not connected yet, waits for its Rust door").

## 16 Nov 04:50 KEYS CREATED + KEY-TOUCH BUG FIXED + F-SERIES ORDER (READ THIS FIRST AFTER COMPACTION)
- BUG found live by me ("no origin": kernel RPC passed no Origin header to passkey::origin_of) fixed in wtrpc.rs (server sets origin from its own host, cargo 409/409), founder-install pasted by him 04:35, live bundle index-CTELgn2B.
- KEYS: I pressed the buttons in his Chrome, HE touched his key: Ed25519 key selector **e2611a** and RSA-2048 key selector **r2611a** are created (live panel: "Key e2611a created", "Key r2611a created"). Private halves are sealed on the server. NOT a green phase yet.
- NEXT (his hands, ONE step at a time): (a) policy switches in Systems > Mail signing: "Over-sign" and "Both Ed25519 and RSA keys required" (Turn on (touch), each one touch; I can press the button in his Chrome, he touches); NOT "DNS record must be confirmed" yet. (b) he runs dkim-dns-print.sh (command above) and pastes the output; I give the Namecheap Host/Value in chat; (c) TXT at the DNS that answers anexomail.com; (d) Check DNS in the panel, then the DNS switch; (e) Q1d-2a, Q1d-2b FMAIL_SEND on, Gmail proof.
- Systems buttons look = his image 2 (dark, thin blue hover border); DKIM title visible on narrow screens.
- F-SERIES explained and ordered with dates: docs/claude/FOUNDER-F-SERIES-ORDER-16NOV.md (21 cards without Rust doors = phases O, P, R, S, V). S5 closed (Router-only).

## 16 Nov 05:05 DKIM DNS PRINT = HIS PASTE (public values, safe to keep). NAMECHEAP STEPS IN PROGRESS, ONE AT A TIME
Nameservers of anexomail.com = dns1.registrar-servers.com + dns2.registrar-servers.com = NAMECHEAP, so the TXT records are pasted in Namecheap > Domain List > anexomail.com > Manage > Advanced DNS > Add New Record (TXT).
- Record 1: Host `e2611a._domainkey`, Type TXT, Value `v=DKIM1; k=ed25519; p=ItjuwBXT+HXAZ5GianL4owoDtoAUAYwMgHDPE3KKXVM=`
- Record 2: Host `r2611a._domainkey`, Type TXT, Value `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxrMMhER+Wp3CapmN6y8rIvSmXACbK1ixXwrplNJlFtuWAG+vF3rRhaNpcbPGT419psyh9gJdQyx3z1w4WNfYyrYvN4hrw+MR/rTiJW9eIMRmjDO3G6LWLgoZ4YpyFbdwQcYZtugP/t9rHHLIT92gI/xkiDU5GyiZiOTDejSj1ZCAhLwSz8iMNST8eXzX+yvDvPiZuRS6F/gUAXx0uOS9fXb6Rzy0hHe5Ruc43Vf9HeV0Oycd7BXU1OfP0ltf1oxOdxagJoToKOz+h273dT3KPZN19qWd59K9LfmG1USR13ib5pX30ZWWruWtOf1HxqRRIQWXdCAF94HeGIBgCKTSSQIDAQAB`
- DNS answer at 05:05: both KHALI. Progress: step 1 (open Advanced DNS) given; then record 1, record 2, save, wait, Check DNS in the panel, DNS switch.

## 16 Nov 05:20 NAMECHEAP: HE PASTED BOTH TXT RECORDS; PANEL CHECK DNS (pressed by me in his Chrome, read-only probe through the server resolver)
- e2611a (Ed25519): **DNS record confirmed** (panel status, my live Chrome).
- r2611a (RSA-2048): "Not in DNS yet" at 05:20 (can be propagation, or the long value pasted wrongly in Namecheap: the TXT value must be ONE line with no quotes and no spaces around it). Re-check in 5-10 minutes with "Check DNS" on that row; if still empty after 30 minutes, ask him for a Namecheap Advanced DNS screenshot of the r2611a row (do not guess).
- My sandbox cannot resolve DNS (allowlist), so the only proofs are the panel's Check DNS and his dkim-dns-print.sh paste (the script also prints what DNS answers now).
- NEXT: when BOTH rows say "DNS record confirmed": he/I switch "DNS record must be confirmed before sending" (Turn on, touch). Then Q1d-2a (outgoing TLS read-only proof), Q1d-2b FMAIL_SEND on, first real mail to his Gmail, he pastes the Authentication-Results header (Record proof) = dkim=pass. Only then is Q1d-1a GREEN.

## 16 Nov 05:05 NORMAL SEND + EXACT-TIME SENDER (his 04:55 word) - WRITTEN, TESTED, NOT YET ON HIS SERVER
- Why his mail was not in Sent: the sender (FMAIL_SEND) is OFF, so mail waits in Outbox. Not a bug. Also his host may block outbound port 25 (probe tells).
- Per-send fingerprint/touch OFF by his word: E177 sets policy require_touch_send=false through the ledgered policy door (action policy_change). The 30 s undo hold STAYS. Key creation + DKIM policy ratchets keep their touch. fmail_selftest167 patched to re-enable the flag inside a rolled-back subtransaction.
- Speed: Rust worker (server/founder/src/fmail_out.rs) has no polling tick: tokio::select! between sleep-until-next-due (fmail_outbox_next_due177) and WAKE Notify (send_ep wakes it). Mail goes out within ~50 ms after the 30 s hold. cargo 410/410, E177 selftest 5/5 in sandbox.
- Files: docs/cursor-work/sql/E177_founder_mail_normal_send.sql + CHECK_E177.sql (next free SQL = E178); server scripts fmail-send-probe.sh (Q1d-2a, read-only) and fmail-send-on.sh (Q1d-2b, backup + rollback).
- ORDER FOR HIM, ONE AT A TIME: 1 sql-run (E177) -> 2 founder-install (new Rust) -> 3 fmail-send-probe.sh paste -> 4 fmail-send-on.sh -> DNS Check for r2611a -> DNS switch (touch) -> first mail to Gmail -> Record proof (dkim=pass). NOT GREEN until then.
