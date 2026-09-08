# WIRE BOOK — ANEXOMAIL Workspace (sirf copy-paste)

**START YAHAN SE: [`00-steps.md`](00-steps.md) — sab steps ek ek command, sirf copy-paste.**

Founder: Muhammad Nauman Sherwani

Yahan koi file edit nahi karni. Koi nano nahi. Har step ka ek box copy karo,
server par paste karo, jo output aaye woh mujhe do. **Ek hi manual hissa hai:
Wire 06 ka DNS table (registrar/Hetzner panel) — baqi sab command hai.**

## Tarteeb (isi order mein)

| # | Block | File |
|---|---|---|
| 01 | Database connect + saari SQL phases | `01-sql-all.md` |
| 02 | Phase-by-phase SQL (agar ek-ek chahiye) | `02-sql-phase-by-phase.md` |
| 03 | Database verify (tables · functions · RLS · GRANT) | `03-verify.md` |
| 04 | Rust PRIMARY engine :3200 + QUIC + gate | `04-rust-engine.md` |
| 05 | Caddy + frontend (awam · founder · AI host) + gate | `05-caddy-frontend.md` |
| 06 | Mail — final address list + round-trip gate | `06-mail.md` |
| 07 | Payments :3400 + webhook gate | `07-payments.md` |
| 08 | ANEXOChat — feature-by-feature gate | `08-anexochat.md` |
| 09 | ANEXOVideoCall — signaling · ICE · relay · recording gate | `09-anexovideocall.md` |
| 10 | FINAL AUDIT — saat blocks ek command mein | `10-final-audit.md` |
| 11 | Mail launch SQL — editor mein direct paste | `11-mail-sql.md` |
| 18 | CRM do host (aicrm + AI-free crm) + gate | `18-crm-hosts.md` |


## Ledger — status

Status sirf teen: **DONE** (live gate green aaya) · **READY** (repo mein hai, server par nahi) · **TODO**.

| Dot | Command | Status |
|---|---|---|
| DB connection | `bash sql/connect.sh` | DONE |
| 59 SQL phases | `bash sql/apply-all.sh` | READY |
| DB verify | `bash sql/verify.sh` | READY |
| Rust :3200 | `bash server/rust/deploy.sh` + `bash server/gates/rust-gate.sh` | READY |
| Caddy + frontend | `bash server/caddy/deploy-sites.sh` + `bash server/gates/web-gate.sh` | DONE |
| CRM do host (aicrm + crm) | `bash server/caddy/deploy-sites.sh` + `bash server/gates/web-gate.sh` | READY |
| ANEXOChat host HTTPS + h3 | `docs/wire/14-anexochat-host-https3.md` | READY |
| Mail SQL (final address list) | `docs/wire/11-mail-sql.md` (editor) ya `bash sql/run.sh sql/phase52_mail_launch.sql` | READY |
| Mail final address list | `bash server/mail/deploy-mail.sh` + `bash server/gates/mail-gate.sh` | READY |
| Payments :3400 | `bash server/rust/polar-payment/deploy.sh` + `bash server/gates/payments-gate.sh` | READY |
| ANEXOChat | `bash server/gates/chat-gate.sh` | READY |
| ANEXOVideoCall | `bash server/gates/videocall-gate.sh` | READY |
| FINAL AUDIT | `bash server/gates/all-gates.sh` | DONE (8 Sep 2026 — 9 blocks green) |
| Live login · 2-user chat · video call | `docs/wire/26-live-login-chat-call.md` | TODO |
| Blueprint match Phase 1→31A | `docs/wire/27-blueprint-match-1-31a.md` | READY (static; live proof = 26) |

Main koi dot DONE nahi likhunga jab tak uske gate ka asli output green na aaye.
