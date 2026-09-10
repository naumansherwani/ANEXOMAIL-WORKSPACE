# PACKAGE + FEATURE FORMULA — Agent Personal Memory
# Source: docs/ai-packages.md + docs/package-feature-map.md (Lovable originals — DO NOT DELETE)
# Rule: packages touch NAHI kerne — sirf yeh file dekh ke feature gate decide karo

---

## RULE 1 — NEVER TOUCH (locked forever)
```
src/lib/plans.ts          ← workspace plans pricing (FOUNDER LOCKED)
src/lib/ai-packages.ts    ← AI plans pricing (FOUNDER LOCKED)
server/routes/polar.ts    ← payment webhook (FOUNDER FIXED)
docs/polar-products.md    ← Polar product IDs
docs/ai-packages.md       ← master package doc (original)
docs/package-feature-map.md ← phase feature gating (original)
```

Agent ka kaam: feature gate decide karna. Pricing change karna nahi.

---

## RULE 2 — PACKAGE LOGIC FORMULA (Lovable ka formula — locked)

```
AI Pro (£400)      INCLUDES:  Business platform + AI workspace + 1,200 credits
AI Business (£1,500) INCLUDES: Business platform + more AI + 5,000 credits
AI Executive (£4,000) INCLUDES: Business PRO platform + full AI + 10,000 credits

Formula:
  AI Pro     > Business      (£400 > £97  — better deal: workspace + AI both)
  AI Executive > Business Pro (£4000 > £2850 — Business Pro included + AI on top)
```

**Ladder (jaan boojh kar aisa hai):**
```
Basic (£23) → Pro (£46) → Business (£97) → Business Pro (£2850/co)
                                                ↕
                         AI Pro (£400) → AI Business (£1500) → AI Executive (£4000)
```

- Sab se mehnga non-AI = Business Pro
- Sab se mehnga overall = AI Executive
- AI Pro sirf AI features ke liye nahi — Business POORA included hai

---

## RULE 3 — SURFACE SEPARATION (locked)

| Surface | Host | Plans shown |
|---|---|---|
| Workspace | `anexomail.com` | Basic, Pro, Business, Business Pro |
| AI workspace | `ai.anexomail.com` | AI Pro, AI Business, AI Executive |
| Founder | `founderworkspace.anexomail.com` | All features, no plan gate |

`ai.anexomail.com` SAME codebase — sirf host-aware gate.
ANEXOChat + ANEXOVideoCall = `ai.anexomail.com` ke ANDAR, alag subdomain NAHI.

---

## RULE 4 — WHEN ADDING NEW FEATURE: WHICH PLAN GETS IT?

```
New feature decide karne ka formula:

1. Kya yeh basic mail/contacts/calendar hai?
   → ALL plans (Basic+)

2. Kya yeh collaboration (shared inbox, teams, audit)?
   → Pro+ (Pro, Business, Business Pro, all AI)

3. Kya yeh ANEXOChat feature hai?
   → Business+ ONLY (Business, Business Pro, AI Pro+)
   → Basic/Pro ko ZERO ANEXOChat

4. Kya yeh large file transfer (>2GB) / 1TB storage?
   → Business Pro + AI Business + AI Executive ONLY

5. Kya yeh LEO AI feature hai?
   → AI plans ONLY (AI Pro, AI Business, AI Executive)
   → Workspace plans ko ZERO AI

6. Kya yeh admin / device trust / safety review?
   → Business Pro + AI Executive (top tiers only)

7. Kya yeh founder-only feature hai?
   → is_founder = true (DB flag) — no plan check needed
```

---

## FEATURE GATES PER PLAN (DB-backed, source: package-feature-map.md)

### Core Mail + Workspace
| Feature | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
|---|---|---|---|---|---|---|---|
| Mail send/receive | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Contacts + Calendar | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Thread ownership | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Undo send 30s | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Snooze / schedule send | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Shared inbox (collision guard) | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Tasks + thread analytics | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### Storage
| Plan | Per mailbox / pool |
|---|---|
| Basic | 5 GB/mailbox |
| Pro | 10 GB/mailbox |
| Business | 25 GB/mailbox |
| Business Pro | 1 TB pooled |
| AI Pro | 256 GB pooled |
| AI Business | 1 TB pooled |
| AI Executive | 2 TB pooled |

