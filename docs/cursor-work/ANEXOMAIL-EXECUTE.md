# ANEXOMAIL — E-series (clean execute)

Yahi implement file hai. **Original blueprint overwrite nahi.**

**Formula (mix nahi — ek tarteeb):**
`docs/anexomail-blueprint.md` (catalog, no-touch)
\+ Lovable se **positive** files (phenko mat, mix gate)
\+ Claude **F1→F9** mail order
= **E1…E8** yahan.

ANEXOChat 32+ / AI phases / founder deck **is list mein nahi.** Polar rust payment **E nahi** — pehle se `:3400`, no-touch.

**Teen kitab:** (1) yeh file = mail `anexomail.com` (2) `AI-EXECUTE.md` baad (3) `FOUNDER-EXECUTE.md` end.

---

## Status words

| Word | Matlab |
|---|---|
| **DONE** | Wire + founder live (browser + API + DB). Mail = `mail-gate.sh` green. |
| **READY** | GitHub pe hai. Server pull / live proof nahi. |
| **TODO** | Abhi nahi. |

PARTIAL / “almost” **nahi**. DONE se pehle agli E start **nahi**. E4 DONE ke baghair E5–E8 DONE **nahi**.

---

## Stack (har E — naya architecture nahi)

| Layer | Technology |
|---|---|
| Host | Hetzner |
| Edge | Caddy HTTPS + HTTP/3 |
| **Frontend** | React 19.2 · TanStack Start v1 (router 1.17.0) · Vite 8.2 · Tailwind 4.2 · Radix/shadcn · Framer/GSAP/Three |
| Frontend run | Bun Nitro SSR `:3000` — **backend nahi** |
| **Backend PRIMARY** | Rust `:3200` — async **Tokio** + **WebTransport** + **QUIC** (`/rpc/*` + `/wt/*`) |
| **Backend FALLBACK** | Bun `:3100–3300` `/api/*` — **sirf** jab Rust 404/501/502/503 |
| DB | Supabase / PostgreSQL |
| Mail (installed) | Postfix / Dovecot / OpenDKIM — dobara install **nahi** |
| Pay | Polar rust payment PM2 `:3400` — **no-touch** |

**Naya phase:** pehle Rust, phir usi kaam ka Bun fallback. Naya Bun-primary **nahi**.  
**Claude:** UI (package features → rail/gates/Zoho mail look) jab API GitHub pe ho.  
**Backend agent:** Rust + mail wire. `plans.ts` prices / landing / Polar **no-touch**.

---

## Tarteeb (number)

```
E1 package rail
  E1A CRM surface + 28 locales
E2 account / session / Personal Polar map
E3 inbox KEEP (list — rewrite nahi)
E4 SEND + RECEIVE GATE
E5 thread
E6 people
E7 calendar
E8 work
→ STOP mail user-complete
→ AI host (AI-EXECUTE)
→ founder (FOUNDER-EXECUTE)
```

---

## E1 — package rail

| | |
|---|---|
| Claude | F1.2 |
| Original | Phase 1 shell |
| Lovable keep | `AppShell.tsx` `host.ts` `plan-surface.ts` `PlanSurfaceGate.tsx` |
| Frontend | React / TanStack / AppShell / gates. Cards = Basic→Pro→Business→Business Pro |
| Backend | Rail frontend. Naya API yahan nahi |
| **Repo** | **READY** — package rail, kind chrome, wall on URL |
| **Live** | **DONE nahi** — founder ne har package rail live close nahi ki |

**Mix hatao:** Leo mail host pe nahi. Landing / `plans.ts` no-touch. Naam chip sirf avatar.

---

## E1A — CRM surface + 28 locales (E1 ki subphase)

| | |
|---|---|
| Claude | F12 + locales |
| Original | CRM + i18n (mail mix nahi) |
| Lovable keep | `app.crm*` `src/i18n` `server/routes/crm.ts` `server/routes/locale.ts` |
| SQL | `phase64_crm_locale.sql` — **already run, no-touch** |
| Frontend | CRM nav / `t()` / picker **login ke baad** workspace header. Auth+landing English |
| Backend | **PRIMARY** Rust `/rpc/crm.*` `/rpc/locale.*` · **FALLBACK** Bun `/api/crm/*` `/api/locale/*` |
| **Repo** | **READY** |
| **Live** | **DONE nahi** |

Flagship CRM (timeline, graph, CR1+) = E4 + E6 ke baad. Alag `crm.` host **nahi**.

---

## E2 — account / session / Personal Polar

| | |
|---|---|
| Claude | F1 |
| Original | Phase 5A auth |
| Lovable keep | `auth.tsx` `server/routes/auth.ts` |
| SQL | `phase65_account_kind.sql` no-touch (run). `E2_personal_polar.sql` map (+ `chat_access` file mein hai — dubara paste mat bolo) |
| Frontend | Sign in `/auth`. Create workspace → Personal \| Business → `/plans`. Get started → `/plans` |
| Backend | **Ab session Bun** (`/api/auth/*`). Naya auth piece = pehle Rust, phir Bun fallback. Polar engine **nahi** |
| **Repo** | **READY** — kind, checkout land, Personal map |
| **Live** | **DONE nahi** — login chalta; har path founder-close nahi |

