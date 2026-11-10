> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# CRM cinematic + 28 locale overlay

**Status:** READY (repo). **DONE nahi** — SQL paste, GitHub pull, live send/receive + Humza/awam proof baqi.

## CRM (tarteeb CR0–CR12)

Cinematic shell (`CrmStage`) + existing real APIs:

| CR | Surface | Wire |
|---|---|---|
| CR0 Capture | `/app/crm/leads` | `POST /api/crm/leads` |
| CR1 Memory | `/app/crm/relationships` | `GET /api/crm/memory` |
| CR2 Timeline | dashboard | `GET /api/crm/live` |
| CR3 Promises | counts → Work | `work_promises` / overdue tasks |
| CR4 Thread | Pipeline **Attach mail** | `POST /api/crm/deals/thread` — recorded thread for that address only |
| CR5 Work | Pipeline **Work** | `POST /api/crm/deals/work` |
| CR6 Health | HealthRing | recorded last touch / open threads |
| CR7 Risk | Revenue risk | silent deal, overdue, health |
| CR8 Graph | SVG from recorded edges | live graph + `crm_graph_edges` |
| CR9 Calendar | 12-day meeting gap | calendar attendees |
| CR10 Mail | no-pitch if open threads | mail rows |
| CR11 Evidence | Activity + `GET /api/crm/evidence` | append-only `crm_evidence` |
| CR12 Next | Next action | rules, not Leo |

Empty stays empty. No dummy people/deals.

## 28 languages

- `t("English")` / `<T>` + SQL `ui_copy` overlay + `awam_locale_pref`
- Future pages: wrap copy in `t()` — picker, `lang`, `dir` already global
- Missing string = English
- Founder/family English only

## Founder next

1. Supabase #4: paste `docs/cursor-work/sql/phase64_crm_locale.sql`
2. GitHub push (aap bolo)
3. Server: `git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save` + `bash /opt/anexomail-web/server/deploy-brain.sh`
