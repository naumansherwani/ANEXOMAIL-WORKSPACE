# ANEXOMAIL — baqi kaam ki poori list (11 Oct 2026) — TARTEEB LOCKED (AGENTS.md Rule 14) — copy; asli list: docs/anexomail-blueprint.md "11 Oct 2026 — remaining work"

Total 27: **26 TODO + 1 READY**. Status sirf DONE / READY / TODO.
Maqsad: awam user kam se kam qadam mein product use kare (signup -> address -> send -> receive).

## A. Mail product (asli buyer ko rokta hai)
| # | Kaam | Status | Kis par rukta hai |
|---|---|---|---|
| 1 | Founder/public alag: `resolved@` basic org mein; "inbox sahi nahi" | TODO | founder_accounts wala SQL output |
| 2 | Company address se send, Sent mein thread, Gmail SPF/DKIM/DMARC | TODO | #1 ke baad send test |
| 3 | Backend: `/accounts` mein company addresses; `/schedule` identity org-check (security); worker `hello@` fallback | TODO | |
| 4 | Test accounts Pro + Business (4 packages) | TODO | |
| 5 | Naya buyer signup: workspace + member + trial plan (Rust) | TODO | sab se bara |
| 6 | Naye buyer ka apna @anexomail.com address + Postfix auto-sync | TODO | #5 ke saath |
| 7 | Compose "From" selector (company address rang ke saath) | TODO | #3 ke baad |
| 8 | Domain wizard UI (3 scenes, DNS ticks, copy buttons) | TODO | #7 ke baad |
| 9 | Mail cinema UI (server par load) | READY | founder screenshot |
| 10 | Repo main <-> server sync (thread route + live-only files) | TODO | live diff output |

## B. Plans aur data
| # | Kaam | Status |
|---|---|---|
| 11 | Business Pro support 12h (phase63 -> E-series, polar.ts untouched) | TODO |
| 12 | Business Pro `workspace_plans.mailboxes_included = 1` galat data | TODO |
| 13 | `plan.ts` limits SQL se copy (drift ka khatra) | TODO |
| 14 | Test accounts ke mailboxes `mail_accounts` mein, `mailboxes` mein nahi -> mailbox limit asli test nahi hui | TODO |

## C. CRM
| # | Kaam | Status |
|---|---|---|
| 15 | Work board "Done" button ka asli test (completed_at) | TODO (founder) |
| 16 | Wada pakadne ka test ("I'll send the quote by Friday" -> Promises page) | TODO (founder) |
| 17 | Graph "teammate ne kis se baat ki" (Business) | TODO, bana nahi |
| 18 | CRM Overview purana Promises card (`crm.promises.list`) galat status filter | TODO |
| 19 | Pro account jahan Loop steps 3-9 dikhein | TODO (#4 ke baad) |

## D. Founder ke browser checks (mere fix ke baad)
| # | Kaam | Status |
|---|---|---|
| 20 | CRM ke saare pages har plan ke account se | TODO |
| 21 | Basic ki 11-point checklist | TODO |
| 22 | Undo send 30s hold, Cmd+K, plan gating | TODO |
| 23 | Business Pro card ke ~35 wade (8K, QUIC, AV1, p50/p95/p99 ...) — abhi sirf naam code mein | TODO |

## E. Baad mein
| # | Kaam | Status |
|---|---|---|
| 24 | Purani mail import (Gmail/Outlook) | TODO |
| 25 | Founder side | TODO |
| 26 | Spreadsheet ("Create a spreadsheet") — kabhi bana nahi, founder se sawal baqi | TODO |
| 27 | Docs update (test accounts, 4 packages, env names, Masood ka asli plan, SLA finding) | TODO |

## F. Security (founder ke zimme)
`/opt/anexomail/.env` plaintext passwords; repo public -> private; purana Supabase token revoke;
chat mein aaya DB password badalna; test passwords rotate; Git ka asli email.

## DONE (is session mein live verify)
- Domain system A (DB), B (Rust, asli DNS 5/5), C receive side (company address par inbound mail).
- Company address mailbox cap + address re-create fix (smoke 17/17).
