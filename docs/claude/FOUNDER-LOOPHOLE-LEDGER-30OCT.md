# FOUNDER LOOPHOLE LEDGER (30 Oct 2026 19:30 PKT) — Chrome audit, har item ka fix ya ghar

Audit: founder ke signed-in Chrome tab, 12 views, console, network. Qaida (Rule 29/33): loophole mile to usi turn mein fix; jo abhi fix nahi ho sakta uska phase aur wajah yahan likhi hai.

| # | Maslah | Status | Fix / ghar |
|---|---|---|---|
| L1 | `/founder/v1/actions` har view badalne par dobara (~900 ms), khali jhalak | FIXED 30 Oct | Decks.tsx: pichla asli server jawab foran dikhta hai, peeche taza aata hai (mock nahi) |
| L2 | Bridge `/bridge` pehli call ~1.4 s | OPEN | server side (Rust `bridge` ke DB queries ek saath chalana); F2c ke saath naapna |
| L3 | Sidebar "Workspace (user app)" links founder host par awam `/app` kholte hain (host mix) | TRANSITION | Isolation §0: F9 mein awam `/app` founder host se hat jata hai; tab tak links sirf founder ke liye, awam token founder par nahi chalta |
| L4 | Trust chip amber "Review": browser verify nahi karta | OPEN, NEXT | F2b: web-wasm ed25519 verify, enforce mode |
| L5 | Host guard `probe` (enforce nahi) | FOUNDER STEP | `/founderlogin` ek baar -> `founder-hostguard.sh status` -> `enforce` |
| L6 | 6 Inter weights "not loaded" | NOT A BUG | font-display swap, sirf istemal par load |
| L7 | package-lock.json stale | OPEN, low | server npm nahi chalata; sandbox mein env -u NO_PROXY se dobara banana |
| L8 | Galat hash (`#/mail`) bridge par aata hai | OK by design | unknown view -> bridge |

# TECHNOLOGY MAP — MIX NAHI (locked, Rules 52/61/62/66)
| Parat | Technology | Kaam | Kabhi nahi |
|---|---|---|---|
| WASM kernel `web-wasm/` | Rust -> wasm32, plain extern "C" ABI, ek hi kernel (Rule 52), tokio LocalSet async, Web Worker mein, SRI pinned | verify (Ed25519 envelope), HMAC sign, HKDF, Merkle, audit chain; backend se `.wasm` ke roop mein aata hai | DOM, network, UI, React |
| Backend `anexomail-founder` | Rust axum 0.8 + tokio, 24x7 systemd | sign, DB, gates | Bun/Node |
| UI (kya dikhta hai) | React 19.2 + TypeScript + TanStack Router + Tailwind 4.2 + shadcn | views, forms, palette | crypto ka faisla |
| Cinematic | CSS (aurora, glass, flip clock) + Three.js WebGPU lazy (sirf 3D/city) | look, motion | data ya verification |
Qaida: UI sirf kernel ka natija dikhata hai; kernel "TAMPERED" kahe to data render nahi.
