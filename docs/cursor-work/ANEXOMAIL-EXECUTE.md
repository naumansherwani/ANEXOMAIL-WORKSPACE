# ANEXOMAIL — E-series = Claude F tarteeb

**Tumhari formula:** original blueprint (no-touch) + Lovable **positive** codes (preserve) + **Claude F1→F12 tarteeb** = E1→E12. Mix nahi. Original file overwrite nahi.

Polar rust payment `:3400` **E nahi** — pehle se, no-touch. `plans.ts` / landing no-touch.

---

## Stack (har E)

| Layer | Technology |
|---|---|
| Frontend | React 19.2 · TanStack Start v1 · Vite 8.2 · Tailwind 4.2 · Radix/shadcn · Bun SSR `:3000` |
| Backend PRIMARY | Rust `:3200` Tokio + WebTransport + QUIC (`/rpc` `/wt`) |
| Backend FALLBACK | Bun `:3100–3300` `/api/*` jab Rust 404/501/502/503 |
| Mail | Postfix / Dovecot / OpenDKIM — **installed**, dobara nahi |
| Pay | Polar rust payment `:3400` no-touch |

Naya kaam: pehle Rust, phir Bun fallback.

**DONE** = yeh E repo mein ban chuki (founder: build ho chuka). **TODO** = abhi nahi. E4 (send+receive live) ke baghair E5–E8 aage **nahi**.

---

## Tarteeb — Claude F = E number

```
E1  = F1   Auth
E1.2= F1.2 Shell / package rail
E2  = F2   Dashboard
E3  = F3   Inbox list
E3A = F3A  Family testers
E3B = F3B  Onboarding Personal|Business
E4  = F4   SEND + RECEIVE GATE
E5  = F5   Thread
E6  = F6   People
E7  = F7   Calendar
E8  = F8   Work
E9  = F9   Founder protocol
E10 = F10  ANEXOChat (1–31A; 32+ paste)
E11 = F11  LEO (AI-EXECUTE, baad)
E12 = F12  CRM
```

---

## Claude frontend — kab aaye (locked)

**Har phase pe naya UI/UX zaroori nahi.** Lovable screen pehle se ho to Claude usko tear nahi karta. Claude **tab** aata hai jab (1) us E ka **backend GitHub pe ho** aur (2) neeche **Claude = HAAN**.

| E = F | Claude UI/UX? | Kab / kya |
|---|---|---|
| E1 F1 Auth | **Nahi** (ab) | Auth+landing English. Naya signup look tabhi jab founder bole |
| E1.2 F1.2 Shell | **Haan** | Package rail + Zoho chrome — E4 ke baad ya founder “UI shuru” |
| E2 F2 Dashboard | **Nahi zaroori** | Greeting pehle se. Zeros E4 mail ke baad khud theek |
| E3 F3 Inbox list | **Haan** | Zoho three-panel — **E4 send/receive API ke baad** |
| E3A F3A Testers | **Nahi** | Accounts / grants. UI phase nahi |
| E3B F3B Onboarding | **Nahi zaroori** | Form pehle se. Polish sirf founder bole |
| **E4 F4 GATE** | **Pehle nahi** | **Backend pehle** (Postfix + Rust + Bun fallback). Claude compose/inbox **wire ke baad** |
| E5 F5 Thread | **Haan** | Us E ka Rust API GitHub pe ho |
| E6 F6 People | **Haan** | Wahi |
| E7 F7 Calendar | **Haan** | Wahi |
| E8 F8 Work | **Haan** | Wahi |
| E9 F9 Founder | **Baad** | `FOUNDER-EXECUTE` — mail DONE ke baad |
| E10 F10 Chat | **Nahi** (1–31A) | Shell repo mein. 32+ founder paste |
| E11 F11 LEO | **Baad** | `AI-EXECUTE` |
| E12 F12 CRM | **Nahi zaroori** (ab) | Surface repo. CR1+ E4+E6 ke baad |
| Polar | **Kabhi nahi** | Engine no-touch |

**Ab Claude: nahi.** Ab backend **E4**. Claude pehli dafa **E3+E4 screens** (Zoho inbox + compose) jab E4 API push ho.

---

## E1 = F1 Auth — DONE

