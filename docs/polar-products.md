# Polar — Products & Checkout (copy-paste blocks)

Locked prices. Yahi exact naam Polar dashboard mein banao. Currency: **GBP (£)**.

## 1) One-time products — Managed Move-In (4 products)

| Product name                        | Price  | Billing  |
| ----------------------------------- | ------ | -------- |
| `Managed Move-In · 1–5 Mailboxes`   | £500   | One-time |
| `Managed Move-In · 6–15 Mailboxes`  | £1,500 | One-time |
| `Managed Move-In · 16–29 Mailboxes` | £2,000 | One-time |
| `Managed Move-In · 30+ Mailboxes`   | £3,000 | One-time |

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

| Product name       | Price | Billing             |
| ------------------ | ----- | ------------------- |
| `Priority Support` | £700  | Recurring — monthly |

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

## 3) Workspace plans (monthly aur yearly alag Polar products)

| Product name             | Monthly |  Yearly | Yearly message    |
| ------------------------ | ------: | ------: | ----------------- |
| `ANEXOMAIL Basic`        |     £20 |    £220 | Get 1 month free  |
| `ANEXOMAIL Pro`          |     £40 |    £440 | Get 1 month free  |
| `ANEXOMAIL Business`     |     £85 |    £850 | Get 2 months free |
| `ANEXOMAIL Business Pro` |  £2,500 | £25,000 | Get 2 months free |

Har row ke liye Polar mein **do alag recurring products** banao: `Monthly` aur `Yearly`. Yearly amount monthly effective rate nahi; upar wala exact annual charge hai. **ANEXOMAIL AI Polar par abhi nahi banana — AI backend-only aur public coming soon hai.**

### Plan descriptions (Polar product description mein paste karo)

**ANEXOMAIL Basic — £20 / user / month · £220 / year (1 month free)**

```text
Professional company email for one person, with control built in.

- 1 company address, 3 mailboxes, 5GB per mailbox
- 5 free aliases and undo send (30 seconds)
- Contacts and calendar in the same workspace
- Thread ownership so nothing is answered twice
- Cmd+K search across your whole workspace
- One-click export — your data leaves whenever you want
- Human support, response within 72 hours

Yearly: £220 — one month free. Billed once a year, cancel at renewal.
```

**ANEXOMAIL Pro — £40 / user / month · £440 / year (1 month free)**

```text
For teams answering customers every day.

- Everything in Basic
- 3 company addresses, 5 mailboxes, 10GB per mailbox
- Shared inbox with collision guard — two people never reply to the same mail
- Snooze and schedule send
- Email templates and snippets
- Boards, notes and tasks attached to the thread
- Thread analytics — who is carrying the load
- Human support, response within 48 hours

Yearly: £440 — one month free. Billed once a year, cancel at renewal.
```

**ANEXOMAIL Business — £85 / user / month · £850 / year (2 months free)**

```text
For growing companies that need governance over their email, not just storage.

- Everything in Pro
- Up to 30 users, 25GB per mailbox
- Roles and departments
- Policies and a full audit ledger
- One-click access revocation for any person or device
- One-click data export, no lock-in
- Native integrations
- ANEXOChat included
- 15GB transfer per user per month, 2GB maximum file send
- Business workspace identity with MX, SPF, DKIM and DMARC proven green
- Human support, response within 24 hours

Yearly: £850 — two months free. Billed once a year, cancel at renewal.
```

**ANEXOMAIL Business Pro — £2,500 / company / month · £25,000 / year (2 months free)**

```text
The complete company communication stack — one price for the whole company, not per user.

- Everything in Business
- Unlimited internal users on your domain
- ANEXOChat Business Pro for the whole company
- 1TB pooled workspace storage
- 5GB maximum file and video sending, resumable transfer engine
- Device Trust and cryptographic vault — every device scored, killed in one click
- Audit ledger with message provenance you can hand to an auditor
- Conversation to task engine — work leaves the inbox and becomes owned work
- Promise tracking — every commitment made in email is followed to done
- Decision ledger — the moment a decision was made, kept forever
- Conversation health and full company timeline
- Permanent business search across mail, chat, files and people
- Email and chat bridge — one thread, two channels
- Export and no lock-in guarantee, real delete means deleted
- Priority human support, response within 12 hours

Priced per company, not per seat. Yearly: £25,000 — two months free.
```

### Basic ka exact Polar setup

1. Mojooda `ANEXOMAIL Basic` product ko rename karke `ANEXOMAIL Basic Monthly` rakho. Price: **£20**, recurring interval: **Monthly**.
2. Naya product `ANEXOMAIL Basic Yearly` banao. Price: **£220**, recurring interval: **Yearly**.
3. Monthly metadata: `brand=anexomail`, `kind=plan`, `plan=basic`, `billing_cycle=monthly`.
4. Yearly metadata: `brand=anexomail`, `kind=plan`, `plan=basic`, `billing_cycle=yearly`.
5. Monthly ka mojooda product ID `POLAR_PRODUCT_PLAN_BASIC_MONTHLY` mein rehta hai. Naye Yearly product ka ID `POLAR_PRODUCT_PLAN_BASIC_YEARLY` mein paste hota hai.

