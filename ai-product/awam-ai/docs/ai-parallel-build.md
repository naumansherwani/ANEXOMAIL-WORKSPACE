> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# ai.anexomail.com — PARALLEL BUILD MAP (locked 24 Aug 2026)

Rule: jo kuch `anexomail.com` (founder side) par ban chuka hai, wahi **same to same**
`ai.anexomail.com` (LEO product) ke andar bhi hoga — magar **awam ko nazar nahi aata**.
Awam ko sirf coming-soon + AI packages ki feature list. Ek codebase, host-aware gate.
Do repo / do design system kabhi nahi.

## 1. Surface split

| Surface | Kaun dekhta hai | Kya dikhta hai |
|---|---|---|
| `ai.anexomail.com/` | awam | AI landing + coming soon + package feature list (kharidari band) |
| `ai.anexomail.com/app/*` | sirf founder (unlock key) | poora mirror: mail, chat, video, CRM, org, billing, founder deck |
| `anexomail.com/*` | founder (pre-launch lock) | jaisa ab hai |

Gate = wahi `SiteLock` (`VITE_SITE_LOCK` + `VITE_UNLOCK_KEY`, key rotate ho chuki hai)
+ host check. AI host par gate ke bahar sirf `/` (coming soon) rehta hai.

## 2. Mirror scope (mashwara)

- **Mirror karo:** `/app/*` sab (mail, chat, video, work, CRM, org, admin, security,
  perf, settings, billing, founder deck, /pages page map).
- **Mirror NA karo:** public marketing pages (`/plans`, `/about`, `/migration`,
  `/partners`, `/move-in`, `/get-started`). Woh anexomail.com ki dukaan hai;
  AI host par sirf AI packages ki apni list.
- AI host ka `/app/*` LEO-first hota hai: har page par LEO panel + AI actions ON,
  jabke anexomail.com par wahi page AI ke bina (AI LOCK qaim).

## 3. ANEXOChat — AI package features (awam ke liye, coming soon list)

| Feature | AI Pro (1,200 cr) | AI Business (5,000 cr) | AI Executive (10,000 cr) |
|---|---|---|---|
| ANEXOChat 1-to-1 + group | ✓ | ✓ | ✓ |
| LEO thread summary (chat → 5 line) | ✓ | ✓ | ✓ |
| Auto work items (task/promise/decision) | ✓ | ✓ | ✓ |
| Smart reply / tone rewrite in chat | ✓ | ✓ | ✓ |
| Live translate (auto-detect, manual override) | — | ✓ | ✓ |
| Meeting-from-chat (calendar slot nikalna) | — | ✓ | ✓ |
| Conversation memory ledger (LEO recall) | — | ✓ | ✓ |
| Screenshot/image read (attachment se text + action) | — | ✓ | ✓ |
| Company-wide chat intelligence (risk, promise leaks) | — | — | ✓ |
| LEO Actions in chat (mail bhejo, deal update karo) | — | — | ✓ |

Credit se chalne wale actions: summary · rewrite · translate · image-read · actions.
Har action se pehle pre-flight estimate, baad mein receipt (AI CREDIT LOCK).

## 4. ANEXOVideoCall — AI package features

| Feature | AI Pro | AI Business | AI Executive |
|---|---|---|---|
| 1-to-1 call (P2P + TURN, adaptive ladder) | ✓ | ✓ | ✓ |
| Honest quality badge + telemetry | ✓ | ✓ | ✓ |
| Live captions (on-device first) | ✓ | ✓ | ✓ |
| Post-call LEO notes + action items | — | ✓ | ✓ |
| Call recording + transcript search | — | ✓ | ✓ |
| Live translated captions | — | ✓ | ✓ |
| 8K native capture (jab camera de) | — | ✓ | ✓ |
| Group calls (SFU phase) | — | ✓ | ✓ |
| Company call analytics (setup p95, relay %) | — | — | ✓ |
| LEO joins as note-taker participant | — | — | ✓ |

Sach ka rule: koi feature "8K"/"live" nahi kehta jab tak measure na ho.
Recording · transcript · captions sab credit-metered, aur consent banner lazmi.

## 5. Deploy shape (mashwara)

Same `anexomail-web` PM2 process + Caddy mein naya host block
`ai.anexomail.com` → `127.0.0.1:3000`. Alag process ki zaroorat nahi
(RAM bachta hai, ek build, ek git pull). Host-aware surface code se aata hai.

**SHIPPED (25 Aug 2026):**

- Caddy block `ai.anexomail.com` update ho gaya (`anexochat/docs/caddy-anexochat.md` §2):
  `/rpc/*` + `/wt/*` → 3200 (Rust PRIMARY) · `/api/chat/*` → 3300 (fallback) ·
  `/api/*` + `/health` → 3100 · baqi sab → 3000 (SSR mirror).
  **Pehle yeh block seedha 3100 par tha — is liye AI host par koi page hi nahi
  khulta tha. Yeh loophole band ho gaya.**
- `src/lib/host.ts`: `isAiHost()` · `isFounderHost()` · `aiPublicPathAllowed()`.
- `SiteLock` host-aware: AI host par awam ko sirf `/` milta hai; `/app/*`
  (mail · chat · ANEXOVideoCall · CRM · founder deck — Phase 1-11 sab, "NEW
  ADDED" samet) unlock key ke peeche mirror hota hai. Ek codebase, zero duplicate.

Server par lagane ka tarteeb:

```bash
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak.$(date +%s)
nano /etc/caddy/Caddyfile     # anexochat/docs/caddy-anexochat.md §2 se poori file paste
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
cd /opt/anexomail-web && git pull && bun install && bun run build:bun
pm2 restart anexomail-web
curl -s -o /dev/null -w "ai-root:%{http_code}\n" https://ai.anexomail.com/
curl -s -o /dev/null -w "ai-app:%{http_code}\n"  https://ai.anexomail.com/app/chat
```
