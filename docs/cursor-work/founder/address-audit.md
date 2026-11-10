> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Founder + company addresses — audit (10 Sep 2026)

**Jeet’ti list:** `sql/phase56_mailbox_final.sql` + `src/lib/founder-plan.ts` + `docs/wire/20-final-addresses.md`  
**Purani list (mix):** blueprint §13 + `anexomail inboxes to build/README.md` — `nauman@` / `support@` / `trials@` **delete** ho chuke.

Passwords is file mein nahi.

---

## Seedha jawab — founder ke kitne email?

| Sawal | Ginti | Address |
|---|---|---|
| Founder **login + asl inbox** (anexomail.com) | **1** | `naumansherwani.founder@anexomail.com` |
| Founder chhota alias | **0 zinda** | `nauman@anexomail.com` — phase56 **DELETE** |
| Parent-company founder login (code allowlist, **public site nahi**) | **1** | `naumansherwani.founder@nexatect.com` (`server/routes/founder.ts`, `server/routes/ai.ts`) |
| Company mail jo founder inbox mein **copy** hoti hai (alag login nahi) | **5** | `hello@` `moveyourbusiness@` `resolved@` `billing@` `leo@` |
| RFC forward (inbox/password nahi → `resolved@`) | **3** | `postmaster@` `abuse@` `dmarc@` |
| Send-only (founder login nahi) | **1** | `noreply@` |
| Family — **founder nahi** | **3** | Humza, Raana, Masood |

**Nauman product pe login kare:** `naumansherwani.founder@anexomail.com` → `founderworkspace.anexomail.com`.  
**Doosra founder “account” mat banao.** Alias `nauman@` wapas mat lao jab tak founder naya phase na bole.

---

## A) anexomail.com — LIVE TARGET (phase56)

### Real mailbox (Dovecot login possible)

| Address | Role | Founder? |
|---|---|---|
| `naumansherwani.founder@anexomail.com` | Founder primary — **ek hi** inbox | HAAN |
| `hello@anexomail.com` | First contact / sales (public footer) | copy → founder |
| `moveyourbusiness@anexomail.com` | Move-In leads | copy → founder |
| `resolved@anexomail.com` | Support asli inbox | copy → founder |
| `billing@anexomail.com` | Invoices / plan | copy → founder |
| `leo@anexomail.com` | LEO reply pipeline | copy → founder |
| `humzasherwani@anexomail.com` | Brother — aam, Business Pro | NAHI |
| `raanasherwani@anexomail.com` | Mother — aam, AI Executive | NAHI |
| `masoodsherwani@anexomail.com` | Father — aam, Pro (F3 A add) | NAHI |

`noreply@anexomail.com` — send-only, inbound discard.

### Forward only

`postmaster@` · `abuse@` · `dmarc@` → `resolved@`.

### DELETE (blueprint mein ab bhi likhe — zinda nahi)

`nauman@` · `support@` · `trials@`

---

## B) Blueprint §13 vs phase56 (mix yahan)

Blueprint ab bhi 13 lines: `support@`→hello, `trials@` mailbox, `dmarc@` mailbox, `nauman@` alias.  
**Phase56 jeet’ta hai.** Blueprint append-only hai — overwrite nahi. Agent wire phase56 se.

---

## C) Family ≠ founder

| Email | Plan (F3 A) |
|---|---|
| `masoodsherwani@anexomail.com` | Pro |
| `humzasherwani@anexomail.com` | Business Pro (AI nahi) |
| `raanasherwani@anexomail.com` | AI Executive grant |

Unki mail founder inbox mein **copy nahi**.

---

## D) Parent org (internal only — public copy / UI nahi)

`anexomail inboxes to build/README.md` section D: parent domain founder + agents.  
ANEXOMAIL awam product inhein **nahi** dikhata. Mix: inhein anexomail.com rail pe mat lao.

---

## E) Recovery (server only)

`founder_inbox_config` recovery mailbox Gmail — repo chat mein password nahi. SQL comments: `docs/wire/19-founder-single-inbox.md`.
