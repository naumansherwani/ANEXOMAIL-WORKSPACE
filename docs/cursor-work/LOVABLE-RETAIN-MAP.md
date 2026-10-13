# Lovable codes — retain map (10 Sep 2026)

**Sawal:** existing phase files phenko ya alag karo?  
**Jawab:** **Alag karo, phenko mat.** 67+ SQL + Polar + Postfix spine. Mix = ek rail pe sab dump.

Teen layers (mix nahi):

| Layer | Kya hai | Kab chhoo |
|---|---|---|
| (1) Original blueprint `## PHASE N` | `docs/anexomail-blueprint.md` | Wire isi tarteeb se |
| (2) Added in repo / founder paste | `docs/package-feature-map.md`, SQL 52–63, F3 A/B | Jo file pehle se hai |
| (3) Claude F-series / suggestions | `IMPLEMENTATION-MASTER.md` F1–F9 | Build order — catalog nahi |

ANEXOChat alag blueprint. Phase 32+ sirf founder original paste.

**NO TOUCH:** `src/lib/plans.ts` · `src/lib/ai-packages.ts` · Polar Rust · landing pages · `BrandMark` SVG (A + ANEXOMAIL WORKSPACE lockup **retain** — har workspace page. Header se sirf insaan ka naam nikalna).

---

## Tarteeb (host × package) — Basic se

```
anexomail.com
  Basic     Dashboard + Mail + People + Calendar     ← ABHI yahan se zinda
  Pro       + Work (snooze / shared / tasks)
  Business  + Chat + Org + VideoCall (8)
  Biz Pro   + Chat limits + Video 40 + later Workspace Admin
ai.anexomail.com
  AI Pro / AI Business / AI Executive   LEO + platform included — Coming Soon awam
founderworkspace.anexomail.com
  sirf naumansherwani.founder@   deck + Speed + platform Admin
```

F4 mail-gate ke baghair F5+ **DONE** nahi.

---

## Retain — kahan rakho (Lovable files)

### KEEP — anexomail.com (Basic pehle)

| Code | Phase | Note |
|---|---|---|
| `src/styles.css` tokens | BP 1 | Locked CSS |
| `AppShell.tsx` + `host.ts` + `plan-surface.ts` | BP 1 + F1.2 | Gate, dump nahi |
| `src/lib/ia.ts` mail folders | BP 2 | Folders **Mail pane** mein |
| `auth.tsx` `server/routes/auth.ts` | BP 5A / F1 | Session `workspace_plan` |
| `app.index.tsx` dashboard | BP 6 / F2 | Har plan; Leo panel AI-only |
| `app.mail.*` `server/routes/mail.ts` `sendmail.ts` | BP 7, 9 / F3–F4 | Product spine |
| `app.people.tsx` `contacts.ts` | BP 10 / F6 | Basic+ |
| `app.calendar.tsx` `calendar.ts` | BP 11 / F7 | Basic+ |
| `ComposeStudio` | F4 | Leo buttons **AI plan only** |
| `StateBlock` Skeletons | BP 4 | Honest empty |

### KEEP — gate Business+ (anexomail.com)

| Code | Kab |
|---|---|
| `app.chat.tsx` + `src/lib/chat*.ts` + Rust `/wt/chat` | C1–31A live wire; **32+ paste** |
| `app.org.*` | Business+ |
| `app.work.tsx` | Pro+ (Basic hide) |
| VideoCall overlay (chat ke andar) | Business+ |

### KEEP — `ai.anexomail.com` only (awam Coming Soon)

| Code | Blueprint |
|---|---|
| `app.ai-center.tsx` `app.ai.*` `ai_.*.tsx` | BP 17–20, 31 |
| `server/routes/ai*.ts` | LEO meter |
| Compose Leo / summary / smart reply | AI plans |

### KEEP — `founderworkspace` only (Image 4 ka ghar)

| Code | Count / note |
|---|---|
| `src/routes/app.founder*.tsx` | 33 files — **delete nahi**, host guard |
| `app.perf.*` Speed | Founder |
| `app.admin.*` | Platform Admin ≠ Humza Org |
| `server/routes/founder.ts` | Founder emails allowlist |
| `src/lib/founder-plan.ts` | Mailbox plan vs live |

### GATE / HIDE on mail host (delete nahi)

| Code | Kyun |
|---|---|
| `app.crm.*` (6 files) | Extra host leftover — mail rail nahi |
| CRM / Speed / AI / Admin on family rail | Mix |
| `isChatHost` `isAiCrmHost` `*.lovable.app` = founder | Dirt — naya product nahi |

### NO TOUCH / NO REWRITE

Landing `index.tsx`, `plans.tsx`, Polar, `package.json`, 67 SQL dubara, ANEXOChat blueprint files.

---

## Audit imaandari

**Kiya:** `host.ts`, `AppShell`, `plan-surface.ts`, `auth.ts` session, `founder-plan.ts`, phase56/52, blueprint hosts, ~160 route **folder** inventory (mail / chat / crm / founder / ai / admin / org).

**Line-by-line 160 files nahi.** Har file ka matlab: **host + plan gate**, naya clone nahi.

---

## Basic se build (ek saath 160 nahi)

1. Session plan truth — Humza/Raana/Masood ≠ default `basic`
2. Chrome — workspace header **sirf A** (Gmail); naam avatar menu
3. Basic rail — Dashboard Mail People Calendar
4. URL honesty — `/dashboard` `/mail/inbox` (alag phase)
5. **F4** send+receive + mail-gate
6. Pro Work → Business Chat/Org → AI host → Founder F9
