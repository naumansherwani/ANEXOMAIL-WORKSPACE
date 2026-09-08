- [x] SERVER NOW: actual Rust SFU media forwarding :3500 TCP / :3501 UDP banana, deploy karna, aur live packet-forward proof gate dena (sandbox par asli forwarding test GREEN)
- [ ] Add AV1→VP9→H.264→VP8 codec ladder and 3-layer simulcast
- [ ] Add Opus DTX/FEC SDP settings
- [ ] Add truthful P2P/TURN relay badge UI
- [ ] Add Phase 31A features to Business, Business Pro, AI Pro, AI Business, AI Executive package cards
- [ ] Verify Phase 31A and re-check roadmap
- [ ] Phase 31B translation layer: wrap public site pages (landing, plans, security, ownership, move-in, anexochat, auth, footer) with t()
- [ ] Phase 31B: wrap /app/* workspace panels with t()
- [ ] Phase 31B: run server/i18n/translate.py on Hetzner for all 29 locales, review RTL output

## WIRE (sirf copy-paste — koi edit nahi)
- [x] SERVER NOW: Storage Box registration se ghalat Founder JWT dependency hata kar protected SUPABASE4 service RPC lagana
- [ ] SERVER VERIFY: `SUPABASE4_*` protected values se mail pipe auto-sync, sender/recipient order aur queued mail retry ka live GREEN output
- [x] SERVER NOW: mail queue failure ko self-diagnosing/self-retry banana aur final mail gate GREEN karna
- [x] SERVER NOW: har real service port ko one-command deploy + truthful protocol gate dena; SFU ko jhoota DONE/200 na kehna
- [x] SERVER NOW: Postfix implicit TLS :465 aur Rust private readiness/metrics :3600 real listeners deploy karna
- [x] Phase 34 ko repeated runner se hata kar SQL-editor-only single source banana
- [x] Mail deploy/gate mein exact SPF, DKIM local-vs-DNS aur strict DMARC alignment green karna
- [x] Storage Box username har command mein `u659696` fix karna
- [x] Frontend runtime Hetzner + Bun only rakhna; external editor runtime calls na hon
- [x] docs/wire/01-sql-all.md — ek command se saari 59 SQL apply (`bash sql/apply-all.sh`)
- [x] docs/wire/02-sql-phase-by-phase.md — har phase ka apna copy-paste command
- [x] docs/wire/03-verify.md — DB verify (tables · functions · RLS · GRANT)
- [ ] SERVER: apply-all ka output GREEN=59 RED=0
- [ ] SERVER: verify.sh ka output — RLS OFF = 0, NO GRANT = 0
- [ ] NEXT: frontend + Caddy, founder side, ANEXOChat, ANEXOVideoCall — isi copy-paste format mein
- [x] SQL runner: shared DB failure ko 59 jhoote RED ki bajaye preflight par rokna aur asli error foran dikhana
- [x] SQL connection: hidden prompt, login verify ke baad hi protected env save; shell history/repo mein secret nahi
- [x] SQL runner: verified `/root/.anexomail.env` ko purani app env se pehle use karna
- [ ] SERVER: corrected runner se database preflight aur 59 SQL phases GREEN
- [ ] SQL ko ek-command self-healing apply mein wire karna; har purana conflicting function/table safely reconcile ho aur `GREEN=59 RED=0` live proof aaye


## AUDIT 8 Sep 2026 (poora repo)
- [x] Poore repo ke 1876 code errors 0 par — type-check + build green
- [x] Har page ka apna browser/search title (55 pages jo khali the)
- [x] CRM ke dono host repo-managed (`aicrm` + AI-free `crm`) — deploy khud wire karta hai
- [x] web-gate: CRM do host · AI host ke andar ke pages · har host par HTTP/3 · har awam host par founder-leak check
- [ ] SERVER: `bash server/caddy/deploy-sites.sh` + `bash server/gates/web-gate.sh` ka GREEN output (CRM hosts ke A record ke baad)
- [ ] SERVER: mail 13 addresses — SQL + `deploy-mail.sh` + `mail-gate.sh` GREEN

## WIRE GATES (sirf copy-paste — tarteeb se)
- [x] docs/wire/04-rust-engine.md — deploy + gate (/rpc/* asli response, HTTP/3, WT sach)
- [x] docs/wire/05-caddy-frontend.md — frontend build + Caddy sync + har route 200 gate (awam · founder · AI)
- [x] docs/wire/06-mail.md — server/mail/deploy-mail.sh (Postfix+Dovecot+DKIM) + round-trip gate; sirf DNS manual
- [x] docs/wire/07-payments.md — polar-payment deploy + webhook/DB gate
- [x] docs/wire/08-anexochat.md — feature-by-feature gate (message · file · search · receipts · timeline · provenance …)
- [x] docs/wire/09-anexovideocall.md — signaling · ICE · coturn relay · recording gate
- [x] docs/wire/10-final-audit.md — server/gates/all-gates.sh (7 blocks, ek command)
- [ ] SERVER: gate 2..7 ka asli output GREEN (jab tak nahi, ledger mein READY)
- [ ] SERVER: `bash server/deploy-all.sh` live output GREEN; blocker: Hetzner server par founder command run karega

## Founder single inbox (8 Sep 2026) — READY
- [ ] `sql/phase55_founder_single_inbox.sql` — founder inbox truth + recovery `anexomail27@gmail.com`
- [ ] `server/mail/deploy-mail.sh` — ek password (`FOUNDER_MAIL_PASSWORD`) + har address ki copy founder inbox mein
- [ ] verify: `docs/wire/19-founder-single-inbox.md` step 3 green

## 8 Sep 2026 — FINAL ADDRESS LIST (Phase 56)
- [x] `sql/phase56_mailbox_final.sql` — backup table, `nauman@`/`support@`/`trials@` delete,
      `postmaster@`/`abuse@`/`dmarc@` sirf forward -> `resolved@`, family accounts
      (`humzasherwani@`, `raanasherwani@`) business_pro + ai_executive 10,000 credits.
- [x] `server/mail/deploy-mail.sh` — final MAILBOXES/ALIASES, family ka apna password,
      founder copy sirf company addresses par, deleted maildirs backup + root delete.
- [x] `src/lib/founder-plan.ts` + `/app/founder` — sirf asli addresses + family group.
- [ ] Server par run + gate green (READY tak) — `docs/wire/20-final-addresses.md`
- [x] Founder short paths (`/mail` `/calendar` `/chat` `/anexochat` `/anexovideocall` …) — `docs/wire/21-founder-short-paths.md`
- [x] Local sweep: 144 pages sab 200/307, koi blank nahi
- [ ] Mail queue fix — `sql/phase57_mail_schema_heal.sql` + `docs/wire/22-mail-queue-fix.md` (READY)
- [x] mail-gate final list par sach bolta hai (12 addresses, spf_result column dot)
- [ ] ANEXOChat live proof — `bash server/gates/chat-gate.sh` output chahiye