Masood / Humza / Raana = Sign in, `/plans` nahi.

---

## E3 — inbox KEEP

| | |
|---|---|
| Claude | F3 |
| Original | Phase 2 + 7 mail |
| Lovable keep | `app.mail.*` MailRail `ia.ts` — **rewrite nahi** |
| Frontend | Three-panel. Empty = khali, fake nahi. Zoho look = Claude, API ke baad |
| Backend | **PRIMARY** Rust `/rpc/mail.*` + `/wt/mail` · **FALLBACK** Bun `/api/mail/*` |
| **Repo** | **READY** — list/counts |
| **Live** | **DONE nahi** — send/receive proof E4 |

---

## E4 — SEND + RECEIVE GATE

| | |
|---|---|
| Claude | F4 |
| Original | Phase 9 + 52–58 |
| Lovable keep | `ComposeStudio` send path — Leo compose se **mail host pe nahi** |
| Frontend | Compose → asli send. Inbox → asli receive |
| Backend | SMTP = **Postfix (installed)**. Rust = delivery push sent→delivered→read. Bun `/api/mail/send` **fallback** |
| **Repo** | **TODO** — wire baaki |
| **Live** | **TODO** — `bash server/gates/mail-gate.sh` + founder dekhe |

E5–E8 yahan **rukte** hain.

---

## E5 — thread

| | |
|---|---|
| Claude | F5 |
| Original | thread |
| Lovable keep | `$threadId.tsx` |
| Frontend | Thread view |
| Backend | **PRIMARY** Rust inline reply push · **FALLBACK** Bun `GET /api/mail/thread/:id` |
| Status | **TODO** — wait E4 **DONE** |

---

## E6 — people

| | |
|---|---|
| Claude | F6 |
| Original | Phase 10 |
| Lovable keep | people UI |
| SQL | `phase62` — **already run, no-touch** |
| Frontend | People list (embed companies **nahi** — PostgREST cache toot’ti thi) |
| Backend | **PRIMARY** Rust contacts (naya wire) · **FALLBACK** Bun `/api/contacts` |
| Status | **TODO** — wait E4 **DONE**. Repo pe list-fix **READY**, live mailbox nahi |

---

## E7 — calendar

| | |
|---|---|
| Claude | F7 |
| Original | Phase 11 |
| Lovable keep | calendar |
| SQL | `phase61` — **already run, no-touch** |
| Frontend | Calendar |
| Backend | **PRIMARY** Rust 5min reminder `/wt` · **FALLBACK** Bun `/api/calendar/load` |
| Status | **TODO** — wait E4 **DONE** |

---

## E8 — work

| | |
|---|---|
| Claude | F8 |
| Original | work |
| Lovable keep | `app.work.tsx` |
| Frontend | Work. Chat ledger 403 = honest gate, empty lie nahi |
| Backend | **PRIMARY** Rust work (naya) · **FALLBACK** Bun `/api/work/*`. Chat ledgers = `chat_access` (Rust chat) |
| Status | **TODO** — wait E4 **DONE** |

---

## Polar (E-series nahi)

| | |
|---|---|
| Engine | `polar-rust-payment` PM2 `:3400` HTTP 200 |
| PRIMARY URL | `https://polarpayments.anexomail.com/api/v1/polar-webhook` |
| BACKUP | `https://anexomail.com/api/v1/polar-webhook` |
| Codes | `server/rust/polar-payment/` **no-touch** |
| Cards | `src/lib/plans.ts` **no-touch**. Features → UI = Claude, prices nahi |

`checkout.created` / `updated` **200** = engine ne event li. Woh pay-katna nahi.

---

## Package → UI (Claude, API ke baad)

| Polar SKU | Kind default | Rail (cards se — prices no-touch) |
|---|---|---|
| Basic £23 | personal | Dashboard Mail People Calendar Work. Chat/full CRM nahi |
| Pro £46 | personal | Personal Pro = Business Pro **power**, Org nahi |
| Business £97 | business | + Org + Chat + CRM shared |
| Business Pro £2850 | business | + CRM activity |

Same AppShell. `ai.anexomail.com` = wahi UI + LEO baad. Vercel **nahi**.

---

## Skip is execute se (original mein hain)

| Original | Kahan |
|---|---|
| Ph 8, 17–22, 31 AI | `AI-EXECUTE.md` |
| Ph 25, 27 Admin/Speed | `FOUNDER-EXECUTE.md` |
| Ph 3 landing | no-touch |
| Ph 32–51 Polar/trial spine | no-touch |
| Chat 1–31A | repo mein; 32+ founder paste |
| Ph 6 dashboard Greeting | rakhna; Leo credits AI-only |

---

## 28 locales (Hebrew / Swahili nahi)

Picker **login ke baad**. Auth + landing English. `t("English")`. Argos = build, product nahi.

---

## Ab kaunsi E

**Backend agent ab:** **E4** — Postfix/Dovecot jo installed hai us se send+receive wire, Rust pehle, Bun fallback.

**Claude:** E4 API GitHub pe aane ke baad UI (Zoho mail look + package gates). Abhi fake inbox **nahi**.

**SQL:** phase60–65 no-touch. Naya = `docs/cursor-work/sql/E<n>_….sql` only.
