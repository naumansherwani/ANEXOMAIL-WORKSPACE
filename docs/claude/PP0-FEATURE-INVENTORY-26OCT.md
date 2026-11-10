> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# PP0 — Feature inventory + current gates (read-only audit, 26 Oct 2026 04:30 PKT)
Source: `src/lib/plan-surface.ts` (466 lines) + 175 route files in `src/routes/`. Docs-only.

## Asli architecture jo mili (zaroori)
- Polar plans sirf 4: basic/pro/business/business_pro. **"enterprise" code mein KAHIN nahi** (planRank, normalizeWorkspacePlan, platformPlan sab 4 tak).
- Personal vs Business ek **account kind** hai (onboarding), alag Polar product NAHI: Polar Basic->Personal Basic, Pro/Business->Personal Pro+, Business Pro->Personal Premium. Personal Pro+/Premium = **Business Pro power**, bas Org/Domains nahi.
- AI plan grant platform deta hai: ai_pro/ai_business->Business power, ai_executive->Business Pro power. (Founder: Business Premium AI mein nahi.)
- Conflict: `personal-tiers.ts` Personal £17/£83/£1,850 alag price likhta hai, `plan-surface.ts` Polar £23/£46/£97/£2850 se map karta hai -- ek hi sach chahiye (founder faisla).

## Maujooda gates (code ka sach) -> Business Premium ke liye kya karna
| Feature (route) | Abhi kaun | Business Premium |
|---|---|---|
| Mail, people, calendar, search, import, onboarding, settings, storage, billing, devices, move-in | Sab | Sab |
| Pro mail tools: snooze/schedule, multiple identities, full video (showProMailTools/Identities/FullVideo) | Pro+ | Haan |
| Work: boards/notes/tasks/thread analytics (`/app/work`) | Pro+ | Haan |
| CRM base: accounts/leads/pipeline/tasks/relationships/reports/health | Pro+ (Personal: Pro+) | Haan |
| CRM collab + risk (`/app/crm/collab`), Work business-record ledgers | Business+ | Haan |
| CRM activity ledger + graph (`/app/crm/activity`) | Business Pro | Haan (Business Pro se upar) |
| ANEXOChat + ANEXOVideoCall (`/app/chat`, anexochat, anexovideocall) | Business+ (Personal Pro+/Premium) | Haan, 7GB file |
| Org: members/roles/departments/policies/audit/compliance/graph (`/app/org*`) | Business kind, Business+ | Haan |
| Company domains + addresses (`/app/domains`) | Business kind (koi bhi plan) | Haan |
| Safety centre: review queue, sealed evidence, appeals (`/app/safety`) | Business Pro power | Haan |
| Security: devices/vault/sessions/proof/encryption/history (`/app/security*`) | Sab (vault count plan ke hisab) | Haan, sab se zyada |
| Analytics (`/app/analytics*`: deep-work, forecast, leaks, promises, team, threads) | **plan-surface mein gate nahi mila -- verify (PP0 part 2)** | -- |
| Admin (`/app/admin*`) / Founder (`/app/founder*`) / Perf | Sirf founder host | Nahi |
| AI (`/app/ai*`, `/ai*`) | Sirf ai.anexomail.com | Nahi (Business Premium AI nahi) |

## Business Premium = Business Pro ke SAARE features + yeh farq (PROPOSAL)
Unlimited users, 15TB shared, 100MB email attachment, ANEXOChat 7GB, overage 50TB@£10, **Priority Support add-on (£790/mo) included**, video group size 60 (Business 8 / Business Pro 40), vault devices 100. Koi naya feature invent nahi.

## Code ghaltiyan/gaps (PP2/PP5 mein)
1. Business Premium rank 5 add karna (planRank, normalize, platformPlan, featurePlan, packageCopyName, polarToPersonalTier) -- 6+ jagah.
2. `plan-surface.ts` header comment "£23/£46/£97/£2850" stale.
3. showFullVideo/ProMailTools Pro+ hain jab ke purani formula file Video ko Business+ likhti hai -- founder bataye kaun sa sahi.
4. Domains: Business kind par Basic plan bhi mil jata hai -- intended?
5. Analytics routes ka gate verify.
6. Personal tier price conflict (upar).
