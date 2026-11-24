# B13 T3: AUTOMATIC COMPANY PICKUP (sender -> ONE tenant UUID), POINT LIST BEFORE CODE (24 Nov 2026 09:4x PKT, his 09:36 order "next shuru kero"; gate RESEARCH IN BLUEPRINT: web research -> this list -> ADVANCE-RESEARCH line -> contract -> SQL)
ADVANCE TECHNOLOGY (first lines, his law): PostgreSQL 16 verdict function (SECURITY DEFINER, fixed search_path, STABLE, closed verdict words, forced RLS tables only read) on the AWAM database next to cp.domain_ownership; Rust Tokio + Axum Control Plane method over HTTP/3 (TLS 1.3 AES-256-GCM, X25519MLKEM768) signed with Rule 52 (Ed25519, own audience, replay cache); Desk Rust client with the fail-closed breaker; DMARC-aligned sender proof (RFC 7489: only a sender whose SPF or DKIM result aligns with the From domain counts); result written through AD30 fadm_case_bind (idempotent, advisory lock).

## WEB RESEARCH (24 Nov 2026, two searches; titles read, conclusions kept to what the advisor text and the standards already say)
Sources looked at: Safeguard "domain verification is the root of your tenancy model"; MailChannels "how to architect email for a multi-tenant SaaS"; Broadcom "Maileater created tickets assigned to wrong tenant" (the exact failure we prevent); SSOJet "email domain discovery: routing logins to the right IdP"; Cisco / Microsoft DMARC identifier-alignment pages; "Forward Pass: security implications of email forwarding" (arXiv 2302.07287).
POINTS TAKEN INTO T3, each built in the sub-step named:
1. A tenant is picked from a VERIFIED domain only, never from the display name, subject or free text (T3a).
2. The From domain is believed only when the message's own authentication aligns with it (DMARC alignment: SPF or DKIM pass for the same organisational domain). Forwarded mail (ARC chain) that fails alignment is NOT auto-resolved, it stays pending (T3a input 'aligned' = false -> pending).
3. Free/shared providers never resolve (AD26 cp.shared_domain, GREEN) (T3a).
4. A domain with two claimants cannot exist (AD26 EXCLUDE, GREEN); if the registry ever shows two, the verdict is 'ambiguous' and the case is quarantined, never guessed (T3a).
5. A sender who is a verified member of MORE THAN ONE tenant is 'multi_member' = pending until a person chooses (T4) (T3a).
6. Verdict words are a closed list: resolved, shared, unknown, ambiguous, multi_member, unaligned (T3a); anything else = the Desk treats it as pending (fail closed).
7. The Desk never receives a tenant name or member address, only the UUID and the verdict word (privacy, data minimisation) (T3b).
8. History: resolution uses the ownership period valid at the time the case arrived (cp.tenant_of_domain(domain, at)), so a later domain move never rewrites an old case (T3a).
9. Every resolution attempt, resolved or not, is a ledger line on both sides (T3a / T3c).

## FACT FOUND WHILE READING (honest, changes the plan)
- desk.fadm_case stores NO sender (no address, no domain): AD07 columns are ref, queue, address (OUR mailbox), thread_id, company_ref, subject, label, ... A case therefore cannot be resolved from the case alone.
- There is NO inbound mail ingest in the Desk Rust today (the Rust mail door is Folder 2 Mailboxes, frozen until Folder 1 is whole; the Desk shows 'Not measured yet' for mail). So the hook that calls the resolver at case creation CANNOT run yet.
- cp.tenant_of_domain(domain, at) already exists on the awam database (AD26, GREEN) and cp_lookup may run it. A sender-membership check and the closed verdict function do not exist yet.

