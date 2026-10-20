# DONE — yeh kaam ho chuka hai, DOBARA NAHI KARNA (Rule 30, founder 20 Oct 2026 20:09 PKT)

Founder (verbatim): "mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo update kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai … latest technology pe kaam kero sirf."
Compact ke baad: pehle `founder-commands.md` + yeh file padho. Neeche ki cheez dobara banane/jaanchne ki zaroorat nahi — sirf "TODO" wali par kaam. Naya kaam hote hi yahan ek line jodo.

## Tareeqa jo test ke liye ban chuka hai (dobara mat banao)
- Local Postgres (`/var/run/postgresql`, DB e39–e45 stubs) — SQL test; real Rust crates offline: scratchpad `realchk`/`fullchk` (`cargo check --offline`); `ptmp.py` = installer ka patch script; Playwright `live/integ.mjs` (blocked/warned/appeal, 3 sizes), `live/pkgate.mjs`, `live/recov.mjs`; local web `build/` + bun :3999 + `proxy.py` :8090.
- DHYAAN: `pkill -f` / `xargs kill` jisme apni command ka text ho shell ko maar deta hai (exit 144) — pid se maro.

## SQL — **E41–E47 + CHECK_E42_E47 sab GREEN (founder 20 Oct 20:21)**
| File | Kya | Halat |
|---|---|---|
| E41 family=real buyer | `\set` line hata di | DONE (live chala) |
| E42 device hash HMAC | `device_hash_v2` + migrate fn | DONE SQL (migrate script chalana: `device-hash-migrate.sh`) |
| E43 passkey/recovery codes | | DONE (live chala) |
| E44 export (scope/page/ticket) | | DONE (live chala) |
| E45 72h purge + tombstone (HMAC email) | `account_integrity_purge_due(_key)` | DONE (live: purge runner `{ok,purged:0,blocked:0}`) |
| E46 notices + appeal + email_hmac migrate | warn/block/24h/purged email outbox, `account_integrity_appeal` | DONE (live chala) |
| E47 device revoke = asli `auth.sessions` kill + links | `device_session_link`, naya `device_trust_set` | DONE (live chala) |
Check: `docs/cursor-work/sql/CHECK_E42_E47.sql` (17 row, sab true).

## Rust (`rust-engine-install.sh`, `MODULES="device export"`)
- export module (ZIP stream, ticket, `account.integrity.me`) + **blocked guard** `export_glue::blocked` — DONE, founder ne chalaya (build OK, 401 saboot).
- `account.integrity.appeal` proc + `device_glue` session link (E47) — DONE, founder ne chalaya (20:21: device 4 tests, export 11 tests, build OK, 401 saboot).

## Brain (`brain-integrity-install.sh`) — DONE, founder ne chalaya (guard + Leo bridge guard, health 200).
## Timers (`integrity-purge/install.sh`) — purge timer DONE (founder chalaya). notify worker (5 min, Postfix) + device_vault_purge hourly — DONE (founder chalaya 20:21; notify claimed=0 sent=0 failed=0 = koi pending notice nahi, theek).
## Web (`pull.sh`) — IntegrityGate, export card, appeal form, "deleted automatically on" — DONE (founder 20:21, server==repo, build OK).
## File safety — `file-safety-check.sh`: clamd **DOWN (RED)** 20:21 -> founder `INSTALL=1` chalaye (ClamAV install); GREEN tab jab EICAR FOUND aaye.