### ANEXOChat
| Feature | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
|---|---|---|---|---|---|---|---|
| 1-to-1 + group chat | ❌ | ❌ | ✓ Ph1-56 | ✓ Ph1-56 | ✓ Ph1-57 | ✓ Ph1-57 | ✓ Ph1-57 |
| Max file in chat | — | — | 2 GB | 5 GB | 2 GB | 5 GB | 5 GB |
| Monthly transfer | — | — | 5 TB | unlimited | 5 TB | unlimited | unlimited |
| Resumable transfer | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |

### LEO AI (credit-metered)
| Feature | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
|---|---|---|---|---|---|---|---|
| Smart reply / rewrite | ❌ | ❌ | ❌ | ❌ | ✓ | ✓ | ✓ |
| Thread summary | ❌ | ❌ | ❌ | ❌ | ✓ | ✓ | ✓ |
| Live translate | ❌ | ❌ | ❌ | ❌ | — | ✓ | ✓ |
| AI workflow builder | ❌ | ❌ | ❌ | ❌ | — | ✓ | ✓ |
| AI Executive Briefing | ❌ | ❌ | ❌ | ❌ | — | — | ✓ |
| Credits per month | 0 | 0 | 0 | 0 | 1,200 | 5,000 | 10,000 |

### ANEXOVideoCall
| Feature | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
|---|---|---|---|---|---|---|---|
| 1:1 video call | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Group participants | — | — | 8 | 40 | 8 | 40 | 60 |
| Screen share | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Live captions (AI) | — | — | — | — | ✓ | ✓ | ✓ |
| Post-call LEO notes | — | — | — | — | — | ✓ | ✓ |
| Recording + search | — | — | — | ✓ | — | ✓ | ✓ |

### Device Trust + Security
| Feature | Basic | Pro | Business | Biz Pro | AI Pro | AI Biz | AI Exec |
|---|---|---|---|---|---|---|---|
| Device vault (sealed) | ✓ 2 | ✓ 4 | ✓ 10 | ✓ 50 | ✓ 10 | ✓ 50 | ✓ 100 |
| One-click session kill | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Safety review queue | — | — | — | ✓ | — | — | ✓ |
| Enforcement history | — | — | — | ✓ | — | — | ✓ |

---

## RULE 5 — DB AUTHORITY (feature gate check kaise hota hai)

```
Server pe feature check:
  1. GET /api/trial/state → account.plan
  2. Check plan against DB function: chat_feature_allowed(org_id, feature_name)
  3. Server returns 403 if not allowed — frontend sirf honest state dikhata hai

Frontend pe UI gate:
  const account = useAccountState()
  if (!account.data?.ai_enabled) return <UpgradeBanner />
  if (account.data?.plan !== 'business') return <UpgradeBanner />
```

**LOCK:** Client-side gate = sirf UI. Real gate = server + DB (RLS + function).
Client ko tamper karke feature nahi milta.

---

## AI CREDITS — Pre-flight formula

```
Har AI action se pehle:
  1. Estimate: "This will use ~8 credits. You have 1,192 remaining." → User: Approve
  2. Execute
  3. Receipt: Action + Model + Credits used + Time + Source

Zero-credit state: human workspace chalti rehti hai, AI pauses.
Complimentary: 5/day first 2 days = 10 total per billing cycle.
```

---

## TOP-UP PRICES (locked — source: docs/ai-packages.md)

| Amount | Credits |
|---|---|
| £15 | 40 |
| £30 | 75 |
| £60 | 170 |
| £120 | 360 |
| £250 | 800 |
| £500 | 1,800 |
| £1,000 | 4,000 |
| £2,000 | 9,000 |
| £5,000 | 21,000 (founder-only) |
