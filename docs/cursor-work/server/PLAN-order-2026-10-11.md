# ANEXOMAIL — kaam ki tarteeb (11 Oct 2026, renumbered 12 Oct 2026) — LOCKED (AGENTS.md Rule 14)

Asli list: `docs/anexomail-blueprint.md` -> "11 Oct 2026 — remaining work". Yeh file us ki copy hai; farq ho to blueprint jeetta hai.

12 Oct 2026: founder ne apni updated list di (Cursor se) — teen naye items A mein (#11-13), teen naye B mein (#18-20), paanch naye C mein (#26-30) insert hue, baqi sab shift hui. Statuses is session ke live-verify aur pehle ke founder-screenshot confirms se check kiye gaye, dobara guess nahi kiye.

Do queue hain. **Queue 1 (AWAM) pehle, poora khatam hone tak Queue 2 (FOUNDER) shuru nahi hoga**, jaisa founder ne kaha (AGENTS.md TARTEEB: anexomail.com pehle, founder workspace baad mein).

## Queue 1 — AWAM product (abhi chal raha hai, #1 se #N tarteeb se)
| # | Kaam | Status |
|---|---|---|
| 1 | `resolved@` basic account se hatana (data leak fix) | DONE — founder screenshot se confirm (11 Oct) |
| 2 | Company address se send, Sent thread, SPF/DKIM/DMARC | DONE — Gmail Show Original: SPF PASS, DKIM PASS (d=mailtest.axonetis.com), DMARC PASS (11 Oct) |
| 3 | `/accounts` company addresses + `/schedule` identity org-check (security) | READY — live deploy ho chuka, lekin is specific check ka green verify command abhi nahi chala, is liye DONE nahi likha |
| 4 | Test accounts Basic + Pro + Business + Business Pro (4 packages) | DONE — 12 Oct: Pro/Business Postfix routing fix hui; Business Pro ka naya real account banaya (auth.users + identities + organisations + mail_accounts + trial_accounts, plan=business_pro, `pro.test` ke asli row-shape se mirror), `postmap` se Postfix mein confirm |
| 5 | Naya buyer signup: workspace + member + trial (Rust) | DONE — 12 Oct: `account.signup.*` RPC + `trial_provision_workspace` SQL (E17) live end-to-end verify (real auth user -> login -> claim -> organisations/mail_accounts/org_members auto-create). Frontend `/claim` repointed (personal kind; business unchanged). Fix along the way: GoTrue token-column NULL bug, `trial_events_event_type_check` widen |
| 6 | Buyer ka apna @anexomail.com address + Postfix auto-sync | DONE — 12 Oct: `postmap -q` confirm, public route (`anexomail.com/rpc/*` -> Caddy -> Rust) bhi verified, dono body shapes. 13 Oct: founder ne asal browser click-through kiya (classic `/auth` signup, "Ali Khan") — bug mila: `signup_device_gate()` signup ko pre-auth 403 se hard-block kar raha tha (Phase 24A locked rule "engine khud block nahi karti" ki violation + `device_vault_register()` ka duplicate, Rule 6). Fix: `docs/cursor-work/sql/E18_signup_device_gate_nonblocking.sql` (auto-block hataya, sirf human-confirmed `device_banned` rehta hai) + `server/routes/auth.ts` cleanup. 13 Oct: server pe deploy (`web /health 200`) + Supabase SQL run, dono founder-confirmed success. DONE |
| 7 | Compose "From" selector (company address rang ke saath) | TODO |
| 8 | Domain wizard UI (3 scenes, DNS ticks) | TODO |
| 9 | Mail cinema UI | DONE — founder screenshot se confirm (11 Oct) |
| 10 | Repo <-> server sync (mail-worker.ts, mail.ts, thread route) | Side branch `wip/e15-ui` par ho chuka; `main` par founder "repo update" kehne par |
| 11 | MailRail: founder inbox aur company inbox alag sections | TODO |
| 12 | `hello@` auto-reply, Option C (ticket number nahi) | TODO |
| 13 | `billing@` receipt on payment success (Polar `:3400`, no-touch) | TODO |
| 14 | Business Pro support 12h (phase63 -> E-series, `polar.ts` no-touch) | TODO |
| 15 | `workspace_plans.mailboxes_included` Business Pro ke liye galat | TODO |
| 16 | `plan.ts` limits SQL se copy (drift risk) | TODO |
| 17 | Test mailboxes `mail_accounts` mein hain, `mailboxes` mein nahi | TODO |
| 18 | Thread analytics sirf Pro+ (backend 403, Basic chip, insights call na ho) | TODO |
| 19 | Integrations + LEO Actions sirf Business+ | TODO |
| 20 | Asli card charge — checkout green hai, paisa cut + workspace active hona baqi | TODO |
| 23 | CRM teammate graph (Business only) | TODO, bana nahi |
| 24 | CRM Overview Promises card committed wade ko "open" dikhata hai | TODO |
| 25 | Pro account jahan Loop steps 3-9 dikhein | TODO |
| 26 | E5 — reply ka Rust push (thread detail pehle se Rust) | TODO |
| 27 | E6 — People, Rust contacts | TODO |
| 28 | E7 — Calendar, Rust reminder | TODO |
| 29 | E8 — Work ka bacha hua Rust (thread notes already green) | TODO |
| 30 | E12 — CRM flagship (screens green, E6 ke baad) | TODO |
| 35 | Purani mail import (Gmail/Outlook) | TODO |
| 37 | Spreadsheet ("Create a spreadsheet") | TODO, founder se sawal baqi |
| 38 | Docs update (test accounts, 4 packages, env names, Masood ka plan, SLA) | TODO |
| 39 | Poora Zoho three-panel look (mail cinema + From selector isko poora nahi karte) | TODO |
| 40 | ANEXOChat Phase 32+ | TODO, sirf founder `## PHASE N` paste karne pe |
| 41 | LEO sirf `ai.anexomail.com` par | TODO |

## Queue 2 — Founder side (RECORD, Queue 1 poora hone ke baad shuru)
Founder ne kaha: kaam bohot zyada hai, awam ke baad karna hai. Yahan sirf list mein, abhi shuru nahi.

| # | Kaam |
|---|---|
| 21 | Founder khud Work Done button dabata hai (`completed_at` test) |
| 22 | Founder "I'll send the quote by Friday" bhejta hai, Promises page kholta hai |
| 31 | CRM ke saare pages har plan ke account se (founder browser check, Ctrl+F5) |
| 32 | Basic ki 11-point checklist (founder) |
| 33 | Undo send 30s hold, Cmd+K, plan gating (founder verify) |
| 34 | Business Pro ke ~35 wade (8K, QUIC, AV1, p50/p95/p99 ...) abhi sirf naam code mein |
| 36 | Founder workspace build (`founderworkspace.anexomail.com`) — AGENTS.md TARTEEB phase 2, awam ke baad; scope founder batayega |
| 42 | Security (= F): `.env` plaintext passwords, repo public->private, purana Supabase token revoke, chat wala DB password badalna, test passwords rotate, Git ka asli email — secrets kabhi repo mein nahi |

## DONE (is session mein live verify)
- Domain system A (DB), B (Rust, asli DNS 5/5), C receive side (company address par inbound mail).
- Company-address mailbox cap + re-create fix (smoke 17/17).
- `/etc/cron.d/anexomail-sync-maps` (login-address -> Postfix sync) ka asal bug fix: fragile double env-sourcing + `%` escaping cron gotcha, jo isay silently fail kar raha tha. Ab har minute reliably chalta hai — yeh #5/#6 (naya buyer auto-sync) ka foundation hai.
- #5/#6 naya buyer signup (Rust `account.signup.*` + SQL E17 + frontend `/claim` wiring): poora real end-to-end chain live verify hua — fresh auth user, asli GoTrue login, handle claim, workspace+mailbox+org auto-create, Postfix sync, public `anexomail.com/rpc/*` route Caddy se Rust tak. Raste mein mile aur fix hue do real bugs: GoTrue token-column NULL (manual auth.users insert), `trial_events_event_type_check` mein `workspace_provisioned` missing. Live-only Rust CRM/Tasks code jo kabhi GitHub mein push nahi hua tha, usay bhi is session mein `backup/live-rust-12oct` branch par secure kiya gaya.
