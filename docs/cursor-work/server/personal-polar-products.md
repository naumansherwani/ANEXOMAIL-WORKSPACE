# Personal Polar products — copy exactly

**Status: READY.** Public home, `/plans`, Business products aur Rust webhook unchanged hain. **DONE** sirf six IDs, E13 SQL, deploy aur real checkout proof ke baad.

Polar mein har billing interval ka alag recurring product banao. Currency **GBP**.

| Product name                           | Billing | Exact price | Polar product ID                       |
| -------------------------------------- | ------- | ----------: | -------------------------------------- |
| `ANEXOMAIL Personal Basic — Monthly`   | Monthly |         £17 | `485fa38d-1bbd-4136-bd71-eed42121ca5d` |
| `ANEXOMAIL Personal Basic — Yearly`    | Yearly  |        £187 | `e4913e6d-4667-4979-a131-60acc429ec53` |
| `ANEXOMAIL Personal Pro+ — Monthly`    | Monthly |         £83 | `320a2cab-4ae8-47c9-8469-3bae6e342f59` |
| `ANEXOMAIL Personal Pro+ — Yearly`     | Yearly  |        £913 | `a93f0bf2-37aa-45f6-9a8a-fa356d37d59f` |
| `ANEXOMAIL Personal Premium — Monthly` | Monthly |      £1,850 | `cde7edac-a9fb-4cf2-ab6a-8e4154968e52` |
| `ANEXOMAIL Personal Premium — Yearly`  | Yearly  |     £18,500 | `a485e76a-9338-4dfb-b680-7cc3df0adaf8` |

Yeh chhe IDs ab repo mein hain: `server/config/billing-products.ts` aur
`docs/cursor-work/sql/E13_personal_polar_products.sql`. Server par koi Personal
environment line likhne ki zaroorat nahi — Rust `polar-payment` product map
in IDs ko product key se resolve karta hai.

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

| Key            | Personal Basic   | Personal Pro+       | Personal Premium   |
| -------------- | ---------------- | ------------------- | ------------------ |
| `brand`        | `anexomail`      | `anexomail`         | `anexomail`        |
| `kind`         | `plan`           | `plan`              | `plan`             |
| `account_kind` | `personal`       | `personal`          | `personal`         |
| `plan`         | `personal_basic` | `personal_pro_plus` | `personal_premium` |

## Aap sirf yeh karein

1. Supabase #4 SQL Editor mein `docs/cursor-work/sql/E13_personal_polar_products.sql` poori file paste → Run. Verification mein chhe rows `READY` aani chahiye.
2. Locked pull command se web deploy karein.
3. `/plans` par teen Personal cards aur Personal Billing par wahi teen cards check karein.
4. Personal account se monthly/yearly checkout test karein. Business account Personal key par `403` deta hai.

Checkout existing route use karta hai: `POST /api/billing/intent`. Frontend amount ya product ID nahi bhejta; backend registry aur database exact price enforce karte hain.
