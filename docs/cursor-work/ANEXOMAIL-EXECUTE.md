# ANEXOMAIL.COM — EXECUTE BLUEPRINT
# Yeh file implement hogi. Original + Claude merge. Protected files no-touch.

**Original catalog (no-touch):** `docs/anexomail-blueprint.md`  
**Claude order:** F1 → F9 (mail only) — teesri kitab nahi, **yahi tarteeb**  
**Lovable:** files rakhna, mix rail/AI/Chat dump **gate**  
**Lovable PRESERVE (locked):** existing `src/` `server/` `sql/` phenko mat. Mix (AI/Chat/CRM/Speed/naam-chip mail pe) **gate/alag**. Phir **usi** code ko theek karke implement — naya clone / shuru se rewrite nahi.

**Inbox:** pehle se bani — **shuru se rewrite nahi** (tootegi)

**Founder rule:** yeh file TODO board nahi. Product TODO se nahi chalti. Har E: wire + live test, ya abhi start nahi. Blank UI nahi.

## GATE (locked — PARTIAL se agla nahi)

Har E sirf **not live** ya **DONE**.  
**DONE** = wire + founder/live test (browser + API + DB).  
DONE se pehle **agli E start nahi.**  
PARTIAL / “almost” / “local only” = **not live**.

**NO TOUCH:** `plans.ts` · Polar · landing · `BrandMark` SVG · ANEXOChat original blueprints

**Teen execute (mix nahi):**
1. Yeh file — mail `anexomail.com`
2. `docs/cursor-work/AI-EXECUTE.md` — baad, same UX + AI add
3. `docs/cursor-work/FOUNDER-EXECUTE.md` — end

**Packages (locked cards — implement existing, prices no-touch):**
| Plan | Price | Rail on anexomail.com |
|---|---|---|
| Basic | £23 / user / month | Dashboard, Mail, People, Calendar |
| Pro | £46 / user / month | + Work (templates, schedule send) |
| Business | £97 / user / month | + Org + ANEXOChat |
| Business Pro | £2,850 / company / month | + Org + ANEXOChat Business Pro |
Workspace cards = **LEO zero**. AI grant includes platform (AI Exec → Biz Pro UX) but Leo only on `ai.anexomail.com`.

---

## Root (sensible)

Ek codebase. Ab sirf **anexomail.com** user complete.  
`ai.anexomail.com` = baad mein **wahi UX** + AI phases add. Naya clone nahi.  
Founder deck = end. Founder **guard** (family Admin/Speed nahi) ab.

**ANEXOChat is execute list mein nahi.** Code repo mein rehti hai; Basic/Pro pe dikhe nahi. Business+ pe rail + existing `/app/chat`. Is blueprint ka kaam mail hai — Chat 1–57 rebuild nahi.

Wire = har E-step: UI dikhe + API + DB. Mock nahi. DONE = live proof.

```
E1 package rail → E2 auth/session → E3 inbox KEEP → E4 SEND/RECEIVE GATE
→ E5 thread → E6 people → E7 calendar → E8 work
→ [STOP mail complete]
→ AI host add (original 8, 17…)
→ founder
```

---

## Execute order (Claude) = original phase = Lovable file

| E | Claude | Original | Lovable (keep, wire) | Mix hatao | Status |
|---|---|---|---|---|---|
| **E1** | F1.2 | Ph 1 shell | `AppShell.tsx` `host.ts` `plan-surface.ts` `PlanSurfaceGate.tsx` | Package rail = cards. Naam chip **sirf** right avatar. CRM/Speed/AI dump. Landing / `plans.ts` no-touch | **READY** — repo. **DONE** after pull + live: Basic vs Pro vs Business rail, no Leo on anexomail.com |
| **E2** | F1 | Ph 5A auth | `auth.tsx` `server/routes/auth.ts` | `workspace_plan` sach. Sessions = Chrome·Windows, Bun dump nahi | **not live** — login hai, plan/sessions live test nahi |
| **E3** | F3 | Ph 2 + **7** mail | `ia.ts` `app.mail.*` `MailRail` | Folders pane. Inbox zero honest. Rewrite nahi | list live; DONE tab E3 verify + E1 live close |
| **E4** | **F4 GATE** | Ph 9 + 52–58 | `ComposeStudio` `sendmail.ts` Postfix | Leo compose se **nikaal** (mail host). Send+receive | **not live** — E1–E3 DONE ke baad |
| **E5** | F5 | thread | `$threadId.tsx` | — | wait E4 DONE |
| **E6** | F6 | Ph 10 | `people` SQL62 | — | wait E4 DONE |
| **E7** | F7 | Ph 11 | `calendar` SQL61 | — | wait E4 DONE |
| **E8** | F8 | work | `app.work.tsx` | — | wait E4 DONE |

**Skip ab (original mein hain, execute nahi):**  
Ph **8, 17–22, 31** = AI → `ai.anexomail.com` baad  
Ph **25, 27** Admin/Speed → founder end  
Ph **3** landing polish → no-touch  
Ph **32–51** Polar/trial → no-touch (spine)  
Ph 6 dashboard = **rakhna** (Greeting), Leo credits panel AI-only  
Ph 4 honest states = har E ke saath (`PlanSurfaceGate`)  
Ph 23 settings/account = E2 ke saath (profile right)

---

## Rail is track pe (anexomail.com)

| Plan | Dikhe | Chat/AI/Founder |
|---|---|---|
| Basic | Dashboard Mail People Calendar | nahi |
| Pro | + Work | nahi |
| Business / Biz Pro | + Org + Chat (nav; Chat 1–57 rebuild nahi) | AI nahi |
| AI Exec (Raana) | Biz Pro mail UX; Leo **baad** AI host | founder nahi |

URL se Chat/Work/Org/AI kholne par blank nahi — package wall (`PlanSurfaceGate`).

---

## E4 — agla asli kaam (inbox + E1 live ke baad)

1. Compose se mail bahar (Postfix)  
2. Bahar se aaye → list (E3 pehle se)  
3. `bash server/gates/mail-gate.sh` green + founder live dekhe  

Us ke baghair E5–E8 DONE nahi.

---

## AI baad (same site, add only)

Jab E4 green + E5–E8 user-complete:  
`ai.anexomail.com` = same AppShell/mail. Add original **8 → 17 → 18 → …** tarteeb se. Duplicate mail app nahi.

---

## Execute shuru

Agent: **is file ke E-number se.** Original `docs/anexomail-blueprint.md` overwrite nahi.  
Ab: **E1 live** (push/pull — package rail) phir **E2 session** phir **E4 mail-gate**.
