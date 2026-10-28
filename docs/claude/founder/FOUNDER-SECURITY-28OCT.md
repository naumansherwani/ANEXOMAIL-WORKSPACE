# FOUNDER SECURITY — military level (founder 28 Oct 2026 05:07 PKT)
Hukm: "founder backend mein Rule 52 wala bhi do, builtin browser mein; bahut military level security."

## 0. Loophole jo band hoga (Chrome mein live dekha)
Founder ka login awam ke `anexomail.com/app` (Business user dashboard, "Connect your domain") mein khulta hai — yani founder aur user ek hi darwaza/session. Fix F1a: founder alag host + alag session audience; awam login founder uid ko refuse; founder session awam API par 401. `FOUNDER_PASSWORD` auto-create raasta passkey login ke saboot ke baad band.

## 1. Rule 52 founder mein (kernel browser mein builtin)
- Wahi WASM kernel (web-wasm/), founder SPA mein bhi builtin. Founder ke HAR call par kernel hmac tag lagata hai; founder binary mein `ANEXO_TAG_MODE=enforce` HAMESHA (awam ki tarah observe nahi). Bina tag = 401.
- Kernel founder mein extra modules: audit-chain verify (SHA-256 chain browser mein), response signature verify (server har founder jawab par HMAC lagata hai, kernel check karta hai), intent (do-tap + reason) tag.
- Kernel wasm pinned: SHA-256 pin `pin.gen.ts`; pin na milay to founder SPA chalne se inkar.

## 2. Login/session
Password + passkey (WebAuthn, user-verification required, platform key), phir device approval + IP allowlist (Caddy + nftables). Session chhota (15 min idle), token sirf memory + HttpOnly/SameSite=Strict cookie, alag audience `founder`. Naya device = pehle purane device se approve. Break-glass: offline recovery code, use hone par LOG + alert.

## 3. Process/server
Alag Linux user, alag systemd service, no shell, read-only filesystem (ProtectSystem=strict), NoNewPrivileges, seccomp, sirf apna port; DB mein alag Postgres role (least privilege), service-role key sirf founder binary ko. Bun/Node founder mein nahi.

## 4. Har action
Do-tap + wajah (reason) + `founder_audit` (append-only SHA-256 chain + HMAC); khatarnak action (delete, plan badalna, refund) par passkey step-up dobara. Content kabhi nahi (metadata-only lock).

## 5. Web hardening
Strict CSP (no inline, no eval, sirf apna origin + wasm), COOP/COEP, Trusted Types, SRI, HSTS preload, no third-party scripts/analytics/fonts founder par, rate-limit + lockout, sab error generic.

## 6. Test (phase exit)
founder uid + awam login = 403; awam uid + founder host = 401; tag ke bina = 401; tampered audit chain browser mein pakda jaye; naya device bina approval = inkar.
