# Blueprint supersede plan

Status: **TODO** (yeh plan hai, live proof nahi). Lovable copy-paste book (`docs/wire/00`–`27`) is plan ka process nahi.

Lovable ka scatter yahan law nahi. Law sirf blueprint + yeh tarteeb. Naya SQL, naya route, naya wire file — Phase N ke original block ke baghair nahi.

---

## 0. `host.ts` kahan chalta hai

`src/lib/host.ts` **Hetzner par alag command nahi**. Yeh frontend TypeScript hai.

- Build: `bun run build:bun` (SSR bundle, port **3000**)
- Run: browser mein, har page load par `window.location.hostname`
- Kaam: `anexomail.com` · `founderworkspace.anexomail.com` · `ai.anexomail.com` alag surfaces, **ek codebase**
- Caddy isi bundle ko HTTPS se serve karti hai. `node host.ts` / `bash host.ts` kuch nahi

---

## 1. Blueprint kahan hai (sirf yeh)

| Product | Source of truth | Layer rule |
|---|---|---|
| **ANEXOChat + VideoCall** | `anexochat/docs/anexochat-blueprint.md` | Sirf original `## PHASE N`. **NEW ADDED** tab jab file mein phase ke neeche locked ho. Founder Suggestions / Lovable / ChatGPT / Grok — us phase par paste ke baghair nahi. **32+ wait** jab tak founder original block paste na kare. |
| **ANEXOMAIL workspace phases 1–11** | Repo ke source headers (alag `anexomail-blueprint.md` **nahi mila**). Phase numbers: `src/styles.css` + `AppShell` (1) · `src/lib/ia.ts` (2) · public routes (3) · `StateBlock` (4) · `auth` (5A) · dashboard (6) · `src/lib/mail.ts` (7) · LEO mail header (8) · compose (9) · contacts (10) · `src/lib/calendar.ts` + `server/routes/calendar.ts` (11) | Founder ke paas original mail blueprint ho to **Phase 1 se paste**. Us ke baghair Phase 1 = shell files jo pehle se hain, unhe align karna — naya architecture nahi. |
| **Teen host** | `src/lib/host.ts` + `docs/ai-parallel-build.md` | Awam `anexomail.com` = mail product. `ai.anexomail.com` = wahi features + LEO, awam ko `/` coming soon. `founderworkspace.anexomail.com` = sab + owner protocol. Packages / Polar / landing logo — no-touch jab tak founder na bole. |

Stack lock (badalna nahi): Hetzner, Caddy, React 19.2, TanStack Start, Vite, Tailwind, Bun `:3000`, Rust `:3200` PRIMARY, Bun `:3100`–`:3300` fallback, Supabase truth, Postfix/Dovecot. Mock nahi. Duplicate system nahi.

---

## 2. Super-seed = Lovable ki barbadi ko theek karna, dump nahi

**Rakhna (infrastructure, phenkna nahi):** Hetzner, Caddy, PM2, Rust, Bun, Supabase, mail stack, existing `src/` + `server/` + `sql/phase52`…`59` jo live mail/auth ke liye already lage.

**Process se hataana (law nahi):**

- `docs/wire/00-steps.md` se `27` — copy-paste book, har step pe founder akela
- `.lovable/plan/*` — editor memory, blueprint nahi
- `docs/wire/28-org-calendar-contacts.md` + `sql/phase60_*` + `phase61_*` + `phase62_*` — **blueprint phase nahi**; is editor ki scatter. GitHub commits `501b697` + `3fa076d` inhein laye. Super-seed step A: inhein **revert** (naya commit, force-push nahi) jab founder bole
- Do raaste ek kaam ke (editor SQL **aur** `sql/run.sh` same patch) — band. Ek phase, ek jagah, ek paste

**Code super-seed (jagah par, duplicate folder nahi):**

- Naya tree `Anexomail Workspace Cursor work` **nahi**. `server/`, `src/`, `sql/`, `anexochat/`, `docs/` pehle se hain. Move = `cd /opt/anexomail-web && bun run build:bun` tootna
- Har feature: pehle **authoritative file** (jo pehle se hai). Missing table → usi route ke naam se **ek** SQL, drop/rename nahi
- UI pe `NotWired` / 401 / `[object Object]` / “Founder preview — no session” = contract ya session, naya page nahi
- Landing, logo, Polar packages — Lovable “theek” ke naam par touch nahi

---

## 3. Tarteeb (ek waqt ek phase)

