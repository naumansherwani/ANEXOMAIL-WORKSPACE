# F3 B — Awam onboarding polish (Lovable mistakes → trust)

**Date:** 10 Sep 2026  
**Founder:** Muhammad Nauman Sherwani  
**Status:** READY (repo). **DONE** nahi — live proof: Humza/family → inbox; Business → org name only; Create workspace → plans.  
**Mix ban:** founder protocol / `founderworkspace` / AI host org wizard — **is phase mein nahi**.

---

## Goal (kyun bana rahe hain)

Login tak aa gaye — ab **pehli 60 seconds** strong karni hain. Lovable ne awam pe company/domain/owner-email phenk diya; isse product trust toot’ti hai.  
**F3 B** = polish + seedha flow. Mail send/receive **F4** (gate alag). Landing visual redesign **nahi** (no-touch); auth + onboarding + workspace API.

---

## Locked product map

| Host | Role |
|---|---|
| `anexomail.com` | Mail home — Plan → Polar → Account → Personal\|Business → Mail |
| `ai.anexomail.com` | LEO only — **no** org/domain/claim wizard; awam Coming Soon |
| `founderworkspace…` | Founder only — awam onboarding **kabhi nahi** |

**Public copy:** NEXATECT **kabhi nahi**.

**Packages (`anexomail.com`):** Basic · Pro · Business · Business Pro  
(+ AI Executive → LEO jab `ai.` open ho — alag surface)

---

## Frozen flow (ek ek line)

1. User `anexomail.com` kholta hai.  
2. **Sign in** → `/auth` (email + password / passkey).  
3. **Get started** → `/plans` (Basic / Pro / Business / Business Pro).  
4. Card → Polar → payment.  
5. Payment OK → create account.  
6. **Personal | Business** choose.  
7. **Personal** → silent workspace → Mail (org/domain/invite **nahi**).  
8. **Business** → organisation **name only** → optional people → Mail.  
9. Domain = Ownership Center **baad** (pehle din nahi).  
10. Owner email / “billing and domain sit here” **print nahi**.  
11. Mailbox = identity; handle = local part; claim force **nahi** jab `@anexomail.com` pehle se.  
12. Login pe “Create a workspace” → **pehle `/plans`** (free workspace nahi).  
13. Family → default Personal feel / pehle se org ho to seedha `/app`.  
14. `ai.anexomail.com` → LEO / Coming Soon — duplicate onboarding nahi.

**Ek jumla:** Plan → Polar → Account → Personal|Business → Mail. Domain kabhi day-1 nahi.

---

## Wire checklist (is phase)

| Item | Status |
|---|---|
| Session: `@anexomail.com` → `anexomail_address`; ops org → skip claim/onboarding | READY |
| Auth copy: Email (not Work email); Create workspace → `/plans` | READY |
| Onboarding: Personal \| Business; Business name-only; no domain/owner print | READY |
| `POST /api/workspace/organisations` → live `organisations` (slug, no shared domain) | READY |
| `POST /api/workspace/personal` → silent workspace + onboarded | READY |
| Founder still seedha `/app` | READY |
| Dual workspace ban: hosted awam = **ek** operational org; `PATCH active-organisation` live | READY |
| Login awam → `/app/mail/inbox` (blank dashboard daba nahi) | READY |
| Hosted mail: "Domain not verified" → "ANEXOMAIL hosted" | READY |
| Analytics: `delivered` column missing → select without it | READY |
| `isPublicMailHost` GitHub pe (build MISSING_EXPORT fix) | READY |
| Awam rail: no Today/CRM/Org/Work/AI/Speed/Admin/Founder; **no Leo credits panel** | READY |
| F4 mail send/receive | TODO (gate) |

---

## Proof → DONE

- Incognito: Humza login → **inbox** (claim/org force nahi)  
- Business path: org name create **green** (no `operational_membership_failed`)  
- Login “Create a workspace” → `/plans`  
- Public UI mein NEXATECT / owner-email billing line **nahi**
