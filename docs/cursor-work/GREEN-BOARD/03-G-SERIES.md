# 03 — G-series G1–G42

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

**FOUNDER RULE (21 Oct 06:56): file server par aa gayi aur wire hai = GREEN.** Do darje: 🟢 live dekha/proof (pakka) · 🟢 server par aaya + wire (live click-test baqi). Baqi sab NOT-GREEN.
**Zubaan:**
- 🟢 **GREEN** = live saboot (founder ka server output ya Chrome mein dekha) — dobara mat chhuo.
- 🟢 **GREEN (server par)** = file repo mein hai AUR pull/installer se server par aa chuki (Web server==repo 490/491; Rust/Brain installer chala) — ab sirf Chrome mein dekhna.
- 🟠 **PARTIAL** = kuch hissa green/maujood, kuch baqi.
- 🔴 **TODO** = repo mein bana hi nahi (ya server par nahi chala).
- 🔵 **FOUNDER** = founder ka faisla/haan/login/DNS chahiye.
- ⚪ **PARKED** = founder ne rok rakha.
**Dhyaan:** "server par aaya" repo grep + server==repo pull output se hai; chalta hai ya nahi wo Chrome click-test se tay hoga (list: NOT-GREEN/01).

| G | Kaam | Status | Saboot / baqi |
|---|---|---|---|
| G1 | Attachments bhejna | 🟠 PARTIAL | Rust attach 12 tests + E48/E49 GREEN (23:50); Brain attach installed; Compose attach SEND live test baqi (C3) |
| G2 | Admin ke baqi 9 pages + Chat harness | 🔴 TODO (bana nahi) | D9; Basic sweep mein Admin plan-gated dikha |
| G3 | Rust latest (edition 2024, axum 0.8.9, wtransport 0.7.2) | 🟢 GREEN (live dekha/proof) | tokio 1.53.3/axum 0.8.9/wtransport 0.7.2/rustc 1.99.1 live |
| G4 | R1 mail.send / R3 typed contract / R4 direct pool / R5 push | 🟠 PARTIAL | R1 GREEN (B3 06:00); R5 READY (B4, install baqi); R3 + R4 TODO |
| G5 | /api/mail/send Bun fallback identity ignore | 🟠 PARTIAL | Rust send identity-checked (GREEN); Bun fallback par identity check = CHECK |
| G6 | IMAP phone sync (Dovecot, 8 KB store) | 🔴 TODO (bana nahi) | audit baqi (D9) |
| G7 | catch-all/forwarding/vacation/signature verify | 🔴 TODO (bana nahi) | C9 8-series NEXT; audit baqi |
| G8 | Urdu/RTL + web push; M11 React Compiler | 🔵 FOUNDER chahiye | M11 vite.config.ts no-touch ki chhoot chahiye |
| G9 | Plan-promise audit (plans.ts har line) | 🔴 TODO (bana nahi) | D9; Basic card/real product match ho chuka (04:30), Pro+ baqi |
| G10 | Passkey flow verify | 🟢 GREEN (live dekha/proof) | B2 GREEN: passkey proof SAB PASS (20 checks) + B2b |
| G11 | Bun 1.4.0→1.4.3 | 🔴 TODO (bana nahi) | B8 |
| G12 | Rust restarts=48 wajah | 🔴 TODO (bana nahi) | pm2 ↺ ab 73 (rust) / 215 (web): wajah audit nahi hui — har installer restart hai, panic count dekhna |
| G13 | Real-phone verification | 🔵 FOUNDER chahiye | founder ka phone |
| G14 | SECURITY L25 crm tenant isolation live | 🟠 PARTIAL | Brain CRM tenant isolation installed (02:00, health 200, unauth 401); crm-tenant-check.sh live baqi |
| G15 | CRM SPA Link (full reload hataana) + useAssignShared body | 🔴 TODO (bana nahi) | code audit baqi |
| G16 | Self-serve billing (cancel/card/VAT via Polar portal) | 🔴 TODO (bana nahi) | B6 (Polar :3400 NO-TOUCH) |
| G17 | Admin Members/Teams/Invitations | 🟢 GREEN (live dekha/proof) | ledger B: G17/L76 team invites live |
| G18 | Founder workspace Rust-only (Rule 22) | 🟠 PARTIAL | 181 Rust-pehle, 19 Bun-only -> B5/G40 |
| G19 | Switch-journey gaps (a Integrations migrate, b…) | 🟠 PARTIAL | G19a = G30 worker (code+installer; 'Import mail' screen dikhi); baqi parts audit |
| G20 | Plan-wise baqi (Business Pro data/entitlement bpro.test) | 🔴 TODO (bana nahi) | D7 |
| G21 | Baqi Brain routers authz audit | 🔴 TODO (bana nahi) | D7 |
| G22 | org.ts sach-jhooth (workspacePlanOf, compliance) | 🔴 TODO (bana nahi) | D7 |
| G23 | People import Rust port | 🟢 GREEN (live dekha/proof) | people_core/people_glue; live 182 procs ✔ |
| G24 | Personal Premium claims live test (8K relay, 40-person group) | 🔴 TODO (bana nahi) | D8 |
| G25 | founderworkspace host par public site aaya (WebFetch) | 🔴 TODO (bana nahi) | edge/redirect check baqi |
| G26 | Calendar guest iMIP reply | 🔴 TODO (bana nahi) | B7 (production mail path: founder 'haan' chahiye) |
| G27 | Recurrence / scheduling link / 2-way sync / CalDAV | 🔴 TODO (bana nahi) | B7 |
| G28 | Rust cal glue asli compile server par | 🟢 GREEN (live dekha/proof) | calendar.create/update live (E51 + drag) |
| G29 | Revoked member guard (mail_identity) | 🟢 GREEN (live dekha/proof) | live 06:16 |
| G30 | Gmail/Outlook IMAP import worker | 🟠 PARTIAL | code+installer; live saboot ka record CHECK; OAuth app = Phase 2 founder |
| G31 | Team seat/audit chain/work address (E34) | 🟢 GREEN (live dekha/proof) | live 06:06 |
| G32 | manager rank | 🟢 GREEN (live dekha/proof) | live 06:16 |
| G33 | Wade ka audit (PROMISES.md) | 🟠 PARTIAL | 12 rows + #13/#14; 'VERIFY' rows baqi (3,5,6,7,9 …) |
| G34 | HMAC device hash | 🟠 PARTIAL | E42 SQL GREEN; purane hash migrate (device-hash-migrate.sh) chala ya nahi = CHECK (C5) |
| G35 | Passkey lazmi + recovery codes | 🟠 PARTIAL | B2 Rust GREEN; E43 live; banner/gate live check + 27 Oct deadline (test accounts exempt: brain-passkey-exempt.sh) |
| G36 | 72 h export → delete (countdown + email) | 🟢 GREEN (server par aaya + wire; live click-test baqi) | E44/E45/E46 live; UI/email countdown ka live dekhna (C7) |
| G37 | 24h me 3 account suspicious/review + warn→block→ban | 🟢 GREEN (server par aaya + wire; live click-test baqi) | review queue UI live dekhna (C7) |
| G38 | Compose attachments bhejna | 🟠 PARTIAL | see G1 |
| G38b | Aane wali mail ke attachment bytes | 🟢 GREEN (live dekha/proof) | inbound hello.txt download 200 (01:15); PROMISES #12 EICAR FOUND |
| G39 | Family = real buyer / lifetime label | 🟠 PARTIAL | E41 GREEN; 'Lifetime access' label live check (Humza) C8 |
| G40 | Rust RPC work/crm/org/integrations/settings (19 Bun-only) | 🔴 TODO (bana nahi) | B5 |
| G41 | Har package par 390/820/1440 live test | 🟠 PARTIAL | Basic GREEN (04:30). Pro/Business/Business Pro TODO |
| G42 | Passkey/recovery login Rust par | 🟢 GREEN (live dekha/proof) | B2 GREEN 05:50 |