1. **`anexomail.com` awam** — real landing (jo hai woh), real `/auth`, real mail send/receive. SiteLock/preview mix yahan product ko band na kare. **DONE** sirf mail-gate + live send/receive green
2. **Founder session** — `founderworkspace` + `founder_accounts`; awam claim/onboarding founder par nahi
3. **`ai.anexomail.com`** — awam coming soon + LEO jab product open ho
4. **ANEXOChat 1–31A** — blueprint vs repo; DONE sirf live 2-user message + call, README READY nahi
5. **ANEXOChat 32+** — sirf pasted original `## PHASE N`
6. GitHub, phir Server 2 `git pull`

Backend pehle tab jab us phase ko DB/API chahiye. Frontend UI usi phase ke existing route par. Wire = us phase ka **ek** live check (browser + API + DB). Alag 60 wire markdown files nahi.

---

## 4. Phase 1 se map (ANEXOMAIL) — code abhi is file se nahi likhna

| Phase | Blueprint naam (repo headers) | Frontend | Backend / Hetzner | SQL | Kami (super-seed) |
|---|---|---|---|---|---|
| 1 | Design + shell | `src/styles.css`, `AppShell.tsx`, `SiteNav`, `src/routes/__root.tsx`, `src/routes/index.tsx` | Caddy → `:3000` | koi phase01 mail SQL nahi, zaroori bhi nahi | Live pe founder-preview / SiteLock mix. Shell pehle se hai — naya design system nahi |
| 2 | IA | `src/lib/ia.ts` | mail folders server routes se | alag phase2.sql nahi | Map hai; DB folders mail se. Duplicate IA nahi |
| 3 | Public pages | `/about` `/security` `/auth` get-started | same SSR | nahi | Pages bikhri hain, heading nahi. Naye landing pages nahi |
| 4 | Honest states | `StateBlock.tsx`, `Skeletons.tsx`, `notify.ts` | API error shape | nahi | 401 ko empty inbox mat kaho. Session ke baghair “unauthenticated” sach hai |
| 5A | Auth | `auth.tsx`, `claim.tsx`, `onboarding.tsx` | `server/routes/auth.ts`, `create-accounts.sh` | `sql/phase59_account_lifecycle.sql` | Live login unproven. Preview bar = no session |
| 6 | Dashboard | `app.index.tsx` | `GET /api/dashboard/*` | org membership tables **live par `org_members` + `org_role` pehle se** | “No organisation yet” = session/membership, naya dashboard nahi |
| 7 | Mail core | `app.mail.*`, `src/lib/mail.ts` | `server/routes/mail.ts`, Postfix pipe | `phase52`…`58` | List/send repo mein. DONE = mail-gate + inbound/outbound proof |
| 8 | LEO delivery | `leoSupportPipeline` in `mail.ts` | founder/AI host | alag phase8.sql nahi | Awam mail se mix mat karo |
| 9 | Compose | `ComposeStudio.tsx` | `mailRouter.post("/send")`, `sendmail.ts` | outbox log | Live send unproven |
| 10 | Contacts | `app.people.tsx` | `server/routes/contacts.ts` | contacts tables repo SQL mein nahi thi | Route hai; schema live check ke baad **isi phase par** ek file, phase 62 naam se scatter nahi |
| 11 | Calendar | `app.calendar.tsx` | `server/routes/calendar.ts` | calendar tables repo SQL mein nahi thin | UI NotWired / 401. Pehle session, phir existing route ke columns live DB se match — naya calendar app nahi |

ANEXOChat Phase 1 alag cheez hai (`anexochat-blueprint.md` ## PHASE 1). Mail Phase 1 se mix nahi.

---

## 5. Kaise chalega (Lovable clone nahi)

1. Founder **Phase 1** ka original block paste kare (mail blueprint), ya bole: “Phase 1 repo headers se chalo”
2. Editor us phase ki **3 lines** likhe: frontend file, backend file, SQL (ya “SQL nahi”)
3. Founder **“likho”** bole — tab sirf wohi files
4. Founder pull + (agar SQL ho) **ek** editor paste
5. Browser proof → status READY ya TODO, DONE nahi jab tak gate green na ho
6. Phir Phase 2

Is file ke neeche naye phase ke boxes tab add honge jab woh phase chale — alag `docs/wire/29` nahi.

---

## 6. Abhi next (code nahi)

Founder Phase 1 original paste kare, ya ek line: **Phase 1 repo shell se map karo, code mat likho.**
