# 1k D5b RUNBOOKS, POINT LIST (23 Nov 2026 03:3x PKT). Written BEFORE code, from web research (supportbench runbook maintenance, ServiceNow runbook template best practices, Kustomer/Aircall/Zendesk playbook guides, Ada playbook best practices, rootly playbooks) + RUNBOOK-LIBRARY-DRAFT-22NOV.md + D5-SUBPHASES-22NOV.md.
Order lock unchanged: 1k NOW, then 1l..1o. Sub-steps inside 1k: b1 library, b3 say-this + no-promise gate, b2 checklist; the phase is GREEN only when all three are real.

| # | Point | From | Advance technology next to it |
|---|---|---|---|
| R1 | Nine runbooks, each exactly six parts (sees / may / never / escalate / say / clock); part 3 always carries the no-promise line. | his draft + template research (metadata, triage, steps, escalation) | Desk-own PostgreSQL tables (AD9), versioned rows, gate-checked shape |
| R2 | Owner is a role, not a person: approval owner = the Chairman; owner shown in every header. | research: assign to a team, record owner in header | owner column + CHECK |
| R3 | Semantic version (major/minor/patch) + append-only changelog (what, why, who, when); a version row is never edited. | research: semver + changelog | append-only trigger, SHA-256 hash chain of versions (like AD4b) |
| R4 | Two dates in every header: last updated and last validated; "Not checked for N days" badge after 90 days. | research: staleness detection | pure age function + SQL view |
| R5 | Approval status visible: "Draft, waiting for the Chairman" until he approves; an unapproved runbook still opens but wears the banner. Employee cannot approve. | his 22 Nov 10:42 word | approval fields + door that employees cannot call |
| R6 | Say-this text with one-click copy (selection fallback), case number filled from the screen, plain words. | his D5b-3 | React clipboard + selection fallback |
| R7 | NO-PROMISE GATE: banned words (promise, guarantee, definitely, will be fixed/restored, refund, credit, compensation, discount, free, within N hours) fail the commit AND the SQL CHECK AND the screen load. One whitelisted policy sentence (no-refund). | his 22 Nov 10:42 + 10:47 | rules-gate + SQL CHECK + pure TS checker, three layers with one word list |
| R8 | Guided checklist beside the company: each tick saved with who/when/runbook version; ticks survive reload. | his D5b-2, research (checklist design, step skip rates) | SQL AD9b ticks table (append-only), signed Rust door, kernel-verified, React |
| R9 | Steps are short imperative sentences; no technology words, no phase names, no money. | research: direct imperative steps | text test |
| R10 | Suspension classes SR1..SR8 shown as class code + label as drafted; approval of the words stays with the Chairman (banner). | RUNBOOK-LIBRARY-DRAFT section B | seed data, approval flag false |
| R11 | Fail-closed: runbook read that cannot be verified shows "Data unavailable", never a cached copy. | 1i law | deskCall + kernel verify |
| R12 | 390 / 820 / 1200+, one build, 44 px, no sideways scroll; keyboard: Enter ticks a step. | Rule 34 + 19 | CSS grid minmax |
Later (not 1k, written so nothing is lost): new-hire dry run, post-case runbook gap review, step-skip rate report (Reports phase).

## AUDIT + AUTOFIX (23 Nov 03:5x PKT)
Found and closed in code: L1 slow tick answer for an EARLIER company could appear under the NEW company -> dropped by comparing the company on screen (test); L2 the plan screen accepted a 3-character company that the lookup door refuses -> both screens now use the lookup shape (6..64, letters digits _ -); L3 runbook doors accept only exact bodies (unknown fields refused), a step 0..11, a company in the lookup shape; L4 an agent can never approve (database trigger + door + 403 test); L5 an old runbook version can never be ticked, approved or validated (SQL selftest); L6 a flood of ticks is refused and written to the ledger (selftest).
Open, said plainly: approval by the Chairman has not happened yet (every runbook shows "Draft, waiting for the Chairman"); the nine texts and suspension class words are his to approve; the live tick proof needs a real company reference on his server (the checklist stores only the reference, no customer data).

## HIS BUG REPORT 23 Nov 03:38 PKT (photo of Service health) AND ITS FIX (UI stays intact, additive only)
The red outline on one service row is the "you came from this card" mark (data-hot on the row named in the URL). It did not exist on the Dashboard KPI cards. Fix: the Desk REMEMBERS which card page you opened (desk_return_pure.ts, per-tab sessionStorage, try/catch); when you are back on the Dashboard that card (Command Bar card or area card) wears the SAME red mark and scrolls into view; the page's "← Dashboard" link and the browser Back button both return there. Only the card's own link is marked, never a secondary link inside another card. TESTED: bun 66 pass (3 new: path parsing, home-only, hostile or missing storage), tsc clean, vite build. Chrome look comes after his install.
HIS SERVER NOTE: desk-install of ca5022eb8 = 3 SAME. The SQL (AD9, AD9b) was OK in his SQL editor but "failed on the server": his ad-auto paste is needed to read the exact line (no guess).

## HIS SERVER PASTE 23 Nov 03:42 (ad-auto) AND ITS ROOT CAUSE (found by reproducing, not guessing)
ad-auto printed "AD2: not in the database yet, running it now ... deadlock detected, AD2: FAILED". AD2 and AD3 were NOT new: their CHECKs had turned false because MY AD9 helper desk.fadm_runbook_clean(text) was executable by PUBLIC (rule "no PUBLIC execute on Desk functions"). ad-auto then re-ran AD2 against the live Desk service and deadlocked. Fix: (1) AD9 now revokes it from PUBLIC (fresh installs); (2) NEW sql/AD1c.sql repairs a database where AD9 already ran and sorts BEFORE AD2 so ad-auto reaches it first; (3) ad-auto retries a deadlock up to 6 times (the run is one transaction, so a deadlock changes nothing); (4) AD9-check got a row for it. LESSON written: every new Desk function must be run through the AD2 and AD3 CHECKS on the scratch database before it is sent (all 16 checks now run together).

## BUG 2 (his photo 23 Nov 03:53): Service health row mark did not follow the click
The red border on the services page came from the URL hash (#h3_edge) and stayed on that row. Fix: rows are focusable, a click or Enter moves the mark to the clicked row (data-pick), the hash mark is switched off once a row is picked. Plain DOM attribute, no hook in a branch. Bundle desk-D4jRio_b.js. Not green until installed and clicked in my Chrome.

## BUG 3 (his 23 Nov 03:54): the mark colour was red and he dislikes it. Now the Desk's own light-blue (#8FB8FF, same as the focus ring) for 'you came from / you picked this'. Red stays ONLY for real outage rows. Bundle desk-BV_W3xnS.js.
