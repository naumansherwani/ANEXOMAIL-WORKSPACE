# Cursor Work — Sep 9 2026

Is session mein jo bana ya badla woh sab yahan. GitHub → server pull → SQL → frontend.
**Tarteeb se chalo. Mix nahi.**

---

## STEP 1 — Server pull

```bash
cd /opt/anexomail-web && git pull
```

---

## STEP 2 — SQL (Supabase #4 Editor — tarteeb se, ek ek paste)

Dono file GitHub se kholo → Raw → Copy → Supabase SQL Editor → Run.

### 2A — Phase 60 (org identity)

**File:** https://github.com/naumansherwani/ANEXOMAIL-WORKSPACE/blob/main/sql/phase60_org_identity_repair.sql

**Kya karta hai:** `orgs`, `org_members`, `mail_accounts` tables banata hai (login ke
baad "No organisation yet" ki asli wajah — yeh tables nahi thin). `account_org_members`
(Phase 59, onboarding) se backfill karta hai.

**Verify (paste ke baad numbers aane chahiye, error nahi):**
```
orgs_rows | org_members_rows | mail_accounts_rows
```

### 2B — Phase 61 (calendar + work)

**File:** https://github.com/naumansherwani/ANEXOMAIL-WORKSPACE/blob/main/sql/phase61_calendar_work.sql

**Kya karta hai:** `calendar_events`, `calendar_attendees`, `calendar_focus_windows`,
`work_tasks`, `work_promises`, `work_notes`, `mail_thread_events` tables banata / patch
karta hai. Calendar "That didn't go through" ki wajah yeh tables missing ya column bina
thin.

**Verify:**
```
calendar_status_ready = true | work_status_ready = true
```

### 2C — Phase 62 (contacts)

**File:** https://github.com/naumansherwani/ANEXOMAIL-WORKSPACE/blob/main/sql/phase62_contacts_intelligence.sql

**Kya karta hai:** `contacts`, `contact_stats`, `companies`, `contact_tags`,
`contact_tag_map` tables + `anexo_rebuild_contacts()` RPC. People tab wiring.

**Verify:**
```
contacts_ready = true | rpc_ready = true
```

---

## STEP 3 — Frontend build (STEP 2 ke baad)

```bash
cd /opt/anexomail-web && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
```

**Is build mein yeh frontend fixes hain:**
- Password field Eye/EyeOff icon: pehle ghost button dark mode mein invisible tha. Ab `text-muted-foreground` color ke saath clearly dikhega (`src/routes/auth.tsx`)
- API error `[object Object]` ki jagah asli message: `src/lib/api.ts`

---

## Changed files (is session mein sirf yeh)

| File | Kya badla |
|---|---|
| `sql/phase60_org_identity_repair.sql` | Naya — org identity tables |
| `sql/phase61_calendar_work.sql` | Naya — calendar + work tables |
| `sql/phase62_contacts_intelligence.sql` | Naya — contacts tables + RPC |
| `src/routes/auth.tsx` | Password Eye button fix (ghost → explicit button) |
| `src/lib/api.ts` | `[object Object]` error → asli message |
| `src/lib/host.ts` | `isPublicMailHost()` add — `SiteLock` use karta hai |
| `src/components/site/SiteLock.tsx` | `anexomail.com` par "Not open yet" nahi dikhata |
| `src/lib/founder-preview.ts` | `workspaceTourFromUrl()` — sticky localStorage session bypass band |
| `src/routes/app.tsx` | `workspaceTourFromUrl()` use, `/app` bina session redirect → `/auth` |
| `src/components/app/AppShell.tsx` | Awam host par Chat/AI/Speed/Admin/Founder nav hide |
| `src/routes/claim.tsx` | Comment only |
| `src/routes/onboarding.tsx` | "NEXATECT Global Ltd" → "Your company Ltd" placeholder |
| `src/components/site/LeadForm.tsx` | Wohi placeholder fix |
| `docs/BLUEPRINT-SUPERSEDE-PLAN.md` | Naya — build process law |
| `docs/cursor-work/README.md` | Yeh file |

**Landing pages, logo, Polar, packages, ANEXOChat SQL — touch nahi hua.**

---

## Host.ts kahan chalta hai (confusion dur)

`src/lib/host.ts` — browser TypeScript. Hetzner par seedha run nahi hota.

- `bun run build:bun` is file ko bundle karta hai SSR ke andar
- Browser par `window.location.hostname` check karta hai
- `anexomail.com` → awam mail surface
- `founderworkspace.anexomail.com` → founder surface
- `ai.anexomail.com` → AI surface (awam ko sirf `/` coming soon)
- Alag `node host.ts` ya `bash host.ts` nahi hota

---

## Agle phases ke liye

Blueprint: `docs/BLUEPRINT-SUPERSEDE-PLAN.md`

Phase 1 → 11 (ANEXOMAIL mail workspace): founder original block paste kare ya bole
"Phase N chalo". Ek phase, ek file, ek paste. Is folder mein naya `.md` tab aayega.

ANEXOChat Phase 32+: founder original `## PHASE N` paste kare.
