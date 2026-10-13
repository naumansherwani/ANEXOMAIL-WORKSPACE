# LOCKED — mail identities, hello@ auto-reply, billing@ receipt (founder, 14 Oct 2026)

Founder ne yeh khud likh kar diya (Rule 6: asli blocks). Is file mein jo likha hai woh badla nahi jata jab tak founder na kahe. Kaam ki tarteeb sirf `docs/anexomail-blueprint.md` ki list se (Rule 14); yeh file spec hai.

## 1. Inbox / UI-UX ka qaida (LOCKED)

- **Founder account** `naumansherwani.founder@anexomail.com`: UI/UX **alag** (founder ka unified, usi account ka). Public user wale UI se mix nahi.
- **Baqi company addresses** (`hello`, `moveyourbusiness`, `resolved`, `billing`, `leo`): **ek hi unified inbox**, har mail par badge ke kaun sa address.
- Public user hamesha pehli priority; tarteeb blueprint ki numbering se.

## 2. MailRail (blueprint #11) — frontend

Do sections:
- **Founder** -> sirf `naumansherwani.founder@`
- **Company** -> 5 addresses unified (`hello`, `moveyourbusiness`, `resolved`, `billing`, `leo`), badge se address dikhe

## 3. Compose "Send from" (blueprint #7)

6 choices real wire ke saath: 5 company + founder. Backend: company addresses send-from identities.

## 4. `hello@anexomail.com` auto-reply (blueprint #12) — Option C

Subject: `We received your message`

```
Hi [First Name],

We got your message and we're on it.

At ANEXOMAIL we don't use ticket numbers or queues.
A real person will reply to you within 24 hours.

Thank you for reaching out.

ANEXOMAIL Team
anexomail.com
```

- `[First Name]` = bhejne wale user ka naam (jo bhi ho).
- Ticket number nahi, queue nahi.
- Loop guard: `noreply`/`mailer-daemon`/`postmaster`/`Auto-Submitted` ko jawab nahi; apne hi addresses ko nahi.

## 5. `billing@anexomail.com` receipt (blueprint #13)

Trigger: Polar payment success -> receipt **user ke email par**. Polar engine `:3400` no-touch.

Content:
- Plan name
- Amount paid
- Date
- Next billing date
- "Your workspace is now active"
- Invoice ID

Plan card (founder ki list, jaisi di waisi):

| Plan | Monthly | Yearly |
|---|---|---|
| Basic (business) | £23 / month | £253 / user / year |
| Pro | £46 / user / month | £506 / user / year |
| Business | £97 / user / month | £970 / user / year |
| Business Pro | £2,850 / company / month | £28,500 / company / year |
| Personal Basic | £16 / month | £187 / year · 1 month free |
| Personal Pro+ | £83 / month | £913 / year · 1 month free |
| Personal Premium | £1,850 / month | £18,500 / year |

"Amount paid" receipt mein **asli charge** hona chahiye (Polar order amount), upar ka jadwal sirf plan-naam / label ke liye.

## 6. Company domains A–E (founder ki 5 hisse ki list)

| # | Hissa | Kya | Status (14 Oct, repo) |
|---|---|---|---|
| A | Database | `org_domains`, `org_addresses`, DKIM key, SQL E15 | repo mein hai; live verify baqi |
| B | Rust | domains list/verify/remove, addresses create/list, cap, `dig` | repo mein hai; live verify baqi |
| C | Server helper | cron: verified domains/addresses -> Postfix/Dovecot/DKIM | repo mein hai; live verify baqi |
| D | UI (cinematic) | 3-qadam wizard, Namecheap/GoDaddy hints, copy buttons, live green ticks, Addresses page par asli list | **NAHI BANA** (blueprint #8) |
| E | Compose + Inbox | "From" mein company address, Inbox mein address label, aane wali mail dono par | pehle live verify |

## 7. Plan-feature-wire Steps 5–8 (founder ka spec)

- **Step 5 — shared-inbox assign:** `POST /api/mail/thread/:id/assign`, body `{ "assignee": "Name" }`, khali = hata do, jawab `{ ok, thread, plan }`, Basic ko 403 `feature_not_available`, doosri org ka thread 404. UI: thread header (ThreadHeaderActions) mein Assign control, Pro+ par khula, Basic par FeatureGate chip "Shared inbox with collision guard" -> `/app/billing`. Save `useThreadAction` kind `assign`, success par `["mail"]` invalidate. Strings `t("...")`. (blueprint #18b)
- **Step 6 — thread Tasks/Notes:** `ThreadWorkPanel` (ya ThreadTasksNotes) `ThreadInsights` wali jagah, hook `work.tasks.list` / `work.notes.*`, Pro+ gate. (blueprint #18a)
- **Step 7 — thread analytics Pro+:** `server/routes/mail-compose.ts` `GET /thread/:id/insights`: `resolvePlan` -> Pro+ na ho to 403 `{error:"feature_not_available",feature:"threadAnalytics",plan}`, uske baad koi read nahi. Route Bun pe hi rahe. Frontend `app.mail.$folder.$threadId.tsx`: Basic par FeatureGate chip "Thread insight", numbers nahi, `useThreadInsights` enabled sirf Pro+. Dashboard analytics tile na chhedo. (blueprint #18)
- **Step 8 — integrations + LEO Actions:** Business+ lock, server aur UI dono. (blueprint #19)

## 8. CRM ideas (founder ne paste kiye — abhi queue mein sirf record; blueprint 30a)

Follow-up reminder (3+ din), lead temperature score, deal-stuck warning, per-person unified timeline, relationship health (Active / Thanda / Cold), per-person response pace, signature se auto facts, team-wide shared context (Business), person-level notes, duplicate identity merge, natural-language search, apne wade alag track.