## SUB-STEPS (each its own step, gate checked, GREEN only with proof)
| Sub-step | What | Where | State |
|---|---|---|---|
| T3a | AD31 (AWAM DATABASE, TARGET-DB marker): cp.resolve_sender(domain, local_part, aligned, at) returning ONE closed verdict word + tenant UUID; membership check against the real member table; selftest + CHECK | docs/claude/admin-desk/sql/AD31.sql | NEXT |
| T3b | Control Plane method 'resolve' (Rule 52, own audience, 15 s, replay cache, closed shapes) + Desk client in consent_cp-style module + unit tests (replay, wrong key, wrong shape, fail closed) | control-plane/src, docs/claude/admin-desk/server/src | after T3a |
| T3c | Desk side: AD32 adds sender_domain + sender_aligned evidence to the case ingest event and a door that applies a verified verdict through fadm_case_bind; the automatic CALL at case creation waits for the Rust mail door (Folder 2) | AD32 + Rust door | after T3b; the live call = Folder 2 |
| T3d | screen: case card shows 'Company: confirmed / waiting for confirmation (reason in words)' | DeskConsent / case card | with T3c |

## MY DECISION BY FOLDER (his 10:01 word: "T3 ke mamlay jin folder se related hain un pe aaye gay, simple hai, tum khud decision liya karo") (24 Nov 2026 10:0x PKT)
- T3a AD31 resolver (awam DB) + T3b Control Plane 'resolve' method + Desk client = DASHBOARD folder, B13 (built now, they are Control Plane / Desk files, no inbound mail needed).
- T3c the automatic CALL when a case is created from incoming mail = FOLDER 2 Mailboxes (the Rust mail door that ingests mail and writes the sender domain + alignment into the case event). The hook point is written in Folder 2's row; until then AD30 binding is by T4 (manual, two staff).
- T3d the case-card text 'company confirmed / waiting' = FOLDER 3 Cases (it is a case screen); until then the existing Customer data access screen carries the not_bound sentence.
- Move-in requests (moveyourbusiness@) = PROSPECT cases: verdict 'unknown' is CORRECT, never bound, never consent (MOVE-IN-SYSTEM-PLAN-24NOV.md note 3). Move-in pipeline = FOLDER 8 phase P.


## T3b WEB RESEARCH, ADVANCE TECHNOLOGY FOR THE RESOLVE DOOR (24 Nov 2026 11:2x PKT, his 11:04 order: use ALL FOUR, leave none out)
1. RFC 9421 HTTP Message Signatures (https://www.rfc-editor.org/rfc/rfc9421): a signature covers chosen request parts (method, target, authority) plus created, expires, nonce, keyid, tag. IN CODE: signed body carries issued_at/expires_at (60 s), request_id (nonce, replay cache), kid, aud (tag) and the exact path (new in T3b); gate checks T3b-rfc9421-path, T3b-rfc9421-path-desk.
2. IETF WIMSE workload-to-workload HTTP signature draft (https://datatracker.ietf.org/doc/html/draft-ietf-wimse-http-signature): service to service calls are signed by the workload's own key, short lived, bound to the target, replay refused. IN CODE: Desk and Control Plane each sign with their OWN Ed25519 key, over HTTP/3 only; gate checks T3b-wimse-workload-signature, T3b-wimse-replay-refused. Open gap kept honest: ML-DSA hybrid (GAP 2) is not built.
3. RFC 7489 DMARC identifier alignment (https://datatracker.ietf.org/doc/html/rfc7489): trust a sender as a domain only if SPF or DKIM passed AND the authenticated domain aligns with the From domain. IN CODE: aligned is a required real boolean in the request (never defaulted), AD31 returns unaligned and never a tenant; gate checks T3b-rfc7489-alignment-required, T3b-rfc7489-alignment-sql. T3c supplies the real value from the mail door.
4. OWASP Logging Cheat Sheet (https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html): log who/what/when/outcome for failures as well as successes, keep the log tamper-evident, never log personal data. IN CODE: AD32 ledger line per attempt (answered, unavailable, refused, invalid), no address or domain parameter exists, selftest proves no line holds an '@', no attempt without its line (verdict not used); gate checks T3b-owasp-logging-no-pii, T3b-owasp-failures-logged, T3b-no-attempt-without-line.
