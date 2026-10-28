# FOUNDER CODE INVENTORY + DEEP AUDIT (28 Oct 2026)
Maqsad: jo founder-code Lovable ne pehle likha, woh ek jagah, ginti ke saath, code parh kar audit. Yeh DOCUMENT hai — koi file move/delete nahi hui (move karne se file-based routes + imports toot jaate). Cutover sirf F9 mein.

## 1. Ginti (asli, grep/wc se)
| Hissa | Files | Lines | Note |
|---|---|---|---|
| src/routes/app.founder*.tsx (deck + sub-pages) | 33 | ~6215 | awam React app ke andar, /app/founder/* |
| src/routes/founder.tsx, founder_.$.tsx, founder.preview.tsx | 3 | ~ | /founder, /founder/* sirf redirect -> /app/founder/*; preview = page index |
| src/components/site/FounderBar.tsx | 1 | 272 | `?founder=1` preview strip, root layout (__root.tsx) mein HAR awam page par mount |
| src/lib/founder.ts, founder-plan.ts, founder-preview.ts | 3 | 148+119+67 | hooks (rpcOrRest), planned mailboxes, preview flag |
| server/routes/founder.ts | 1 | 333 | express Router: mailboxes/overview/ai-agents/ai-mail/provision/approve |
| server/lib/founder-gate.ts, founder-gate-core.ts, founder-gate.test.ts | 3 | 25+53+71 | /api/founder/* gate (index.ts line ~127) |
| Dusre server routers jo /api/founder/* dete hain | ~20 (admin, analytics, crm, integrations, movein, org, perf, release, revenue, security, settings, storage, glitch, billing-support, ai-credits ...) | | har ek index.ts mein `app.use("/api/founder", ...)` |
| SQL jo founder tables banate | E2, E24, E48 (founder_accounts), E102 (naya) | | tables: founder_accounts, founder_actions, founder_audit, founder_audit_sig, founder_devices |
| Naya (Rule 61): server/founder (Rust, 28 tests) + founder-web (React/Vite/Three) | ~25 | | alag, naye technology par |
Aur ~188 files mein lafz "founder" aata hai (chat, billing, auth ...) — zyadatar sirf `isFounder` check ya comment; yeh founder-code NAHI, awam code hai.

## 2. Endpoints
Frontend `/api/founder/*` ke ~46 unique endpoint call karta hai (release/*, revenue/*, org/*, movein/*, mailboxes, ai-mail, ai-agents, security/settings/perf/analytics/admin/integrations overview, support/replies, crm/state+toggle). Server mount: index.ts `app.use("/api/founder", founderGate)` PEHLE, phir har router.

## 3. Audit — khatray (parh kar, file:line ke saath)
1. **LOOPHOLE (sab se bada) — server/routes/auth.ts ~790-835:** awam `/auth/login` mein `FOUNDER_PASSWORD` env path. Agar email == FOUNDER_EMAIL aur password == env, to server (a) normal login try, (b) fail ho to **user ka password admin API se overwrite** karta hai, (c) account na ho to **createUser + founder_accounts row upsert**, (d) session de deta hai. Matlab founder login awam login se hota hai, aur ek env-password se founder identity BAN sakti hai. Fix F1a: alag login host + passkey/device approval; yeh block TAB hatega jab founder naye login se passkey proof de (warna lock-out).
2. **Teen jagah alag-alag FOUNDER_EMAILS list** (routes/founder.ts, founder-gate.ts, analytics.ts, org.ts + org-authz.ts): email-trust. Email string se founder banna — agar kisi tarah us email ka account ban jaye/badle to founder access. Naya founder sirf `founder_accounts` uid + local ES256 JWT verify.
3. **Har call par network `admin.auth.getUser(token)`** (gate + routes/founder.ts ctx): GoTrue par dependency + latency; naya Rust jwt_core local verify karta hai.
4. **Silent `safe()` fallback** (routes/founder.ts): error par khali/0 data lautata hai — founder ko jhoota "sab theek" dikh sakta hai. Rule 63: unavailable = null/`connected:false`, kabhi fake 0 nahi.
5. **Write actions bina audit:** provision, ai-mail approve, org kill-switch/impersonate, movein transition/rollback — `founder_audit` mein entry nahi. Naye `/founder/v1/action` mein hash-chain audit + reason zaroori.
6. **rpcOrRest fallback (src/lib/founder.ts):** RPC fail ho to REST par chala jata hai — alag authz path, galat error chhup jata hai.
7. **`?founder=1` preview (FounderBar + founder-preview.ts):** founder UI awam app ke ANDAR (root layout), localStorage flag se on. Founder aur awam mix. Host list mein `.lovable.app`/`localhost` bhi "founder host" hain. Sirf navigation/render hai (session mint nahi) — bada khatra nahi, magar design-level mix hai; F9 mein hatega.
8. **Founder pages awam bundle mein:** 33 route files awam JS ke saath ship hoti hain (lazy hone par bhi code awam origin se milta hai). Naya founder alag binary + alag host.
9. **/founder aur /founder/* redirect** sirf `/app/founder/*` par bhejte hain — koi auth nahi (auth aage route/API par). Theek, par F9 mein hatenge.
10. **Rust audit hashing mismatch (naya code):** server/founder/src/audit.rs hash DB v1 format (target/meta ke saath) se thoda alag hai — align karna baqi.

## 4. Mapping — purana -> naya phase
| Purana | Naya phase |
|---|---|
| app.founder.tsx deck, mailboxes, ai-mail | F4 People / Mail Desk |
| revenue*, billing, pipeline | F3 Money (Polar MRR/ARR, dunning) |
| movein, crm, calls, org | F4 People / F6 Control |
| security, safety, settings, admin, perf, analytics, integrations, glitch, storage | F5 Systems |
| launch/* (checklist, deployments, lock, qa, roadmap) | F5 Systems / F6 Control |
| ai/* (arena, automation, billing, knowledge, memory, prompts, receipts, studio) | F7+ (AI desk) — F9 se pehle faisla |
| FounderBar + founder-preview + redirects + FOUNDER_PASSWORD path + FOUNDER_EMAILS lists | F1a (login alag) -> F9 (hatana) |

## 5. Kya TOOTNA NAHI chahiye (cutover ke qawaid)
- Jab tak naya founder har page ka kaam live (Chrome mein) na dikha de, purani file na hatao (Rule 64).
- FOUNDER_PASSWORD path tab hi hatao jab founder passkey login live proof kar chuka ho — warna lock-out.
- `/api/founder/*` Bun routers cutover tak chalte rahenge; naya `/founder/v1/*` unke saath-saath.
- Har badlav: manifest-sync + verify 0 bad, Rule 28.

## 6. Agla qadam (Rule 64: ek hi phase)
E102 SQL ka re-run green -> phir sirf ek phase: founder host live Chrome mein (DNS A record `founder.anexomail.com` founder dega). Us se pehle koi naya command nahi.
