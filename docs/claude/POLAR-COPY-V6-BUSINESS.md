# Polar checkout copy v6 — BUSINESS (DRAFT 27 Oct 2026 02:30 PKT, founder approve baqi) — Rule 55 (per month + user cap), Rule 51 (3 honest tech claims)
Price: £360/month · £3,960/year (1 month free) · up to 60 users · 1.5TB shared · 45MB attachments. Landing `plans.ts` Business card yahi numbers dikhata hai.
**Sirf wahi likha jo repo mein MATCHES-CODE hai** (docs/packages/business/INCLUDES.md). Group calls (GATE-TO-BUILD), codec ladder, rooms, team analytics Polar copy mein NAHI — jab live honge tab jodenge. (Landing card mein abhi inka zikr hai: wahan bhi tab tak "coming" ya hatana hai — alag item.)

## Product edit tareeqa (IDs NAHI badalte — Basic/Pro jaisa)
Polar → Products → `ANEXOMAIL Business` (Monthly) → Price **£360** → Description niche wali → Save. Phir `ANEXOMAIL Business` (Yearly) → Price **£3,960** → yearly description. Product ID wohi rehti hai, isliye server `.env` / `polar-product-ids-update.sh` ki zaroorat NAHI. (Agar naya product banate hain to naya UUID `POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY/YEARLY` ke saath polar-product-ids-update.sh se.) Metadata: `brand=anexomail kind=plan plan=business account_kind=business`.
Purane £97/£970 par jo pehle se subscribe hain unka price Polar khud purana rakhta hai (grandfathered) — naya checkout £360 par jayega.

## Monthly — £360
```text
Company email with control, governance and chat for growing companies.

£360 per month for the whole company, with a cap of 60 users. We never charge per-user fees.

- Everything in Pro
- Every app and feature listed here is included. There are no charges for any app and nothing extra to buy.
- Up to 60 users and 1.5TB of shared storage for the whole company
- Roles and departments, with a policy simulator before a rule goes live
- Audit ledger of who did what, and one-click access revocation
- One-click data export, so your data leaves whenever you want
- ANEXOChat included: messages with honest delivery status, files, voice notes and relay video calls
- Message to Task, Promise or Decision with owner and deadline, with no AI involved
- Promise recovery: remind, or move a deadline with a written reason that stays on record
- Message provenance: sender, workspace and exact UTC time on every message
- File evidence chain and self-hosted malware scanning, with no external service
- Device trust list with one-click revoke
- Email attachments up to 45MB
- Human support, with a response within 24 hours

Built on modern infrastructure:
- Large attachments go straight through, with no waiting and no broken uploads.
- Fast at peak hours, because the engine behind your mail is built in Rust to handle many requests at once.
- Reliable by design: a problem in one part never takes down the whole workspace.
```

## Yearly — £3,960 (Get 1 month free)
Same text, second paragraph:
`£3,960 per year for the whole company (one month free), with a cap of 60 users. We never charge per-user fees.`
and final line after the technology block: `Billed once a year. Cancel at renewal.`

## Test (live, chhota order) — Basic/Pro jaisa
1. Business account (business.test) → /app/billing → Business monthly checkout → Polar page par **£360.00** dikhe, "per user" na likha ho.
2. Polar sandbox/test card se pay → webhook → account plan=business, billing page "Business £360".
3. Pehle purane Business buyers (£97) ko koi asar nahi — sirf naye checkout.
