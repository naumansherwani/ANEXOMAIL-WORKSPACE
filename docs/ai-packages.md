# ANEXOMAIL — PACKAGES MASTER (repo source of truth, locked 25 Aug 2026)

Rule: koi bhi price/package change pehle is repo mein hota hai, phir kahin aur.
Chat mein ad-hoc package kabhi nahi. Frontend display truth = `src/lib/plans.ts`
+ `src/lib/ai-packages.ts`; Polar IDs = `docs/polar-products.md`.

## 1. Workspace plans (anexomail.com — NO AI)

| Plan | Monthly | Yearly | Annual rule |
|---|---|---|---|
| Basic | £23 /user | £253 /user | 1 month free |
| Pro | £46 /user | £506 /user | 1 month free |
| Business | £97 /user | £970 /user | 2 months free |
| Business Pro | £2,850 /company | £28,500 /company | 2 months free |
| Priority Support add-on | £790 /month | — | — |

Move-In one-off: 1–5 £568 · 6–15 £1,670 · 16–29 £2,210 · 30+ £3,350.

## 2. AI plans (ai.anexomail.com — LEO product)

| Plan | Monthly | Yearly | Credits/mo |
|---|---|---|---|
| AI Pro | £400 | £4,000 | 1,200 |
| AI Business | £1,500 | £15,000 | 5,000 |
| AI Executive | £4,000 | £40,000 | 10,000 |

Top-ups: £15/40cr · £30/75 · £60/170 · £120/360 · £250/800 · £500/1,800 ·
£1,000/4,000 · £2,000/9,000 · (£5,000/21,000 founder-only).

## 3. Package LOGIC (awam ko yeh logic attract karta hai)

- **AI Pro (£400) > Business (£97):** AI Pro mein poora Business platform
  included + AI workspace + 1,200 credits. Awam sochta hai: "£97 mein sirf
  workspace, £400 mein workspace + poora AI — better deal."
- **AI Executive (£4,000) > Business Pro (£2,850):** Business Pro sab se
  expensive NON-AI package hai; AI Executive uske upar — Business Pro platform
  included + full AI bundle + 10,000 credits.
- Sab se mehnga = AI Executive (AI), sab se mehnga non-AI = Business Pro.
  Yeh ladder jaan boojh kar aisa hai.

## 4. ANEXOChat — AI package features (awam list, coming soon)

| Feature | AI Pro | AI Business | AI Executive |
|---|---|---|---|
| ANEXOChat 1-to-1 + group | ✓ | ✓ | ✓ |
| LEO thread summary (chat → 5 lines) | ✓ | ✓ | ✓ |
| Smart reply / tone rewrite | ✓ | ✓ | ✓ |
| Auto work items (task/promise/decision) | ✓ | ✓ | ✓ |
| Live translate (auto-detect) | — | ✓ | ✓ |
| Meeting-from-chat | — | ✓ | ✓ |
| Screenshot/image read | — | ✓ | ✓ |
| Company-wide chat intelligence | — | — | ✓ |
| LEO Actions in chat | — | — | ✓ |

## 5. ANEXOVideoCall — AI package features

| Feature | AI Pro | AI Business | AI Executive |
|---|---|---|---|
| 1-to-1 call (P2P + TURN, adaptive) | ✓ | ✓ | ✓ |
| Honest quality badge + telemetry | ✓ | ✓ | ✓ |
| Live captions | ✓ | ✓ | ✓ |
| Post-call LEO notes + action items | — | ✓ | ✓ |
| Recording + transcript search | — | ✓ | ✓ |
| Live translated captions | — | ✓ | ✓ |
| 8K native capture | — | ✓ | ✓ |
| Company call analytics | — | — | ✓ |
| LEO as note-taker participant | — | — | ✓ |

Credit-metered: summary · rewrite · translate · image-read · recording ·
transcript · captions · actions. Pre-flight estimate + receipt har action par.

## 6. AI subdomain mashwara (locked)

`ai.anexomail.com` SAME rehta hai — alag subdomain kabhi nahi.
Wajah: ek hi codebase + host-aware gate; alag subdomain = doosri dukaan,
awam confuse, SEO/Caddy/maintenance double. ANEXOChat aur ANEXOVideoCall
alag subdomain nahi — woh AI packages ke ANDAR ke features hain,
ai.anexomail.com/app/* mirror mein chalte hain.
