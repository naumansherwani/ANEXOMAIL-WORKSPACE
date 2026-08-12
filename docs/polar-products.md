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
| `Priority Support` | £700 | Recurring — monthly |

**Description:**

```text
Priority Support — £700 / month. A named founder contact instead of a queue.

- Response within 2 business days
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

## 4) Metadata (Polar UI: Key · Type · Value rows)

Polar mein har metadata line ek ROW hoti hai: **Key** + **Type** + **Value**.
Type hamesha **String** rakho (Number/Boolean kabhi nahi). Har row ke baad
**Add Metadata** dabao.

**Move-In products (4) — 3 rows:**

| Key | Type | Value |
| --- | --- | --- |
| `brand` | String | `anexomail` |
| `kind` | String | `movein` |
| `band` | String | `1-5` / `6-15` / `16-29` / `30plus` |

**Priority Support — 2 rows:**

| Key | Type | Value |
| --- | --- | --- |
| `brand` | String | `anexomail` |
| `kind` | String | `support` |

**Plans (Basic/Pro/Business) — 3 rows:**

| Key | Type | Value |
| --- | --- | --- |
| `brand` | String | `anexomail` |
| `kind` | String | `plan` |
| `plan` | String | `basic` / `pro` / `business` |

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
POLAR_PRODUCT_MOVEIN_6_15=a9d1bec3-0d5f-4b9b-ae1c-993efde66da2
POLAR_PRODUCT_MOVEIN_16_29=c7b502c5-ff75-4138-b34d-25d94878fe79
POLAR_PRODUCT_MOVEIN_30PLUS=f3ff5002-b55f-45b5-b0b9-d80c1f33d3c8
POLAR_PRODUCT_PRIORITY_SUPPORT=92a35351-743c-4ddf-b1f4-fae473a89e69
POLAR_PRODUCT_PLAN_BASIC=9560496a-4449-4428-949d-95c923c8dad9
POLAR_PRODUCT_PLAN_PRO=ef47325e-983c-4ea8-bdbe-be99cc00c584
POLAR_PRODUCT_PLAN_BUSINESS=2eee930b-b530-43ce-a6d4-14b87315f49e
```

### Confirmed IDs (founder ne banaye)

| Product | Polar ID | Status |
| --- | --- | --- |
| Managed Move-In · 1–5 Mailboxes (£500 one-time) | `fdcdabc2-9e50-4e4b-91d4-45e4128ef829` | ✅ created |
| Managed Move-In · 6–15 Mailboxes (£1,500 one-time) | `a9d1bec3-0d5f-4b9b-ae1c-993efde66da2` | ✅ created |
| Managed Move-In · 16–29 Mailboxes (£2,000 one-time) | `c7b502c5-ff75-4138-b34d-25d94878fe79` | ✅ created |
| Managed Move-In · 30+ Mailboxes (£3,000 one-time) | `f3ff5002-b55f-45b5-b0b9-d80c1f33d3c8` | ✅ created |
| Priority Support (£700/mo) | `92a35351-743c-4ddf-b1f4-fae473a89e69` | ✅ created |
| Basic (£20/mo) | `9560496a-4449-4428-949d-95c923c8dad9` | ✅ created |
| Pro (£40/mo) | `ef47325e-983c-4ea8-bdbe-be99cc00c584` | ✅ created |
| Business (£85/mo) | `2eee930b-b530-43ce-a6d4-14b87315f49e` | ✅ created |

Backend route `server/routes/polar.ts` repo mein add ho gaya hai — checkout + webhook dono.

## 8) Testing (Polar ka sandbox nahi hai)

100% off forever discount code banao, phir asli checkout us code se chalao.
