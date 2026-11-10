> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Personal vs Business — Polar pe naya product NAHI

**Status:** READY (repo). **DONE** nahi — pull + live look. Paise Polar landing; kind signup. SQL phase65 **no-touch**.

**Mashwara (locked):** Personal Polar cards / landing Personal section **mat banao**. Paise wahi 4 Polar SKUs se aate hain. Kind backend session pe hai.

## Do axes (mix nahi)

| Axis | Kahan | Kya hai |
|---|---|---|
| **Money** | Polar + `plans.ts` **no-touch** | Basic £23 · Pro £46 · Business £97 · Business Pro £2,850 |
| **Kind** | `account_profiles.preferences.workspace_kind` + session `account_kind` | `personal` \| `business` |

Landing wahi 4 cards. Checkout ke baad: **Create your account for workspace → Personal | Business**.

## Default (jab kind explicit na ho)

| Polar SKU | Kind | Workspace feel |
|---|---|---|
| `basic` / `pro` | personal | Masood = Personal Pro buyer |
| `business` / `business_pro` | business | Humza = Business Pro buyer |

Slug `personal-*` bhi personal. Explicit `workspace_kind` jeet’ta hai.

## Power vs presentation

**Personal Pro = Business Pro power.** Sirf use-case alag:

- Personal: Org rail **nahi**. Book = “Your book”. Team follow-through **nahi**.
- Business: Org + company chrome. Humza = shared/company book.

Premium (copy) = Polar **Business Pro** SKU + kind personal. Naya Polar ID nahi.

## Buyers (family tester UI nahi)

| Login | Polar SKU | Kind | Rail |
|---|---|---|---|
| Masood | `pro` | personal | Mail People Calendar Work CRM Chat — **Org nahi** |
| Humza | `business_pro` | business | + Org + Chat + CRM shared/activity |
| Raana | **AI Executive** (`ai_plan`) | infer from grant — **Business Pro label nahi** | mail host = included platform UX, LEO `ai.anexomail.com` |

## Files

- Session: `server/routes/auth.ts` → `user.account_kind`
- Stamp: `POST /api/workspace/personal` \| `/organisations`
- Gates: `src/lib/plan-surface.ts` (`featurePlan`, `surfaceFromSession`)
- SQL video Pro+: `docs/cursor-work/sql/phase65_account_kind.sql`

E4 mail-gate ke baghair rooms khali reh sakti hain — yeh fail nahi.
