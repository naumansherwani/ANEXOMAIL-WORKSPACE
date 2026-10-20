# DONE — yeh kaam ho chuka hai, DOBARA NAHI KARNA (Rule 30, founder 20 Oct 2026 20:09 PKT)

Founder (verbatim): "mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo update kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai … latest technology pe kaam kero sirf."
Compact ke baad: pehle `founder-commands.md` + yeh file padho. Neeche ki cheez dobara banane/jaanchne ki zaroorat nahi — sirf "TODO" wali par kaam. Naya kaam hote hi yahan ek line jodo.

## Tareeqa jo test ke liye ban chuka hai (dobara mat banao)
- Local Postgres (`/var/run/postgresql`, DB e39–e45 stubs) — SQL test; real Rust crates offline: scratchpad `realchk`/`fullchk` (`cargo check --offline`); `ptmp.py` = installer ka patch script; Playwright `live/integ.mjs` (blocked/warned/appeal, 3 sizes), `live/pkgate.mjs`, `live/recov.mjs`; local web `build/` + bun :3999 + `proxy.py` :8090.
- DHYAAN: `pkill -f` / `xargs kill` jisme apni command ka text ho shell ko maar deta hai (exit 144) — pid se maro.

## SQL (founder Supabase mein CHALA CHUKA: E41–E45 green; E46, E47 abhi chalane baqi)
| File | Kya | Halat |
|---|---|---|
| E41 family=real buyer | `\set` line hata di | DONE (live chala) |
| E42 device hash HMAC | `device_hash_v2` + migrate fn | DONE SQL (migrate script chalana: `device-hash-migrate.sh`) |
| E43 passkey/recovery codes | | DONE (live chala) |
| E44 export (scope/page/ticket) | | DONE (live chala) |
| E45 72h purge + tombstone (HMAC email) | `account_integrity_purge_due(_key)` | founder dobara chalaye (purana function `{ok,purged}` tha) |
| E46 notices + appeal + email_hmac migrate | warn/block/24h/purged email outbox, `account_integrity_appeal` | READY — chalana baqi |
| E47 device revoke = asli `auth.sessions` kill + links | `device_session_link`, naya `device_trust_set` | READY — chalana baqi |
Check: `docs/cursor-work/sql/CHECK_E42_E47.sql` (17 row, sab true).

## Rust (`rust-engine-install.sh`, `MODULES="device export"`)
- export module (ZIP stream, ticket, `account.integrity.me`) + **blocked guard** `export_glue::blocked` — DONE, founder ne chalaya (build OK, 401 saboot).
- `account.integrity.appeal` proc + `device_glue` session link (E47) — READY, dobara installer chalana baqi.

## Brain (`brain-integrity-install.sh`) — DONE, founder ne chalaya (guard + Leo bridge guard, health 200).
## Timers (`integrity-purge/install.sh`) — purge timer DONE (founder chalaya). notify worker (5 min, Postfix) + device_vault_purge hourly — READY, install dobara chalana baqi.
## Web (`pull.sh`) — IntegrityGate (warned/blocked/purged), "Your data" export card, appeal form, "deleted automatically on" — READY.

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
3. G38 attachments sending; G40 Rust RPC (work/crm/org/integrations/settings); G42 passkey Rust port (Bun exception, TECH-MAP).
4. Founder protocol/profile (AnexoChat) — maujooda code modify karna, shuru se nahi.
5. Basic/Pro/Business remaining audit 1440/820/390; father ka account sab ke baad.
