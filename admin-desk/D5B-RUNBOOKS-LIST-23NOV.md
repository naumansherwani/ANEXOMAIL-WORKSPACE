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
