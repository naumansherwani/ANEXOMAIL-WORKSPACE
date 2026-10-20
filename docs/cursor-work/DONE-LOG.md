# DONE-LOG — jo kaam HO CHUKA hai, DOBARA NAHI karna (founder 20 Oct 2026 20:10 PKT: "bar bar same kaam repeat ker rahay ho")

> Compact ke baad PEHLE yeh file + `founder/founder-commands.md` padho (Rule 24). Yahan likha kaam dobara mat likho/test mat karo — sirf jo "BAQI" hai woh karo.
> Har kaam ke baad yahan ek line (commit ke saath). Founder ko loophole-list nahi (Rule 29), sirf fix + pull command.

## Security wade (G33–G37) — code + local test DONE
| Kaam | Kahan | Test (local, real stack) | Server par |
|---|---|---|---|
| HMAC-SHA256 device hash (G34) | E42 SQL, `device-hash-migrate.sh`, `HASHING.md` | stub DB | SQL GREEN (founder 20 Oct); migrate script chalana: `bash docs/cursor-work/server/device-hash-migrate.sh` |
| Passkey lazmi + 10 recovery codes (G35) | E43 SQL, `server/routes/auth-passkey.ts`, `PasskeyGate`, `RecoveryCodesPanel` | Playwright 3 sizes + virtual authenticator | SQL GREEN, Brain `brain-passkey-install.sh` (pehle diya) |
| Asli data export ZIP stream (G36) | E44 SQL, `server/rust/export_core.rs/_glue.rs`, `/file/account-export` | real-crate e2e | SQL GREEN, Rust `export` GREEN (20 Oct 19:5x) |
| Blocked account guard (G37) | Rust `export_glue::blocked`, Brain `server/lib/integrity-gate.ts` (+ Leo bridge) | 11 core tests, 5 Bun tests (Leo path, fail-open, cache) | Rust GREEN, Brain GREEN |
| 72h ke baad asli delete + tombstone | E45 SQL (`account_integrity_purge_due(_key)`), timer `integrity-purge/` | local DB: purge/window/founder-blocker/log-trigger | SQL E45 DOBARA chalana (naya version) , timer GREEN (purani) |
| warn/block/24h/deleted EMAIL | E46 SQL (outbox + trigger), `integrity-purge/anexomail-integrity-notify.py` (Postfix 127.0.0.1:25) | local DB + mock SMTP | E46 + timer dobara |
| In-app APPEAL (blocked screen) | E46 `account_integrity_appeal`, Rust proc `account.integrity.appeal`, `IntegrityGate` | Playwright 1440/820/390 | E46 + Rust + Web |
| Device REVOKE = asli auth.sessions khatam | E47 SQL, Rust `device_glue` `device_session_link` | local DB (linked + UA fallback) | E47 + Rust `device` |
| Device record ki deletion date asli | `device_vault_purge` hourly runner mein, UI "deleted automatically on" | script | timer dobara |
| File safety (ClamAV self-hosted) ka sach | `file-safety-check.sh` (EICAR) | mock clamd | founder chalaye (INSTALL=1) |
| IntegrityGate screens (warned/blocked/purged) | `IntegrityGate.tsx` | Playwright 3 sizes | Web pull |
| Export button: chhupa iframe (error par tab JSON par na jaye) | `src/lib/account-export.ts` | build OK | Web pull |
| Review queue UI + device deletion date UI | `AccountIntegrityPanel`, `DeviceVaultPanel` (pehle se maujood) | code padha | — |

## Rules/docs DONE
Rule 29 (AGENTS.md), HASHING.md, PROMISES.md, `sql/CHECK_E42_E47.sql` (read-only green check), E41 line 12 (`\set`) hata di.

## Process lessons (dobara mat karo)
- `pkill -f` / `ps|grep|xargs kill` mein apni command ka text aaye to shell khud mar jati hai (exit 144). Server restart ke liye PID file: `scratchpad/bun.pid`.
- Mock RPC shape: `{ result: { data: ... } }` (plain `{ok,data}` nahi).
- Supabase SQL editor mein psql meta-commands (`\set`) nahi chalte.
- Test order: download click ke baad page badal sakta hai — pehle form test, phir download.

## BAQI (agla kaam, is tarteeb se)
1. E45(naya) + E46 + E47 SQL, Rust `MODULES="device export"`, Brain (pehle se), timer dobara, Web pull — founder ki commands neeche founder-commands.md mein.
2. Live login test — khud test account bana kar (Rule 29), password repo mein kabhi nahi.
3. G38 attachments sending, G40 Rust RPCs (work/crm/org/integrations/settings), G42 passkey Rust port.
4. Basic/Pro/Business ke baqi audits 1440/820/390; Business Pro leftovers.
5. Phir founder profile (shuru se, maujooda code modify) aur AnexoChat.
