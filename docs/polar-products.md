# Polar — Products & Checkout (copy-paste blocks)

Locked prices. Yahi exact naam Polar dashboard mein banao. Currency: **GBP (£)**.

## 1) One-time products — Managed Move-In (4 products)

| Product name | Price | Billing |
| --- | --- | --- |
| `Managed Move-In · 1–5 Mailboxes` | £500 | One-time |
| `Managed Move-In · 6–15 Mailboxes` | £1,500 | One-time |
| `Managed Move-In · 16–29 Mailboxes` | £2,000 | One-time |
| `Managed Move-In · 30+ Mailboxes` | £3,000 | One-time |

**Description (teeno products ke liye, sirf band line badalti hai):**

```text
We move your whole company off Gmail, Outlook, Zoho or plain IMAP — and prove your domain is green.

- Mail, folders, read state and full history moved and verified message-for-message
- Contacts, calendars, aliases, shared addresses and signatures rebuilt
- MX, SPF, DKIM and DMARC generated and proven green on your domain
- Cut-over scheduled overnight and designed to avoid interruption
- A written item-by-item move log handed to you at the end

Band: 1–5 mailboxes. 50% on accepting the written plan, 50% the business day after cut-over.
Two move-ins a month — done by hand, never queued. Old mailboxes are copied, never deleted.
```

Band line variants:
- `Band: 1–5 mailboxes.`
- `Band: 6–15 mailboxes.`
- `Band: 16–29 mailboxes.`
- `Band: 30 or more mailboxes.`

## 2) Recurring product — Priority Support

| Product name | Price | Billing |
| --- | --- | --- |
| `Priority Support` | £500 | Recurring — monthly |

**Description:**

```text
Priority Support — £500 / month. A named founder contact instead of a queue.

- Response within 1 business day
- Named founder contact
- Quarterly service & security review
- Priority migration scheduling
- Up to 3 companies at a time

Sits on top of any plan. Invoiced monthly in advance, cancel at the end of any month.
Business days are Monday to Friday, UK time.
```

## 3) Workspace plans (recurring, per person / month)

| Product name | Price | Billing |
| --- | --- | --- |
| `ANEXOMAIL Basic` | £20 | Recurring — monthly |
| `ANEXOMAIL Pro` | £40 | Recurring — monthly |
| `ANEXOMAIL Business` | £85 | Recurring — monthly |

## 4) Metadata (har product par set karo)

```text
brand = anexomail
kind  = movein | support | plan
band  = 1-5 | 6-15 | 16-29 | 30plus   (sirf movein par)
plan  = basic | pro | business     (sirf plan par)
```

## 5) Server 2 — env block (Polar tokens)

```bash
cd /opt/anexomail
grep -q '^POLAR_ACCESS_TOKEN=' .env || echo "POLAR_ACCESS_TOKEN=REPLACE_WITH_POLAR_ORG_TOKEN" >> .env
grep -q '^POLAR_WEBHOOK_SECRET=' .env || echo "POLAR_WEBHOOK_SECRET=REPLACE_WITH_POLAR_WEBHOOK_SECRET" >> .env
grep -q '^POLAR_SUCCESS_URL=' .env || echo "POLAR_SUCCESS_URL=https://anexomail.com/checkout/done?checkout_id={CHECKOUT_ID}" >> .env
nano .env   # dono REPLACE_ values apne asli token/secret se badlo
pm2 restart anexomail-leo --update-env && pm2 logs anexomail-leo --lines 40
```

## 6) Polar webhook (dashboard → Settings → Webhooks)

- URL: `https://anexomail.com/api/public/polar/webhook`
- Events: `checkout.created`, `checkout.updated`, `order.created`, `order.paid`,
  `subscription.created`, `subscription.active`, `subscription.canceled`, `subscription.revoked`, `subscription.past_due`
- Secret → `POLAR_WEBHOOK_SECRET` (upar ke block mein).
- **Refund policy:** ANEXOMAIL does not issue refunds. Polar `order.refunded` event is not consumed.

## 7) Product IDs ka jagah (Polar mein banane ke baad)

Product bante hi Polar ke IDs is ek block se `.env` mein daalo:

```bash
cd /opt/anexomail && nano .env
# neeche paste karo, asli IDs ke saath:
POLAR_PRODUCT_MOVEIN_1_5=fdcdabc2-9e50-4e4b-91d4-45e4128ef829
POLAR_PRODUCT_MOVEIN_6_15=prod_xxx
POLAR_PRODUCT_MOVEIN_16_29=prod_xxx
POLAR_PRODUCT_MOVEIN_30PLUS=prod_xxx
POLAR_PRODUCT_PRIORITY_SUPPORT=prod_xxx
POLAR_PRODUCT_PLAN_BASIC=prod_xxx
POLAR_PRODUCT_PLAN_PRO=prod_xxx
POLAR_PRODUCT_PLAN_BUSINESS=prod_xxx
```

### Confirmed IDs (founder ne banaye)

| Product | Polar ID | Status |
| --- | --- | --- |
| Managed Move-In · 1–5 Mailboxes (£500 one-time) | `fdcdabc2-9e50-4e4b-91d4-45e4128ef829` | ✅ created |
| Managed Move-In · 6–15 Mailboxes (£1,500 one-time) | — | pending |
| Managed Move-In · 16–29 Mailboxes (£2,000 one-time) | — | pending |
| Managed Move-In · 30+ Mailboxes (£3,000 one-time) | — | pending |
| Priority Support (£500/mo) | — | pending |
| Basic (£20/mo) | — | pending |
| Pro (£40/mo) | — | pending |
| Business (£85/mo) | — | pending |

IDs aa jayein to bolo — checkout + webhook route (`/api/public/polar/webhook`,
`/api/billing/checkout`) likh ke repo mein `server/routes/polar.ts` de dunga.

## 8) Testing (Polar ka sandbox nahi hai)

100% off forever discount code banao, phir asli checkout us code se chalao.
