# PROMISES.md — footer / Privacy ka har wada: code -> live saboot (Blueprint G33)

> Qaida: jo likha hai woh asal mein hona chahiye. Jo bana nahi, uski line tab tak halki rahe (UK GDPR: jhoota bayan nahi). Har wade ke samne live saboot likho.
> Source text: `src/routes/privacy.tsx`, `src/components/site/SiteFooter.tsx`, `src/components/app/security/AccountIntegrityPanel.tsx`.

| # | Wada (footer/policy) | Code | Live saboot | Halat |
|---|---|---|---|---|
| 1 | Paanch moti nishaniyan (platform, browser, timezone, screen, language) se device record | `signup_device_gate` (phase63 SQL) | code padha | DONE (live test baqi) |
| 2 | Hash hota hai (SHA-256 + pepper) | `digest(... 'sha256')` | code padha | DONE -> G34 HMAC |
| 3 | Encrypted store hota hai | `device_vault` + `DEVICE_VAULT_KEY` | code padha | VERIFY |
| 4 | Canvas/audio/fonts/graphics nahi parhte | `server/rust/device_core.rs` in keys ko hatata hai | code padha | DONE |
| 5 | Device record par **deletion date** | ? | - | VERIFY |
| 6 | Apne devices dekh kar revoke; revoke se live session foran khatam | E39 `sec_session_kill`; device revoke ? | - | AADHA |
| 7 | 3+ account / 24 ghante mein 3 account = suspicious, review | gate sirf 3+ par block | - | VERIFY (G37) |
| 8 | Likhit ek final warning, phir block | `AccountIntegrityPanel`, `account-integrity.ts` | - | VERIFY (G37) |
| 9 | Dobara violation = block; severe = device ban list | `device_bans` | - | VERIFY |
| 10 | Block ke baad **72 ghante export**, phir hamesha delete | ? | - | VERIFY (G36) |
| 11 | Baatein kisi AI/third-party moderation ko nahi jatin | koi call nahi | code padha | DONE |
| 12 | File safety apne infrastructure par | ? | - | VERIFY |

Audit chalte waqt har "VERIFY" ko live/code se green ya TODO banana hai.
