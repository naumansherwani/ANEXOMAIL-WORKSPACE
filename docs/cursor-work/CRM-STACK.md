# ANEXOMAIL CRM — flagship map (stack = Claude, naya nahi)

**Status:** READY. **DONE nahi.**

Yeh file **nayi technology nahi** likhti. Stack wahi hai jo Claude ne lock kiya:

- Constitution: `AGENTS.md` TECHNOLOGY CONSTITUTION
- Wire model: `docs/MASTER-BUILD-PLAN.md` (Rust :3200 PRIMARY, Bun :3100 fallback)
- Per-flow map: `docs/cursor-work/IMPLEMENTATION-MASTER.md` §1 + §7

CRM usi pipeline pe chalta hai. Alag server, alag framework, WebContainer, mock backend — **banned**.

---

## Claude stack (copy — touch nahi)

| Layer | Technology |
|---|---|
| Host | Hetzner only |
| Edge | Caddy — HTTPS + HTTP/3 |
| Frontend | React 19.2 · TanStack Start v1 · Router 1.17.0 · Vite 8.2 · Tailwind v4.2 · Radix + shadcn/ui · Framer Motion · GSAP · Three.js |
| SSR | Bun · Nitro bun preset · PM2 interpreter bun · :3000 |
| Backend PRIMARY | Rust :3200 — Tokio async, WebTransport, tRPC, PostgreSQL |
| Backend FALLBACK | Bun :3100–3300 |
| Emergency | Node 22 only |
| Database | Supabase / PostgreSQL |
| Mail | Postfix / Dovecot / OpenDKIM |
| Payments | Polar — Rust webhook (no-touch) |

**CRM request path (Claude coexistence, `src/lib/rpc.ts`):**  
browser → **pehle** `POST /rpc/crm.*` (Rust :3200) → 404/501/502/503 pe ` /api/crm/*` (Bun :3100) → Supabase.

Realtime mail/chat pehle se `/wt/*` Rust. CRM graph unhi recorded rows se padhta hai — naya WT channel nahi.

---

## Surfaces (Claude teen darwaze + pehle ke CRM Caddy aliases)

Claude lock: `anexomail.com` · `ai.anexomail.com` · `founderworkspace.anexomail.com`.  
`crm.anexomail.com` / `aicrm.anexomail.com` = **usi frontend :3000** ke Caddy blocks (`server/caddy/crm.Caddyfile`, `aicrm.Caddyfile`) — naya product stack nahi. Founder CRM sirf `founderworkspace` `/app/founder/crm`.

UI/UX common. Farq: `crmAiAllowed()` — plain `crm.` pe Leo panels off.

---

## Flagship A–M + 1–20 (CRM domain, Claude F-map ke upar)

Deterministic CR0–CR12 = `ANEXOMAIL-EXECUTE.md`.  
Leo A-CRM1–6 = `AI-EXECUTE.md` — `aicrm.` + `ai.` + AI plan. Workspace packages pe LEO zero.

| # | Flagship | A–M | Layer | Wire | Status |
|---|---|---|---|---|---|
| 1 | Unified Customer Memory | A | recorded | `GET /rpc/crm.memory` → `/api/crm/memory` | READY |
| 2 | Unified Relationship Timeline | G, 18 | recorded | `crm.live` timeline | READY (empty channel = empty) |
| 3 | Promise engine | C | recorded dates | `work_promises` on radar | READY / AI parse TODO |
| 4 | Relationship Health | D | recorded | health ring, no sentiment | READY |
| 5 | Revenue Risk Radar | E, 14, 16 | recorded | silent/overdue + source row | READY |
| 6 | Conversation → CRM | B | rules then AI | `POST crm.dealThread` | READY (link) / A-CRM1 TODO |
| 7 | CRM → Work | K | recorded | `POST crm.dealWork` | READY |
| 8 | CRM → Calendar | L | date math | 12-day gap rule | READY |
| 9 | CRM → Mail | M | folder/state | no-pitch if open thread | READY |
| 10 | AI Customer Memory | F | AI | A-CRM2 | TODO |
| 11 | Evidence | J | recorded | `crm.evidence` | READY |
| 12 | Autonomous agent | I | AI | A-CRM5 | TODO |
| 13 | Intelligence graph | H | recorded links | live SVG + `crm_graph_edges` | READY |
| 14–16 | Momentum / NBA / recovery | E, 15 | rules | next_actions + radar | READY (rules) |
| 17, 19 | Brief / lifecycle | — | AI | A-CRM4 / A-CRM6 | TODO |
| 18 | Multi-channel fusion | G | recorded | one timeline | READY |
| 20 | Founder command | — | founder host | `/app/founder/crm` | READY (kill switch) |

---

## SQL

`docs/cursor-work/sql/phase64_crm_locale.sql` — usi Claude DB (Supabase #4). Fail = usi file.
