# Personal Polar products — copy exactly

**Status: READY.** Public home, `/plans`, Business products aur Rust webhook unchanged hain. **DONE** sirf six IDs, E13 SQL, deploy aur real checkout proof ke baad.

Polar mein har billing interval ka alag recurring product banao. Currency **GBP**.

| Product name | Billing | Exact price | Environment key |
|---|---|---:|---|
| `ANEXOMAIL Personal Basic — Monthly` | Monthly | £17 | `POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY` |
| `ANEXOMAIL Personal Basic — Yearly` | Yearly | £187 | `POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY` |
| `ANEXOMAIL Personal Pro+ — Monthly` | Monthly | £83 | `POLAR_PRODUCT_PLAN_PERSONAL_PRO_MONTHLY` |
| `ANEXOMAIL Personal Pro+ — Yearly` | Yearly | £913 | `POLAR_PRODUCT_PLAN_PERSONAL_PRO_YEARLY` |
| `ANEXOMAIL Personal Premium — Monthly` | Monthly | £1,850 | `POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY` |
| `ANEXOMAIL Personal Premium — Yearly` | Yearly | £18,500 | `POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY` |

## Product descriptions

### Personal Basic

```text
Professional email and personal work tools for one person.

- 1 company address, 3 mailboxes, 5GB per mailbox
- 5 free aliases and undo send (30 seconds)
- Contacts and calendar
- Thread ownership and workspace search
- Personal tasks and work tracking
- Human support, response within 72 hours
- ANEXOChat and full CRM are not included

Yearly: £187 — one month free. Billed once a year.
```

### Personal Pro+

```text
The complete communication workspace for one professional, without a company organisation.

- Everything in Personal Basic
- 3 company addresses, 5 mailboxes, 10GB per mailbox
- Shared inbox collision guard, snooze and scheduled send
- Templates, boards, notes, tasks and thread analytics
- Full CRM
- ANEXOChat and ANEXOVideoCall with screen share
- Human support, response within 48 hours
- Company Org, departments and multi-user governance are not included

Yearly: £913 — one month free. Billed once a year.
```

### Personal Premium

```text
Maximum communication, evidence and storage power for one professional.

- Everything in Personal Pro+
- Unlimited mailboxes and 1TB pooled storage
- 5GB maximum file and video sending
- Resumable transfer and download evidence
- Device Trust, cryptographic vault and self-hosted content safety
- 5,000 open work objects, dependencies and completion evidence
- Tamper-evident conversation records
- Group calls up to 40 participants and advanced relay video
- Human support, response within 12 hours
- Company Org, departments and multi-user governance are not included

Yearly: £18,500 — two months free. Billed once a year.
```

## Metadata — every product

Type har row mein **String**:

| Key | Personal Basic | Personal Pro+ | Personal Premium |
|---|---|---|---|
| `brand` | `anexomail` | `anexomail` | `anexomail` |
| `kind` | `plan` | `plan` | `plan` |
| `account_kind` | `personal` | `personal` | `personal` |
| `plan` | `basic` | `pro` | `business_pro` |
| `billing_cycle` | `monthly` or `yearly` | `monthly` or `yearly` | `monthly` or `yearly` |

## IDs banne ke baad

1. Six IDs ko `/opt/anexomail/.env` aur `/opt/polar-rust-payment/.env` mein matching environment keys ke saath rakho. Secret/token print mat karo.
2. `docs/cursor-work/sql/E13_personal_polar_products.sql` mein six `REPLACE_..._ID` values ko exact Polar IDs se replace karke Supabase #4 SQL Editor mein poori file run karo.
3. Repo file mein actual IDs commit mat karo jab tak founder unhein public product IDs ke taur par lock na kare.
4. Deploy ke baad Personal account se monthly/yearly checkout test karo. Business account se Personal key ka response `403` hona chahiye.

Checkout existing route use karta hai: `POST /api/billing/intent`. Frontend amount ya product ID nahi bhejta; backend registry aur database exact price enforce karte hain.