## 4) Metadata (Polar UI: Key · Type · Value rows)

Polar mein har metadata line ek ROW hoti hai: **Key** + **Type** + **Value**.
Type hamesha **String** rakho (Number/Boolean kabhi nahi). Har row ke baad
**Add Metadata** dabao.

**Move-In products (4) — 3 rows:**

| Key     | Type   | Value                               |
| ------- | ------ | ----------------------------------- |
| `brand` | String | `anexomail`                         |
| `kind`  | String | `movein`                            |
| `band`  | String | `1-5` / `6-15` / `16-29` / `30plus` |

**Priority Support — 2 rows:**

| Key     | Type   | Value       |
| ------- | ------ | ----------- |
| `brand` | String | `anexomail` |
| `kind`  | String | `support`   |

**Har plan product — 4 rows:**

| Key             | Type   | Value                                                                                     |
| --------------- | ------ | ----------------------------------------------------------------------------------------- |
| `brand`         | String | `anexomail`                                                                               |
| `kind`          | String | `plan`                                                                                    |
| `plan`          | String | `basic` / `pro` / `business` / `business_pro`                                              |
| `billing_cycle` | String | `monthly` / `yearly`                                                                      |

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
# Purane teen IDs ko pehle monthly naam par move karo:
POLAR_PRODUCT_PLAN_BASIC_MONTHLY=9560496a-4449-4428-949d-95c923c8dad9
POLAR_PRODUCT_PLAN_PRO_MONTHLY=ef47325e-983c-4ea8-bdbe-be99cc00c584
POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY=2eee930b-b530-43ce-a6d4-14b87315f49e
# Polar dashboard mein naye products bana kar IDs yahan paste karo:
POLAR_PRODUCT_PLAN_BASIC_YEARLY=REPLACE
POLAR_PRODUCT_PLAN_PRO_YEARLY=REPLACE
POLAR_PRODUCT_PLAN_BUSINESS_YEARLY=REPLACE
POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY=REPLACE
POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY=REPLACE
```

### Confirmed monthly IDs (founder ne banaye)

| Product                                             | Polar ID                               | Status     |
| --------------------------------------------------- | -------------------------------------- | ---------- |
| Managed Move-In · 1–5 Mailboxes (£500 one-time)     | `fdcdabc2-9e50-4e4b-91d4-45e4128ef829` | ✅ created |
| Managed Move-In · 6–15 Mailboxes (£1,500 one-time)  | `a9d1bec3-0d5f-4b9b-ae1c-993efde66da2` | ✅ created |
| Managed Move-In · 16–29 Mailboxes (£2,000 one-time) | `c7b502c5-ff75-4138-b34d-25d94878fe79` | ✅ created |
| Managed Move-In · 30+ Mailboxes (£3,000 one-time)   | `f3ff5002-b55f-45b5-b0b9-d80c1f33d3c8` | ✅ created |
| Priority Support (£700/mo)                          | `92a35351-743c-4ddf-b1f4-fae473a89e69` | ✅ created |
| Basic (£20/mo)                                      | `9560496a-4449-4428-949d-95c923c8dad9` | ✅ created |
| Pro (£40/mo)                                        | `ef47325e-983c-4ea8-bdbe-be99cc00c584` | ✅ created |
| Business (£85/mo)                                   | `2eee930b-b530-43ce-a6d4-14b87315f49e` | ✅ created |

Yearly + Business Pro ke `REPLACE` IDs Polar dashboard mein create karke bharne hain. AI ke liye koi Polar env key nahi hai. Jab tak kisi workspace key ka asli ID env mein nahi hota, backend us checkout ko `product_required` se rokta hai — galat monthly fallback kabhi nahi karta.

Backend route `server/routes/polar.ts` repo mein add ho gaya hai — checkout + webhook dono.

**Checkout contract:** frontend sirf `product_key`, `seats`, `email` bhejta hai `POST /api/billing/intent` par. Amount, plan, cycle aur Polar product ID backend registry decide karti hai. Purana `POST /api/billing/checkout` retired hai, is liye client arbitrary `product_id` bhej kar sasta checkout nahi bana sakta.

## 8) Billing emails + founder reply clock

- Polar paid checkout ke baad customer ko provider receipt/invoice automatically bhejta hai.
- Verified webhook usi payment ka immutable proof `billing_event_receipts` mein rakhta hai.
- Paid plan `workspace_subscriptions` mein save hota hai: Basic / Pro / Business.
- Founder reply clock: Basic **72h**, Pro **48h**, Business **24h**.
- `hello@anexomail.com` par inbound conversation aate hi paid plan lookup aur deadline automatic hoti hai; founder ka outbound reply clock ko automatic close karta hai.
- Founder queue endpoint: `GET /api/founder/support/replies`.
- SQL: `sql/phase34_billing_support.sql` Supabase #4 mein run karna hai.

## 9) Testing (Polar ka sandbox nahi hai)

100% off forever discount code banao, phir asli checkout us code se chalao.
