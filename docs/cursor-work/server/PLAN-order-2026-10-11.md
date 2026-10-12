# ANEXOMAIL — kaam ki tarteeb (11 Oct 2026) — LOCKED (AGENTS.md Rule 14)

Asli list: `docs/anexomail-blueprint.md` -> "11 Oct 2026 — remaining work". Yeh file us ki copy hai; farq ho to blueprint jeetta hai.

Do queue hain. **Queue 1 (AWAM) pehle, poora khatam hone tak Queue 2 (FOUNDER) shuru nahi hoga**, jaisa founder ne kaha (AGENTS.md TARTEEB: anexomail.com pehle, founder workspace baad mein).

## Queue 1 — AWAM product (abhi chal raha hai, #1 se #N tarteeb se)
| # | Kaam | Status |
|---|---|---|
| 1 | `resolved@` basic account se hatana (data leak fix) | DONE — founder screenshot se confirm (11 Oct) |
| 2 | Company address se send, Sent thread, SPF/DKIM/DMARC | DONE — Gmail Show Original: SPF PASS, DKIM PASS (d=mailtest.axonetis.com), DMARC PASS (11 Oct) |
| 3 | `/schedule` identity org-check (security) | Live deploy ho chuka |
| 4 | Test accounts Basic + Pro + Business + Business Pro (4 packages) | DONE — 12 Oct: Pro/Business Postfix routing fix hui; Business Pro ka naya real account banaya (auth.users + identities + organisations + mail_accounts + trial_accounts, plan=business_pro, `pro.test` ke asli row-shape se mirror), `postmap` se Postfix mein confirm |
| 5 | Naya buyer signup: workspace + member + trial (Rust) | DONE — 12 Oct: `account.signup.*` RPC + `trial_provision_workspace` SQL (E17) live end-to-end verify (real auth user -> login -> claim -> organisations/mail_accounts/org_members auto-create). Frontend `/claim` repointed (personal kind; business unchanged). Fix along the way: GoTrue token-column NULL bug, `trial_events_event_type_check` widen |
| 6 | Buyer ka apna @anexomail.com address + Postfix auto-sync | DONE — 12 Oct: `postmap -q` confirm, public route (`anexomail.com/rpc/*` -> Caddy -> Rust) bhi verified, dono body shapes. Sirf asal browser click-through test baqi hai (koi insaan ne live page pe click nahi kiya abhi) |
| 7 | Compose "From" selector (company address rang ke saath) | TODO |
| 8 | Domain wizard UI (3 scenes, DNS ticks) | TODO |
| 9 | Mail cinema UI | DONE — founder screenshot se confirm (11 Oct) |
| 10 | Repo <-> server sync (mail-worker.ts, mail.ts, thread route) | Side branch `wip/e15-ui` par ho chuka; `main` par founder "repo update" kehne par |
| 11 | Business Pro support 12h (phase63 -> E-series) | TODO |
| 12 | `workspace_plans.mailboxes_included` Business Pro ke liye galat | TODO |
| 13 | `plan.ts` limits SQL se copy (drift risk) | TODO |
| 14 | Test mailboxes `mail_accounts` mein hain, `mailboxes` mein nahi | TODO |
| 17 | CRM teammate graph (Business only) | TODO, bana nahi |
| 18 | CRM Overview Promises card (`crm.promises.list`) galat filter | TODO |
| 19 | Pro account jahan Loop steps 3-9 dikhein | TODO |
| 24 | Purani mail import (Gmail/Outlook) | TODO |
| 26 | Spreadsheet ("Create a spreadsheet") | TODO, founder se sawal baqi |
| 27 | Docs update | TODO |

## Queue 2 — Founder side (RECORD, Queue 1 poora hone ke baad shuru)
Founder ne kaha: kaam bohot zyada hai, awam ke baad karna hai. Yahan sirf list mein, abhi shuru nahi.

| # | Kaam |
|---|---|
| 15 | Founder khud Work Done button dabata hai (`completed_at` test) |
| 16 | Founder "I'll send the quote by Friday" bhejta hai, Promises page kholta hai |
| 20 | CRM ke saare pages har plan ke account se (founder browser check) |
| 21 | Basic ki 11-point checklist (founder) |
| 22 | Undo send 30s hold, Cmd+K, plan gating (founder) |
| 23 | Business Pro ke ~35 wade (8K, QUIC, AV1, p50/p95/p99 ...) abhi sirf naam code mein |
| 25 | Founder workspace build (`founderworkspace.anexomail.com`) — AGENTS.md TARTEEB phase 2, awam ke baad |
| F | Security: `.env` plaintext, repo public->private, token/password rotate, git email |

## DONE (is session mein live verify)
- Domain system A (DB), B (Rust, asli DNS 5/5), C receive side (company address par inbound mail).
- Company-address mailbox cap + re-create fix (smoke 17/17).
- `/etc/cron.d/anexomail-sync-maps` (login-address -> Postfix sync) ka asal bug fix: fragile double env-sourcing + `%` escaping cron gotcha, jo isay silently fail kar raha tha. Ab har minute reliably chalta hai — yeh #5/#6 (naya buyer auto-sync) ka foundation hai.
- #5/#6 naya buyer signup (Rust `account.signup.*` + SQL E17 + frontend `/claim` wiring): poora real end-to-end chain live verify hua — fresh auth user, asli GoTrue login, handle claim, workspace+mailbox+org auto-create, Postfix sync, public `anexomail.com/rpc/*` route Caddy se Rust tak. Raste mein mile aur fix hue do real bugs: GoTrue token-column NULL (manual auth.users insert), `trial_events_event_type_check` mein `workspace_provisioned` missing. Live-only Rust CRM/Tasks code jo kabhi GitHub mein push nahi hua tha, usay bhi is session mein `backup/live-rust-12oct` branch par secure kiya gaya.