## G38 attachments bhejna (20 Oct 2026) — CODE DONE + local test, server install baqi (founder pull)
- SQL `E48_outgoing_attachments.sql` (+ `CHECK_E48.sql`), Rust `attach` module, Bun `mail/attachments.ts` + `brain-attach-install.sh`, GC timer `attach-gc/`, `attach-check.sh`, Compose UI + thread download — sab ban chuka, local test GREEN (SQL 37/37, Rust 12, Bun 27, real browser 3 sizes). Dobara mat banao; sirf server par chalwana.
- Policy: dedup SIRF org ke andar; bytes `/mnt/anexomail-box/attachments` (mount na ho to 503, NVMe par nahi likhta); DB mein sirf metadata; cap = min(plan, 7 MB raw); clamd down => `scanned:false` (jhoot nahi).
- Founder HAAN 21:38: Caddy `/files/*` band (`attach-caddy-close-files.sh`) + badi hadd. Postfix pehle se 52428800 (attach-check 21:38) => Postfix ko haath nahi lagta; E49 se ceiling 18 MB raw (base64 ~25 MB). Local: 17.5 MB upload OK, 19.5 MB 413, Bun wrap 17.5 MB 193 ms.
- Server par chale (founder 21:34-21:38): Rust `attach` OK (12 tests, build, 3x401); attach-check: storage mount OK, 1.0T khali, clamd DOWN, Caddy /files/* FAIL (band hoga).
- Pending (kaam): G38b inbound bytes, phase48 ledger se quota milana, ClamAV green.
- Test infra: `docs/cursor-work/server/tests/attach/` (README). Dobara mat banao.

- **SQL ab server se (founder 21:28):** `docs/cursor-work/server/sql-run.sh` — ek command, tarteeb se E37..E48 + CHECK_E42_E47 + CHECK_E48; ledger; fail par ruk jata hai (local test: chali, 2nd run skip, FORCE, bad file ruki, CHECK false => exit 1). Editor mein paste ab zaroori nahi. E28/E36 isme nahi (password).

## G38b aane wali mail ke attachments (20 Oct 2026) — CODE DONE + local test, server install baqi
- SQL E50 (+CHECK_E50), `inbound_attach.rs` + `deliver_bin.rs` (spool + `--spool-run`), `mig_mime` `attachment_src`/`attachment_bytes`, `rust-inbound-attach-install.sh` (+ `inbound-attach/` timer), attach-check section 4b, thread chip (download/blocked/pending). Tests: Rust 35, SQL 19/19, `tests/attach/e2e_inbound.sh` 20/20, installer sim OK. Dobara mat banao.
- `rust-engine-install.sh` replace pre-pass ab idempotent (`unless`) + `blocked` flag; patched/unpatched/live-like main.rs par test (duplicate nahi banta).
- Pending (server): sql-run (E50) -> Rust `MODULES="attach"` (blocked flag) -> `rust-inbound-attach-install.sh` -> Web pull.

## Loopholes jo band ho chuke (dobara audit nahi)
- Export sirf queue thi -> asli streaming ZIP (e2e real crates) DONE.
- Block kahin enforce nahi hota tha -> Rust + Brain + Leo guard, fail-open, 30s cache DONE (unit tests).
- purge sirf chat mitata tha -> full `account_purge` + tombstone + log trigger in-transaction DONE (local DB test).
- Block/warn par email nahi -> E46 + notify worker DONE (mock SMTP test).
- Appeal ke liye device hash maangte the -> in-app appeal form DONE (UI test 3 sizes).
- Revoke sirf app-list mitata tha -> `auth.sessions` kill (linked + UA fallback) DONE (local DB test).
- Device deletion date UI "kept until" -> "deleted automatically on"; `device_vault_purge` kisi ne schedule nahi kiya tha -> hourly runner DONE.
- File safety: ClamAV ka sach check/install script `file-safety-check.sh` DONE (mock clamd test); server par chalana baqi.
- Export download tab ko JSON error par le jata tha -> hidden iframe DONE.
- Hash policy `HASHING.md` DONE; E24 `account_deletions.email_hash` -> HMAC migrate fn (E46) DONE.

## TODO (sirf yeh)
1. Founder pulls: SQL E46 -> E47 -> CHECK; Rust `MODULES="device export"`; Timer install; Web pull; `file-safety-check.sh`.
2. Review queue UI + device deletion date UI ka live dekhna (code maujood: AccountIntegrityPanel, DeviceVaultPanel).
3. G38 server install + G38b inbound bytes; G40 Rust RPC (work/crm/org/integrations/settings); G42 passkey Rust port (Bun exception, TECH-MAP).
4. Founder protocol/profile (AnexoChat) — maujooda code modify karna, shuru se nahi.
5. Basic/Pro/Business remaining audit 1440/820/390; father ka account sab ke baad.
