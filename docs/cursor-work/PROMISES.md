# PROMISES.md — footer / Privacy ka har wada: code -> live saboot (Blueprint G33)

> Qaida: jo likha hai woh asal mein hona chahiye. Jo bana nahi, uski line tab tak halki rahe (UK GDPR: jhoota bayan nahi). Har wade ke samne live saboot likho.
> Source text: `src/routes/privacy.tsx`, `src/components/site/SiteFooter.tsx`, `src/components/app/security/AccountIntegrityPanel.tsx`.

| # | Wada (footer/policy) | Code | Live saboot | Halat |
|---|---|---|---|---|
| 1 | Paanch moti nishaniyan (platform, browser, timezone, screen, language) se device record | `signup_device_gate` (phase63 SQL) | code padha | DONE (live test baqi) |
| 2 | Hash hota hai (SHA-256 + pepper) | `device_hash_v2` = HMAC-SHA256 (E42) | stub DB test | READY (server par SQL + migrate baqi) |
| 3 | Encrypted store hota hai | `device_vault` + `DEVICE_VAULT_KEY` | code padha | VERIFY |
| 4 | Canvas/audio/fonts/graphics nahi parhte | `server/rust/device_core.rs` in keys ko hatata hai | code padha | DONE |
| 5 | Device record par **deletion date** | `device_vault.retain_until` (180 din, `device_vault_purge`) | code padha; UI par dikhana VERIFY | CODE DONE |
| 6 | Apne devices dekh kar revoke; revoke se live session foran khatam | E39 `sec_session_kill`; device revoke ? | - | AADHA |
| 7 | 3+ account / 24 ghante mein 3 account = suspicious, review | `device_vault_register`: >=3 accounts ya 24h mein >=3 registrations => state `suspicious` (block nahi, E18) | code padha | CODE DONE; review queue UI VERIFY (G37) |
| 8 | Likhit ek final warning, phir block | `AccountIntegrityPanel` (insaan: warn/block, 12+ char wajah) + user ko `IntegrityGate` (warned = upar patti, blocked/purged = poori screen) | UI 3 sizes mock test; SQL phase24a | CODE DONE (live baqi) |
| 9 | Dobara violation = block; severe = device ban list | `device_bans` | - | VERIFY |
| 10 | Block ke baad **72 ghante export**, phir hamesha delete | export: Rust `export_core/glue` + E44 (ZIP stream); enforce: Rust `export_glue::blocked` + Brain `integrity-gate.ts`; delete: E45 `account_integrity_purge_due` (account_purge + tombstone) + hourly timer `integrity-purge/` | export e2e real-crate; E45 local DB (purge/window/founder-blocker/trigger); gate unit tests | CODE DONE (server par install baqi) |
| 11 | Baatein kisi AI/third-party moderation ko nahi jatin | koi call nahi | code padha | DONE |
| 12 | File safety apne infrastructure par | ? | - | VERIFY |

Audit chalte waqt har "VERIFY" ko live/code se green ya TODO banana hai.

## Passkey (G35) — founder ka faisla 20 Oct: password + passkey dono, passkey lazmi
- Naya account: signup ke foran baad passkey screen (skip button hata diya), phir 10 recovery codes (save tick lazmi).
- Purana account (Humza, test, Masood...): 7 din grace (patti), phir poori-screen gate. `passkey_policy.enforced_at` E43 chalne ka din; `grace_days` = 7.
- 2 passkey (target): 1 hone par patti "backup passkey"; recovery codes khatam hon to patti.
- Login: password ya passkey ya recovery code (`/api/auth/recovery-codes/redeem`, 15 min mein 5 galat par rok).
- Family accounts: koi chhoot nahi (asli buyer jaisa).
