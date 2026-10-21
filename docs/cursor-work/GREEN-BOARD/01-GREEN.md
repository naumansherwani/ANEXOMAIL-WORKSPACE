# 01 — GREEN (live saboot ke saath)

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

## A. Plan (P1–P9) mein se green
| Phase | Item | Saboot |
|---|---|---|
| P1 | Login cinema split (auth page) | Plan status board: 'LIVE — screenshot liya'; login live (B1/B2 proofs) |
| P1 | Session persist (refresh pe logout nahi) | B1 GREEN 21 Oct 04:55: refresh asli, logout 26 s baad token 401 (revocation) |
| P3 | Scheduled send | B3: mail.schedule/hold Rust worker, proof SAB PASS (asli Postfix), Compose 'Held for 30s' live |
| P3 | Undo send | G-UNDO GREEN 21 Oct 01:20 (cancel 200, mail nahi aayi) + B3 undo/409 proofs. NOTE: plan 10 s likhta hai, product 30 s |
| P4 | Scheduled send UI | Compose live: 'Sending… Held for 30s' toast |
| P4 | Undo send countdown toast | G-UNDO GREEN (30 s, Undo button) — plan '10 s' purana |
| P5 | Conversation view (replies grouped) | Thread live dekha 390/820 (Basic) |
| P7 | Week view (primary) | Calendar desktop week = TimeGrid live: create, drag move+resize LIVE VERIFIED (21 Oct 04:25) |
| P7 | Create/edit/delete event | calendar.create GREEN after E51 (21 Oct 00:50), calendar.update drag persisted; delete live saboot nahi |

## B. G-series green
| G | Kaam | Saboot |
|---|---|---|
| G3 | Rust latest (edition 2024, axum 0.8.9, wtransport 0.7.2) | tokio 1.53.3/axum 0.8.9/wtransport 0.7.2/rustc 1.99.1 live |
| G10 | Passkey flow verify | B2 GREEN: passkey proof SAB PASS (20 checks) + B2b |
| G17 | Admin Members/Teams/Invitations | ledger B: G17/L76 team invites live |
| G23 | People import Rust port | people_core/people_glue; live 182 procs ✔ |
| G28 | Rust cal glue asli compile server par | calendar.create/update live (E51 + drag) |
| G29 | Revoked member guard (mail_identity) | live 06:16 |
| G31 | Team seat/audit chain/work address (E34) | live 06:06 |
| G32 | manager rank | live 06:16 |
| G38b | Aane wali mail ke attachment bytes | inbound hello.txt download 200 (01:15); PROMISES #12 EICAR FOUND |
| G42 | Passkey/recovery login Rust par | B2 GREEN 05:50 |

## C. Technology green
| Technology | Saboot |
|---|---|
| Tokio async 1.53.3 | live |
| axum 0.8.9 | live |
| QUIC wtransport 0.7.2 (quinn) | live; ufw 3443/udp open item D11 |
| tRPC-style /rpc/* | live |
| B1 Rust JWT local verify + refresh | 21 Oct 04:55 |
| B2 passkey/recovery Rust (G42) | 05:50 |
| B2b Bun hardening + passkey list/delete | 05:50 |
| B3 mail.send/undo/queue worker/org.mailboxes (R1) | 06:00 |

## D. Ledger section B (live green, dobara mat chhuo)
- tokio 1.53.3 / axum 0.8.9 / wtransport 0.7.2 / rustc 1.99.1 + edition 2024 — live 20 Oct.
- L1/L2 mail TLS cert + expiry watch — live.
- E37 (anjaan pata quarantine), E38 (thread count), R1a Rust inbound pipe — live.
- G29 revoked guard, G31 seat/audit/work address (E34), G32 manager rank, G17/L76 team invites — live.
- E41–E47 + CHECK_E42_E47 (family real buyer, device hash HMAC, passkey/recovery tables, export, purge, notices/appeal, revoke sessions) — founder 20:21.
- G38 SQL E48/E49/E50 + CHECKs; Rust `attach`; attach-gc timer; Caddy `/files/*` band; attach-check — founder 23:50.
- E51 calendar fix, calendar create/drag, E53 session alive, E54 mail queue claim — live.
- Basic account Chrome: 21-page sweep (0 empty/0 error), 39 loads (13 routes × 390/820/1200), billing -> Polar checkout opens (Pro £46/mo, not paid).
- Basic = GREEN (founder haan, 21 Oct 04:30; saboot `BASIC-AUDIT-DONE.md`).
- A1 repo-vs-server audit + A2 live-snapshot (af24025) — GREEN.
- Brain: auth-harden, CRM tenant isolation, passkey-harden, mail (claim/cancel), refresh — installed, health 200.
- Rust deliver (anexopipe -> Rust) 21 Oct 06:40: 35 tests, asli Postfix -> Rust -> DB OK.
- Web pull 21 Oct 06:35: server==repo src 490/491 (sirf routeTree.gen.ts generated diff).
