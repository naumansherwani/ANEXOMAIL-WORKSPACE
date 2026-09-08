# WIRE BOOK — ANEXOMAIL Workspace (sirf copy-paste)

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
| 06 | Mail — 13 addresses + round-trip gate | `06-mail.md` |
| 07 | Payments :3400 + webhook gate | `07-payments.md` |
| 08 | ANEXOChat — feature-by-feature gate | `08-anexochat.md` |
| 09 | ANEXOVideoCall — signaling · ICE · relay · recording gate | `09-anexovideocall.md` |
| 10 | FINAL AUDIT — saat blocks ek command mein | `10-final-audit.md` |

## Ledger — status

Status sirf teen: **DONE** (live gate green aaya) · **READY** (repo mein hai, server par nahi) · **TODO**.

| Dot | Command | Status |
|---|---|---|
| DB connection | `bash sql/connect.sh` | DONE |
| 59 SQL phases | `bash sql/apply-all.sh` | READY |
| DB verify | `bash sql/verify.sh` | READY |
| Rust :3200 | `bash server/rust/deploy.sh` + `bash server/gates/rust-gate.sh` | READY |
| Caddy + frontend | `bash server/caddy/deploy-sites.sh` + `bash server/gates/web-gate.sh` | READY |
| Mail 13 addresses | `bash server/mail/deploy-mail.sh` + `bash server/gates/mail-gate.sh` | READY |
| Payments :3400 | `bash server/rust/polar-payment/deploy.sh` + `bash server/gates/payments-gate.sh` | READY |
| ANEXOChat | `bash server/gates/chat-gate.sh` | READY |
| ANEXOVideoCall | `bash server/gates/videocall-gate.sh` | READY |
| FINAL AUDIT | `bash server/gates/all-gates.sh` | TODO |

Main koi dot DONE nahi likhunga jab tak uske gate ka asli output green na aaye.
