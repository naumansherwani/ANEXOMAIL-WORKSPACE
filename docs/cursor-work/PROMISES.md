> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

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
| 12 | File safety apne infrastructure par | clamd 127.0.0.1:3310 (apna server) + Rust `inbound_attach`/`attach_glue` | founder output 20 Oct: EICAR FOUND, inbound mail scan=clean, Storage Box par bytes | **GREEN (live)** |

Audit chalte waqt har "VERIFY" ko live/code se green ya TODO banana hai.

## Passkey (G35) — founder ka faisla 20 Oct: password + passkey dono, passkey lazmi
- Naya account: signup ke foran baad passkey screen (skip button hata diya), phir 10 recovery codes (save tick lazmi).
- Purana account (Humza, test, Masood...): 7 din grace (patti), phir poori-screen gate. `passkey_policy.enforced_at` E43 chalne ka din; `grace_days` = 7.
- 2 passkey (target): 1 hone par patti "backup passkey"; recovery codes khatam hon to patti.
- Login: password ya passkey ya recovery code (`/api/auth/recovery-codes/redeem`, 15 min mein 5 galat par rok).
- Family accounts: koi chhoot nahi (asli buyer jaisa).

- #13 (21 Oct): 3D v1 + Graphics toggle (har plan, mobile/tablet lite) — code 216b00c; live 390/820/laptop test pending Web pull.
- #14 (21 Oct): test accounts passkey-exempt (real users 27 Oct) — brain-passkey-exempt.sh pending founder run.
