# FOUNDER ESCALATION INBOX (the founder-side receiver of the Admin Desk) - PLAN + WHAT COMES TO THE FOUNDER
STATUS: PLANNED (parked by his order 23 Nov 2026 04:25-04:29 PKT). Starts AFTER 1o DASHBOARD FINAL and 1a (Desk HTTP/3 off Caddy). The commit gate FOUNDER INBOX REMINDER keeps this from being forgotten.
HIS WORDS (04:29): "jo jo ana hai admin desk ka mere pass escalate hona hai woh sab admin desk ke saath bana hai, phases ke hisab se samjhao; founder ke pass kya kya ana hai; yeh anexomail company ka system design hai, ek bar hota hai, bar bar nahi hota."

## HIS WORDS (23 Nov 2026 04:55 PKT, 04:34): the inbox is its OWN FOLDER in the founder UI. He is Founder, Chairman, CEO and Managing Director and handles every escalation PERSONALLY; it stays with him always. The system must be Elon-Musk-level: instant, clear, nothing lost, decision in a few taps, works on phone 390 as well as laptop. DESIGN GOALS from that: (a) one screen = every open case sorted by urgency with the audit reference and the Desk's own words; (b) decision actions are few (approve, decline, ask the employee, hand to engineering), each needs his fresh passkey touch (founder policy); (c) a push/notification path to his phone for urgent cases (founder lane, researched in that phase); (d) the whole history is a signed append-only chain he can verify.

## RULES THAT STAY (Desk isolation + UI law + Rule 52)
1. ONE-WAY SIGNED HAND-OVER. The Desk writes the case in its OWN table (owner = founder side) and signs it (Rule 52, Desk Ed25519). The founder side PULLS it on its own terms, verifies the signature in ITS OWN Rust kernel, and keeps its OWN copy in its OWN table. The founder side never reads a Desk table, never calls a Desk door, never shares a key. The result goes back the same way (founder signs, Desk verifies).
2. ONLY METADATA + AUDIT REFERENCE travels. No money evidence, no card, no invoice. Money evidence stays on the founder side.
3. Idempotent request id, replay-safe, expiry, fail-closed (a bad or old signature is refused and counted, never shown).
4. UI LAW: the founder UI is never touched without his "haan" per feature. This is proposed as an ADDITIVE panel with a DEMO ARTIFACT first, his pick, then code. Advance technology is researched on the web and written in the phase LIST + blueprint + NOW-LIST BEFORE code (RESEARCH-IN-BLUEPRINT law).
5. Phone 390 / tablet 820 / laptop 1200+ in the same build (Rule 34 + 19).

## WHAT COMES FROM THE ADMIN DESK TO THE FOUNDER, BY DESK PHASE (sourced from the Desk docs, nothing invented)
| Desk phase | What reaches the founder | Source |
|---|---|---|
| 1l D5c Escalate | The ESCALATION CASE: company id, reason, priority, account / payment status flag, audit reference, employee identity, time; the employee sees case number + status; the founder's DECISION/RESULT returns the same way | D5-DECISIONS-AND-EXTRACT-22NOV.md items 3 and 20 |
| 1k D5b runbooks (the "escalate" line of each guide) | Payment received but service not active -> owner case with audit reference (priority high if older than the plan's target); Storage or seats limit -> upgrade is a money act, goes to the owner, the employee never sells; Account suspended -> escalation named by the reason class; Multiple customers affected (first cut) -> owner case | D5B-RUNBOOKS-LIST-23NOV.md + runbooks.seed.json |
| 1m D6 cards B1..B13 | The priority/escalation card counts and the Chairman Escalations Inbox card (1-2 critical Enterprise cases awaiting his decision; data stays empty until the Enterprise plan row exists) | BRIDGE-FEATURES-22NOV.md row 3 |
| 1h D5a-4 audit | The signed audit checkpoints of lookups (who looked at which company and why) copied outside the database: the founder can verify them without the Desk database | D5A4-AUDIT-PROOF-LIST-23NOV.md |
| R4 Control Plane / probes | A critical outage or a Desk freeze (HTTP/3 edge, TLS, database, signer, ledger) as a signed alert | BRIDGE-FEATURES-22NOV.md |
| 1n E+F | To be listed when E and F are written (their escalations are added here in the same step) | NOW-LIST |
| R5g Escalations (engineering hand-off, on-call) | Hand-over of a case to engineering with context and an owner | WORLD-CLASS-DESK-MODULES-22NOV.md |

## SCHEDULE
After 1o and 1a: (1) web research for the inbox -> LIST file + blueprint + NOW-LIST + CURRENT.md contract; (2) SQL in the FOUNDER lane (schema-first law), (3) founder Rust verifier + kernel call, (4) demo artifact of the panel -> his haan -> React panel, (5) his install + my Chrome proof at 390 / 820 / 1200+. Then GREEN. FOUNDER-ESCALATION-INBOX
