# ANEXOChat original vs Implementation Master — audit (10 Sep 2026)

**Founder paste** = `anexochat/docs/anexochat-blueprint-original.md` (Sep 9 save). Aaj ka text **usi file se match**.  
**NO TOUCH:** us file, `anexochat-blueprint-original-with-added-features.md`, `docs/anexomail-blueprint.md`.  
**Prices:** `src/lib/plans.ts` jeet’ta hai — paste/blueprint ke £250 / £85 / £1000 / £2000 **nahi**.

---

## 1. Teen files — teen kaam (mix yahan se)

| File | Product | Phases |
|---|---|---|
| `docs/anexomail-blueprint.md` | **Mail** `anexomail.com` | 1–62 (8/17+ = AI skip ab) |
| `anexochat/docs/anexochat-blueprint-original.md` | **Chat** | 1–56 human, **57 = AI plans only** |
| `IMPLEMENTATION-MASTER.md` | Claude **mail** F1–F9 + compressed **C1–C8** | C-series = chat ka **duplicate short** — **dusri chat mat banao** |

Master **ANEXOChat replace nahi karta.** Mail pehle. Chat catalog = original 1–57.

---

## 2. Duplicate (ek cheez do jagah — ek hi wire)

| Topic | Original Chat | Master | Faisla |
|---|---|---|---|
| Message engine | Ph 3 | C1 | **Chat original** |
| States / typing | Ph 9 | C2–C3 | original |
| Groups | Ph 41 | C4 | original |
| Files 5GB | Ph 13–16 | C5 | original |
| Task/Promise/Decision | Ph 22–24 | C6 + mail F8 | Chat = message→work. Mail F8 = **mail thread**→task. **Do surfaces, ek kaam nahi** |
| Search/export | Ph 32–33 | C7 | original; C7 skip as separate project |
| Cinematic weather | Ph 37–40 **API-free, Open-Meteo banned** | C8 **Open-Meteo Sep 7** | **Original jeet.** Master C8 galat. |
| Device trust | Ph 19–20 | S3 + account sessions | **Ek vault.** Account list human UA (mail). Chat trust panel = same DB |
| Email↔chat | Ph 29–30 | mail F5 adjacent | Chat original; mail pe “Discuss in chat” pehle se lib |
| Leo in chat | Ph 57 | AI4 | **Ph 57 only, AI plans.** Mail compose Leo = AI host baad |
| Sidebar Chat | Ph 6 Business+ | purana F1.2 hide | **Ph 6 + package cards.** Basic/Pro **zero Chat** |
| Founder chat god-view | Ph 44–45 | F9 | Founder **end**; privacy: admin ≠ padhna |
| Polar prices | Ph 1/55/57 old £ | `plans.ts` | **plans.ts** |

**Master FLOW 11 (C1–C8) = duplicate catalog.** Implement **mat** karo alag se. Chat = original `## PHASE N`.

---

## 3. Architecture clash (paste vs constitution)

| Rule | Paste | Locked constitution |
|---|---|---|
| Realtime | WT primary + **may** Supabase Realtime | Realtime **naya nahi** jab tak founder + pehle se na ho |
| Weather | No Open-Meteo | Master C8 Open-Meteo — **ignore C8** |
| Bun | Fallback/secondary | Bun :3100–3300 fallback — match |
| tRPC | mentioned | Rust `/rpc` + WT — existing, naya tRPC stack nahi |
| AI APIs | banned core | match |

Repo: `chat-signal.ts` + SQL publication — **pehle se**. Naya Realtime product mat kholo.

---

## 4. Wire vs READY vs DONE

`docs/wire/27-blueprint-match-1-31a.md`: Phase **1–31A repo READY** (SQL + Rust rpc + `app.chat.tsx`).  
**DONE nahi** — live A→B + WT primary + mail-gate alag.

| Band | Original | Repo | Live |
|---|---|---|---|
| 1–5 foundation/RLS | spec | SQL + `chat_access` | unproven |
| 6 sidebar | Business+ tab | rail + `/app/chat` | Humza dikha; Basic hide |
| 7–12 UI/states/continuity | spec | page + lib | 1 conversation, **HTTP/3 polling** (WT nahi) |
| 13–21 files/safety/device | spec | SQL/Rust | live unproven |
| 22–31 work/bridge | spec | rpc + some UI | live unproven |
| **32–56** | spec | **TODO** (search cost leaks calm weather groups 1TB founder gate…) | nahi |
| **57** | Leo, AI plans | AI4 TODO | Coming Soon |

Humza screenshot = Ph 6+7 **surface**, Ph 2 PRIMARY **unwired** (poll). Fake Sarah/John nahi.

---

## 5. Basic/Pro (paste lock — Master se match)

- Basic / Pro: **ANEXOChat access zero** (nav, routes, API 403).
- Business / Business Pro: Ph 1–56 (limits `plans.ts` se, £250 nahi).
- AI plans: same 1–56 + Ph 57. **1–56 dobara mat banao.**

---

## 6. Kaam ki tarteeb (is audit ke baad)

1. **`anexomail-blueprint.md`** `anexomail.com` — Phase 1 shell → 5A → 7 → **9 mail-gate**.  
2. Chat **32–57 ab nahi** (mail pehle). 1–31A **naya clone nahi** — jo READY hai usi ko live proof.  
3. Master **C1–C8 hatao as build list** — pointer: original Ph 1–57.  
4. Ph 57 / AI host — anexomail complete ke baad.  
5. Founder Ph 44–45 — end.

**Shuru jumla alag:** `ANEXOMAIL Phase 1 shuru` vs `ANEXOChat Phase N shuru` (N = original heading).
