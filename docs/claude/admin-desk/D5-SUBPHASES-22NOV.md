# D5 SUBPHASES + ADVANCE TECHNOLOGY (his word 22 Nov 2026 10:27 PKT: "yeh admin desk meri company ki rooh hai, seminar mein bhi samjhana hai, business ki backbone")
Written 22 Nov 2026 10:28 PKT. Rule 52 holds for every step: each answer the employee sees is signed by the Desk Rust signer and verified in the browser by the Desk's own Rust WASM kernel. HTTP/3 only, TLS 1.3 AES-256-GCM, X25519MLKEM768. No phase name is ever shown to an employee (rule 14). No money on the Desk. Desk isolation law: nothing here touches founder code, doors, keys or tables.

## A. THE SEMINAR STORY IN 5 LINES (so he can say it on stage)
1. A customer has a problem. The employee opens that company in the Admin Desk.
2. The Desk asks the Control Plane, live and signed, read-only, and shows package, features, limits, service state, usage. Nothing is copied.
3. The employee types the reason, the look is written in a tamper-evident log.
4. A written runbook tells the employee exactly what to see, do, never do, who to call, what to say, which clock applies.
5. If it needs the owner, one button creates a real case. Money never appears on the employee's screen.

## B. SUBPHASES (build order, each closes only after my live Chrome look, 390 / 820 / 1200+)
| Id | What | Advance technology | Closes when |
|---|---|---|---|
| D5a-1 Contract | The lookup contract in CURRENT.md: allowed fields (package id and version, features on, limits, usage, service state, one flag "payment received, service not active" + since when, freshness time), forbidden fields (any amount, invoice, card, transaction), request format | Written contract + a commit gate that FAILS any Desk file that names an amount / invoice / card field (same style as the isolation gate) | gate fails on a planted bad field, passes clean |
| D5a-2 Package registry | ONE versioned entitlement registry from the landing-page list: package, version, effective date, features, limits, trial and grace rules, SLA target; old subscriptions keep their version | PostgreSQL (fadm_pkg tables in the Desk schema, forced RLS), append-only versions, hash-chained ledger line per version, Rust read door; empty until he supplies the list | an inserted test version cannot be edited, only superseded |
| D5a-3 Signed lookup | Employee opens a company: role check, reason typed, short-lived signed read-only request to the Control Plane, answer checked, nothing stored | Rust Tokio axum, Ed25519 request signature with audience + expiry + request id, HKDF/HMAC, one narrow read-only key, Rule 52 verify in the Rust WASM kernel, HTTP/3 | wrong audience, expired, replayed request all refused |
| D5a-4 Audit with reason | Every look leaves one line: employee, company ref, time, reason, requested fields, request id | PostgreSQL append-only ledger with SHA-256 hash chain (Desk's own), RLS | line appears for every look, chain verifies |
| D5a-5 Fail closed | Control Plane down or slow: screen says "Data unavailable", never old data; show freshness time on every screen | Rust timeout + circuit state, kernel stale-frame check (Rule 52) | live test with the lookup switched off shows the honest message |
| D5 Plan context screen | Company page: package + version, included vs ACTUALLY enabled features, limits and usage bars (90 / 95 marks), service state (Active, Not active yet, Grace period, Suspended, Setting up), SLA target, the one payment flag, freshness | React 19 + TypeScript, Tailwind 4, Framer Motion, registry-driven cards, kernel-verified data, History API router | his eyes on 390 / 820 / 1200+, no amount anywhere |
| D5b-1 Runbook library | The 9 runbooks, each with exactly 6 parts | Desk-own runbook data (PostgreSQL, versioned, approval owner + approved date), React cards | 9 runbooks readable, each with its 6 parts, owner = him |
| D5b-2 Guided checklist | A runbook opens as a step-by-step checklist beside the company (idea from his screenshot: stage bar + checklist panel); each tick is saved to the case | React 19 + Framer Motion, kernel-verified saves, Rust door | ticks survive reload and show in the case history |
| D5b-3 Say-this text | The sentence for the customer, one click copy, in plain words | React, clipboard with selection fallback | copy works on all three widths |
| D5c Escalate | "Escalate to the owner" button makes a real case: company, reason, priority, status flag, audit ref, employee, time; employee sees case number + status; the result comes back the same way | Rust one-way signed hand-over (Desk writes its OWN case table, owner side pulls on its own terms), idempotent request id, PostgreSQL RLS | a test case reaches the owner queue and the answer returns, no founder table touched by the Desk |
| D6 Customers needing you now | First priority card: payment received but not active, grace period, 90 percent usage, 95 percent usage, suspended; count, severity, SLA, runbook link per row | Rust Tokio broadcast over the kernel WebTransport stream (one read for all staff), React card from the registry | numbers equal the Control Plane, never a placeholder |

## C. DISCUSSION: WHAT I KEEP OF HIS RUNBOOK TEXT AND WHAT I CHANGE
KEEP exactly: the 9 problems, the 6 parts per runbook, version control, approval owner.
CHANGE / ADD (my view, he decides):
1. "Storage or seats limit: approved upgrade route": an upgrade is a money act. The employee explains usage and points to the customer's own Billing Portal or the owner; the employee never sells or promises. Wording changed to "explain usage, send the customer to the owner's upgrade route".
2. "Account suspended: approved reason class": I need HIS list of reason classes (for example non-payment, abuse, security hold, owner request). Until he writes it the runbook shows "Reason classes not supplied yet" instead of inventing them.
3. "Grace period": I need HIS number of grace days per package; it comes from the registry, not from the runbook text.
4. "Multiple customers affected" is a runbook only for the first cut; the real incident handling (group, one status message) lands in phase K.
5. "Payment received, service not active": the runbook's first line is the safe flag; second line is escalate with the audit reference. The employee never checks Polar or amounts.
6. I ADD a 7th habit, not a 7th part: every runbook ends with "what to write in the case" so the evidence is the same every time.
7. From his screenshot I take the IDEAS only (a stage bar on the case, a contact card, a short case summary, a guided checklist panel on the side). No copy of that product's look; the Desk keeps its own night-glass style.
DROP now: AI-written summaries (AI for the Desk is dropped until July 2027), dual approval flows, a separate runbook editor UI (first cut: runbooks are written by me in the repo, approved by him, versioned by commit; an editor comes later only if he asks).

## D. WHAT HE MUST GIVE (one at a time, none blocks D5a-1 and D5a-4)
1. Package list as data (features + limits per package, grace days). Blocks D5a-2 filling and D5 screen values.
2. Suspension reason classes. Blocks one runbook only.
3. Where his Control Plane answers (address + how it should verify our signature). Blocks D5a-3 on his server; the code and tests are written first against a local test double.

## E. ORDER NOW
D5a-1 contract and gate -> D5a-4 audit ledger SQL -> D5a-2 registry SQL -> D5a-3 signed lookup (test double) -> D5a-5 fail closed -> D5 screen -> D5b-1..3 -> D5c -> D6. Deadline for the whole Desk stays 26 Nov 2026 07:26 PKT.
