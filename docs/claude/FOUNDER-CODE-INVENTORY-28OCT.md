# Founder code ki inventory (repo-wide) — 28 Oct 2026, 05:10 PKT
Founder ka hukm (28 Oct 04:36): "puray repo se founder ke codes talash kero; Lovable ne likhe thay, sab mix, dirt hai; maqsad founder ko new technology par banana; command center se puri website chalni hai, awam ke masle yahin se sune jayen. Seriously fix karo." Yeh file ginti + sach hai (grep/CSV se nikali), koi andaza nahi.

## 1. Frontend (React/TanStack) — 36 route files, 6,541 lines
| Group | Files (lines) | Halat |
|---|---|---|
| Home `app.founder` | 343 + libs founder.ts 148, founder-plan.ts 119, FounderBar 272 | Bun `founder.ts` (6 endpoint, sab BUN-ONLY) |
| Org / People | org 215 | Bun org.ts (4) |
| Money | revenue 115, revenue_.pipeline 141, billing 186 | revenue: Rust `founder.revenue.pipeline` (b5); baqi Bun |
| Analytics / Perf / Admin | analytics 76, perf 80, admin 89 | admin 11 + perf 9 endpoint BUN-ONLY; analytics Rust `founderAnalytics.overview` |
| Security / Settings / Integrations / Safety | 76 / 96 / 108 / 41 | Rust `founderSecurity/Settings/Integrations.overview` (setx) |
| Launch (7 pages) | launch* ~920 | Rust `founder.release.*` (b5) |
| Move-in | movein 374 | Rust `founder.movein.cockpit/deal` (b5), baqi Bun (16 endpoint) |
| Misc | motion 251, calls 163, crm 214, preview 304 | calls/motion sirf device ke asli samples; preview mein lorem/TODO |
| **AI (10 pages, ~2,814 lines)** | arena, automation, billing, index, knowledge, memory, prompts, receipts, studio, ai | **Rule 23: ai.anexomail.com band — in par KOI kaam nahi** |
Libs (founder se jude): movein.ts 317, release.ts 453, perf.ts 178, revenue.ts 250, admin-center.ts 260.

## 2. Backend
- **Bun (fallback):** founder.ts 333, founder-gate*.ts 149, plus admin/perf/movein/release/revenue/glitch/billing-support/org/storage wale founder endpoints.
- **Endpoint map (ENDPOINT-PACKAGE-MAP.csv, starts_at=founder): 77 endpoint = 53 BUN-ONLY + 24 RUST-FIRST.** Bun-only bade hissay: movein 16, release 13, admin 11, perf 9, founder 6, glitch 4, org 4.
- **Rust (server/rust):** b5_glue/b5_core (founder.brain.command, release.*, movein.*, revenue.pipeline), setx (founderSettings/Security/Integrations.overview), analytics_glue (founderAnalytics.overview), main.rs `founder.expiry.watch`.
- **Gate:** `founder-gate.ts` (har /api/founder/* par ek darwaza, 401/403, tested) — theek hai. Rust side founder gate bhi `founder_accounts`/email list.
- **SQL:** founder_accounts (E2 etc.), identity E70–E72, E76 test registry. **`founder_audit` table, break-glass table: repo mein hain hi nahi.** `server/founder/` Rust crate: hai hi nahi (F1 shuru nahi hua).

## 3. Lovable ka dirt — jo asli mila (verified)
1. `src/lib/host.ts` `isFounderHost()` aur `FounderBar.tsx`: founder surface `localhost`, `127.0.0.1`, **`*.lovable.app`, `*.lovableproject.com`** par bhi khulta hai (client-side guard). Production ke liye sirf `founderworkspace.anexomail.com` hona chahiye. (Server gate asli hifazat hai, par yeh guard dhokha hai.)
2. `src/lib/pwa.ts` mein 3 Lovable hosts ki list; `vite.config.ts` + `package.json`: `@lovable.dev/vite-tanstack-config` 2.26.5 (build config Lovable ka wrapper). Rule 4: vite.config/package.json NO-TOUCH => sirf founder ke "haan" par badlega.
3. **`server/routes/auth.ts:790-797` — `FOUNDER_PASSWORD` plain compare (`password === founderPassword`), aur match par account ka password UPDATE ya account CREATE kar deta hai, public login route par.** Constant-time nahi, rate-limit/passkey ke baghair. Plan (§2 auth) is ko passkey+device+IP allowlist se badalta hai (A5). Yeh sab se zaroori security item hai.
4. Founder pages ka bada hissa 4 alag kalam (Bun REST-first `rpcOrRest`) par; founder-stack-audit: rust-first 181, rust-only 0, bun-only 19 (Rule 22 ke khilaf).
5. Achi khabar: "mock/fake/sample" flags check kiye — zyadatar sirf comments ya "asli samples" wali copy; **nakli data wale pages nahi mile** (no-mock rule bachta raha). `founder.preview.tsx` (304 lines) mein lorem/TODO hai (visitor preview).

## 4. Plan kya kehta hai (FOUNDER-WORKSPACE-PLAN.md + TECH-STACK-BEAST, LOCKED)
React 19.2/Vite 8.2/TanStack/Tailwind 4.2/shadcn/Three.js(WebGPU)/Motion+GSAP **build-time par -> static SPA -> akela Rust binary serve karta hai** (founder host par na Node na Bun) + Rust live push (WebTransport/SSE) + WASM kernel (audit hash-chain verify). Privacy: **metadata-only** (mail/file content KABHI nahi). Do-tap + reason + `founder_audit` (hash-chained). Phases F0 design -> F1 foundation (crate, auth passkey+IP+device, audit, command bar) -> F2 Bridge/Command Center (`founder.brain.command`) -> F3 Money+Release -> F4 People (global user/org 360, abuse, actions) -> F5 Mail Desk (awam ke masle yahin) -> F6 Systems+Move-In -> F7 3D -> F8 Control+AI -> F9 cutover (purane React founder pages band).

## 5. Gap (plan vs maujooda)
- F0..F9: **kuch bhi nahi bana** (sirf B5 ke Rust procs + purane Lovable pages).
- Command Center (puri website yahin se): global People/Abuse board, Mail Desk (awam ke masle sunna), Systems health, Control (kill switch/flags), `founder_audit` — sab TODO.
- Founder se baqi faisle (plan §8): login (passkey+device, password bhi?), Bridge par pehle kya (paisa ya "kya bigad raha hai"), Mail Desk ke inbox.
