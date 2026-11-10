> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# E17 — `/claim` ko naye Rust signup RPC se wire kiya (12 Oct 2026)

Rule 14 #5/#6 ka backend hissa (Rust `account.signup.*` + SQL `trial_provision_workspace`)
live end-to-end test mein green ho gaya tha (asal auth user -> login -> address check ->
start -> claim -> organisations/mail_accounts/org_members auto-create -> Postfix sync),
lekin asal website (`src/routes/claim.tsx`) ab tak purane Bun fallback endpoints
(`/api/auth/identity/*`, `/api/workspace/*`) hi use kar rahi thi — founder ne poocha
"website pe kya change hai?" aur sahi pakda ke abhi kuch nahi tha.

## Kya badla

`src/routes/claim.tsx`:

1. **Availability check** (handle free/taken) — ab `rpcOrRest("account.signup.address", ...)`
   use karta hai (Rust pehle, Bun fallback automatic agar Rust unreachable). Yeh read-only,
   side-effect-free hai, is liye **har kind** (personal + business) ke liye unconditionally
   switch kiya — koi risk nahi.
2. **Claim step** — sirf `kind === "personal"` ke liye `/rpc/account.signup.claim` (Rust) try
   karta hai; fail ho (Rust down, koi error) to purane `/api/auth/identity/claim` (Bun) pe
   gracefully fallback karta hai — koi behavior change nahi agar Rust ka masla ho.
   `kind === "business"` (ya kind abhi chosen nahi) **bilkul nahi chhua** — woh `/onboarding`
   pe jaata hai jahan custom-domain org provisioning hoti hai, jo Rust abhi nahi karta.

## Business path kyun nahi chhua (zaroori wajah)

`trial_provision_workspace` (Rust/SQL) unconditionally ek generic "X workspace"
organisation + personal-kind mail_account bana deta hai — yeh kind-agnostic hai.
Agar claim step **har** kind ke liye Rust pe switch hota, to ek business buyer
`/onboarding` pe apna real company-domain org banata (`/api/workspace/organisations`),
aur us se PEHLE Rust claim ne already ek auto-generated personal-style org bana diya
hota — matlab do organisations, ek user, data duplication/confusion. Business flow ko
isi wajah se purane path pe chhoda gaya hai jab tak domain-wizard (#8) khud Rust mein
na ban jaye.

## `/api/workspace/personal` phir bhi kyun call hota hai (Rust claim ke baad bhi)

Rust claim ke baad `org_members` mein row already ban chuki hoti hai, is liye
`/api/workspace/personal` "existing org" fast-path leta hai (koi duplicate org/mailbox
nahi) — lekin yehi ek jagah hai jo `account_profiles.preferences.workspace_kind='personal'`
+ `onboarded=true` stamp karti hai. `server/routes/billing-sync.ts`'s
`enforceAccountKind()` isi preference ko padhta hai personal-tier billing products ke
liye — is call ko skip karna silently ek Rust-provisioned account ko apne hi plan se
lock out kar deta (bina kisi error ke, bohot baad mein pakda jaata). Is liye yeh call
hamesha chalta hai, chahe Rust claim succeed ho ya fallback.

## Verify (zaroori, deploy ke baad)

- Server pull + build + restart (Rule 1 ka standard command).
- `wip/e17-signup` branch se deploy — abhi `main` par merge nahi (founder "repo update"
  kehne par hoga).
- Live browser test: naya email+password signup -> `/claim` -> ek handle claim karo ->
  `/dashboard` khulna chahiye, koi console error nahi, `organisations`/`mail_accounts`/
  `org_members` Supabase mein confirm.
- Fallback test (optional): Rust ko temporarily down karke dekho claim abhi bhi purane
  path se chalta hai ya nahi (`rpc()` catch -> legacy claim).

**Status:** READY (repo mein, server par abhi deploy/verify nahi hui — Rule 5).
