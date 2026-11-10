> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Aap sirf yeh — E-series (investor pressure)

**Aap akela product nahi bana rahe.** Agent code likhta hai + GitHub. Aap **teen kaam**: paste · dekho · green/red bolo.

Packages alag apps **nahi**. Ek website. Test ke liye teen login:

| Login | Package | Investor ko dikhao |
|---|---|---|
| Masood | **Personal Pro** (Polar `pro`) | Mail People Calendar Work CRM Chat — Org nahi. Buyer, tester nahi |
| Humza | **Business Pro** | + Org + Chat + CRM Shared + Activity. Buyer |
| Raana | **AI Executive** | Mail UX included platform. Label AI Executive — Business Pro nahi. LEO AI host |

Aap Polar pe Personal product **mat** add karo. Kind backend pe hai.

Aap architecture mat socho. Har E pe agent kehte: yeh command chalao.

---

## Aapke teen kaam (hamesha yahi)

**1. Server — ek block paste** (vim khule to `:wq`)

```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```

**2. Jab agent bole — mail (E4)**

```bash
cd /opt/anexomail-web && bash server/mail/deploy-mail.sh && bash server/gates/mail-gate.sh
```

Output yahan paste (password **mat**). GREEN/RED.

**3. Browser** — Masood / Humza kholo. Jo tootay: screenshot. Jo theek: **green**.

SQL tabhi jab agent file ka naam de (`docs/cursor-work/sql/…`) → Supabase #4 paste → Run.

Phase 60s SQL (`phase60`–`phase65`) **no-touch** — dubara paste mat. Agla SQL tabhi jab agent **E-series** file de (`docs/cursor-work/sql/E….sql`).

Masood **Invalid login credentials** = `.env` mein `MASOOD_PASSWORD` missing/galat. Password chat/GitHub mein **mat**. `bash server/accounts/create-accounts.sh` dubara.

---

## Tarteeb (aap skip mat karna)

E1 rail → E1A CRM → E2 session → E3 inbox → **E4 mail jaani+aani** → phir E5–E8.

E4 ke baghair rooms khali rehengi. Yeh fail nahi — mail pipe baaki.

**DONE** sirf aap **live green** bolo. Agent “working” nahi kahega.