Lovable keep: `auth.tsx` `server/routes/auth.ts`  
Frontend: Sign in `/auth`. Create workspace → Personal | Business → `/plans`.  
Backend: **ab** Bun `/api/auth/*`. Naya piece = Rust pehle, Bun fallback.  
SQL: phase65 no-touch; `E2_personal_polar.sql` map (purana E-number naam — yeh E1/E3B ka map).

---

## E1.2 = F1.2 Shell — DONE

Lovable keep: `AppShell.tsx` `host.ts` `plan-surface.ts` `PlanSurfaceGate.tsx`  
Frontend: package rail, URL wall.  
Backend: nahi (UI).  
Mix nahi: Leo mail host pe nahi.

---

## E2 = F2 Dashboard — DONE

Lovable keep: Greeting, tiles, `/api/dashboard/*`  
Frontend: cinematic dashboard rakhna. Leo credits **AI-only**.  
Backend: Bun dashboard aaj. Naya = Rust pehle, Bun fallback.

---

## E3 = F3 Inbox list — DONE (list only)

Lovable keep: `app.mail.*` MailRail — **rewrite nahi**  
Frontend: three-panel. Fake empty nahi. Zoho look = Claude, E4 API ke baad.  
Backend: **PRIMARY** Rust `/rpc/mail.*` `/wt/mail` · **FALLBACK** Bun `/api/mail/*`  
Send/receive **E4** hai, E3 nahi.

---

## E3A = F3A Testers — DONE (repo)

Masood Pro · Humza Business Pro · Raana AI Executive. Sign in, `/plans` nahi.  
SQL phase63 no-touch.

---

## E3B = F3B Onboarding — DONE (repo)

Personal | Business. Business → org name+domain. Personal → dashboard. Polar alag.

---

## E4 = F4 SEND + RECEIVE GATE — TODO

Compose → Postfix (installed). Bahar se → Dovecot → list.  
Backend: Rust delivery push; Bun send fallback.  
Live: `bash server/gates/mail-gate.sh` + founder dekhe.  
**Ab backend yahi.** E5–E8 wait.

---

## E5 = F5 Thread — TODO (wait E4)

Lovable: `$threadId.tsx`  
Backend: Rust reply push · Bun `/api/mail/thread/:id` fallback.

---

## E6 = F6 People — TODO (wait E4)

Lovable: people. SQL phase62 no-touch.  
Backend: Rust contacts (naya) · Bun `/api/contacts` fallback.  
Repo list-fix (no companies embed) pehle se hai.

---

## E7 = F7 Calendar — TODO (wait E4)

Lovable: calendar. SQL phase61 no-touch.  
Backend: Rust reminder `/wt` · Bun `/api/calendar/load` fallback.

---

## E8 = F8 Work — TODO (wait E4)

Lovable: `app.work.tsx`  
Backend: Rust work (naya) · Bun `/api/work/*` fallback.  
403 = honest gate.

---

## E9 = F9 Founder — TODO (wait E4; FOUNDER-EXECUTE)

Host: `founderworkspace.anexomail.com` only.  
Backend: Rust `/wt/founder` live · Bun `/api/founder/*` fallback.

---

## E10 = F10 ANEXOChat — DONE (1–31A repo) / 32+ TODO

Backend: **FULLY RUST** `/wt/chat`. Bun chat **fallback**.  
32+ sirf founder `## PHASE N` paste.

---

## E11 = F11 LEO — TODO (AI-EXECUTE, E4 ke baad)

`ai.anexomail.com`. Mail host pe Leo nahi.  
Backend: baad; naya = Rust pehle.

---

## E12 = F12 CRM — DONE (surface repo)

Lovable: `app.crm*` `crm.ts` `locale.ts`  
Backend: **PRIMARY** Rust `/rpc/crm.*` `/rpc/locale.*` · **FALLBACK** Bun `/api/crm/*` `/api/locale/*`  
SQL phase64 no-touch. CR1+ flagship = E4+E6 ke baad. Alag crm host nahi.

---

## Polar (E nahi)

`polarpayments.anexomail.com` + `anexomail.com/api/v1/polar-webhook` → `:3400`. HTTP 200. Codes no-touch.

---

## Package → UI (Claude, E4 API ke baad)

Basic / Pro / Business / Business Pro — `plans.ts` prices no-touch. Features → rail/gates Claude.

---

## Ab

Backend agent: **E4**. Claude: **ab nahi** — pehli UI E3+E4 (Zoho) jab E4 API GitHub pe ho. Har E pe UI zaroori nahi — upar wali table.
