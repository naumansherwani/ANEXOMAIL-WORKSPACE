# FOUNDER LOOPHOLE LEDGER (30 Oct 2026 19:30 PKT) — Chrome audit, har item ka fix ya ghar

Audit: founder ke signed-in Chrome tab, 12 views, console, network. Qaida (Rule 29/33): loophole mile to usi turn mein fix; jo abhi fix nahi ho sakta uska phase aur wajah yahan likhi hai.

| # | Maslah | Status | Fix / ghar |
|---|---|---|---|
| L1 | `/founder/v1/actions` har view badalne par dobara (~900 ms), khali jhalak | FIXED 30 Oct | Decks.tsx: pichla asli server jawab foran dikhta hai, peeche taza aata hai (mock nahi) |
| L2 | Bridge pehli call ~1.4 s, actions ~0.9 s (sequential Supabase round-trips) | FIXED + Chrome proof 30 Oct 19:37: Bridge 1466 -> 863 ms, actions ~900 -> 821 ms first load (baqi waqt Supabase round-trip; auth cache NAHI kiya: device revoke foran band rehna zaroori) | main.rs: auth `is_founder`+`device_ok` ek saath (tokio::join!), Bridge mein Polar pulse bhi join, pulse+rejects ek saath; 61 tests pass; naap founder-install ke baad Chrome mein |
| L3 | Sidebar "Workspace (user app)" links founder host par awam `/app` kholte hain (host mix) | FIXED + Chrome proof 30 Oct 19:37 (links _blank noopener, https://anexomail.com/app) | links ab `https://anexomail.com/app...` naye tab mein (noopener); founder SPA kabhi awam page par navigate nahi karta. Server par `/app` ka hat jana F9 |
| L4 | Trust chip amber "Review": browser verify nahi karta | GREEN 30 Oct 20:20: server + Chrome (chip "Trusted", asli jawab kernel se verify, fonts 6/6 loaded, bundle index-3Lfb3QXU) | web-wasm v0.5.0 `ed.rs` (ed25519@1, envelope@1), pinned key s1, Worker, enforce; chip tab green jab asli jawab verify ho |
| L9 | Bridge par Billing/Finance/Customer voice totals (trend = Dashboard ka kaam) | FIXED + Chrome proof 30 Oct 19:37 | naya view "Company health" (`#/dashboard`, g d) mein gaye; Bridge par Money exceptions sirf jab past due/grace ho |
| L5 | Host guard `probe` (enforce nahi) | FOUNDER STEP — docs/claude/founder/FOUNDER-ONLY-STEPS.md (3 qadam) | `/founderlogin` ek baar -> `founder-hostguard.sh status` -> `enforce` |
| L6 | 6 Inter weights "not loaded" | WAS A BUG, FIXED + Chrome GREEN 30 Oct 20:20 (fonts 200..700 loaded) | meri pehli rai ghalat thi ("not a bug"). Asal wajah: CSP `default-src 'none'` ke saath `font-src` nahi tha, Inter hamesha block (sandbox ke asli CSP test mein pakda). `font-src 'self'` add + Rust test |
| L7 | package-lock.json stale | FIXED 30 Oct 20:40 (green) | npm registry se baar baar fail (proxy/timeout), isliye lock ab `founder-web/bun.lock` (bun, 1 s mein bana). Purani stale package-lock.json hata di. Saboot: saaf folder mein `bun install --frozen-lockfile` (136 packages) + tsc 0 errors + vite build OK. Command: `cd founder-web && env -u NO_PROXY -u no_proxy bun install --lockfile-only` (sandbox mein NO_PROXY registry ko bypass karta hai). Server par kuch nahi |
| L8 | Galat hash (`#/mail`) bridge par aata hai | OK by design | unknown view -> bridge |

# TECHNOLOGY MAP — MIX NAHI (locked, Rules 52/61/62/66)
| Parat | Technology | Kaam | Kabhi nahi |
|---|---|---|---|
| WASM kernel `web-wasm/` | Rust -> wasm32, plain extern "C" ABI, ek hi kernel (Rule 52), tokio LocalSet async, Web Worker mein, SRI pinned | verify (Ed25519 envelope), HMAC sign, HKDF, Merkle, audit chain; backend se `.wasm` ke roop mein aata hai | DOM, network, UI, React |
| Backend `anexomail-founder` | Rust axum 0.8 + tokio, 24x7 systemd | sign, DB, gates | Bun/Node |
| UI (kya dikhta hai) | React 19.2 + TypeScript + TanStack Router + Tailwind 4.2 + shadcn | views, forms, palette | crypto ka faisla |
| Cinematic | CSS (aurora, glass, flip clock) + Three.js WebGPU lazy (sirf 3D/city) | look, motion | data ya verification |
Qaida: UI sirf kernel ka natija dikhata hai; kernel "TAMPERED" kahe to data render nahi.

| L10 | Top bar par "Lahore · time" chip faltu; search kinare par | FIXED + Chrome GREEN 30 Oct 19:56 (search beech mein, Lahore chip gaya, flip clock + Review chip intact) | chip hata (App.tsx CityTime removed), search `.tpc` center (ui.css grid); flip clock aur Review chip same |
| L7b | npm lockfile regen registry se fail | CLOSED (L7: bun.lock) | — |
| L11 | Page refresh: ~3.7 s khali kala screen, logo nahi (JS 416 KB bina compression, `no-store` har file par, har refresh dobara download) | FIXED + SERVER + CHROME GREEN 30 Oct 19:56 (refresh FCP 3731 ms -> 571 ms; JS cache se 53 ms, gzip 133 KB, assets immutable, index no-store) | (a) Rust: hashed `/assets/*` = `cache-control: public, max-age=31536000, immutable` (index.html aur har /founder/v1 jawab `no-store` hi); (b) `precompressed_gzip` + `founder-web/precompress.sh` (472 KB -> 144 KB); (c) index.html mein foran dikhne wala logo + loader (`public/boot.css`, React ke render par hat jata hai, CSP style-src 'self' ke andar). 62 Rust tests pass |
| L12 | Browser kernel ka Worker strict CSP (`require-trusted-types-for 'script'`) ke saath nahi chalta tha (sandbox mein plain server par chalta dikha, asli CSP server par rukta) | FIXED 30 Oct 20:25 | Trusted Types policy `anexo-kernel-worker` (sirf `/_cc/assets/`), Vite `?worker&url`; sandbox test ab asli CSP + COEP header ke saath (`csp_srv.py`) |
