# ANEXOMAIL Autonomous Billing State Mesh (ABSM) — Phase 49

Killer invariant (locked):

> Koi bhi webhook, network failure, provider delay, ya node failure — akela canonical
> billing state ko ghalat ya permanently unrecoverable nahi bana sakta.

## Authority map

| Layer | Role |
| --- | --- |
| Polar | external provider — sirf **observation** |
| Webhook | fast signal — **authority nahi** |
| Supabase #4 | **canonical truth** |
| QUIC (Server 1 ↔ Server 2) | internal transport — outbox/inbox ke peeche |
| Reconciliation engine | recovery brain (P0…P4) |
| Receipts | immutable financial evidence |

## SQL (Supabase #4 SQL editor)

`sql/phase49_absm_billing_mesh.sql` — idempotent. Deta hai:

- `billing_intents` upgrade: guest checkout (`guest_token`, `guest_email`), `fsm_state`,
  `state_version`, `state_hash`, `trace_id`, `expires_at`
- observation layer: `billing_observations` (webhook | pull | manual, `signature_ok`)
- versioned state: `billing_state_versions` + `billing_state_hash()` (SHA-256)
- QUIC durability: `billing_outbox`, `billing_inbox` (`message_id` unique, at-least-once)
- reconciliation: `billing_reconciliation_runs` (single-flight lease), `_items`,
  `billing_watermarks`, `billing_failures`
- evidence: `billing_receipts` (unique per `intent_id + state_version`)
- adaptive queue: view `billing_reconcile_queue` (priority + `poll_seconds` 5s→1h)
- radar: view `billing_mesh_health`

### State machine

```
CREATED → CHECKOUT_OPEN → PAYMENT_PENDING → PAYMENT_CONFIRMED → SUBSCRIPTION_ACTIVE
                              ├── EXPIRED / FAILED / CANCELLED
ACTIVE → PAST_DUE | PAUSED | CANCELLED | REFUNDED
```

Transition sirf `billing_state_apply()` se hoti hai: version++ → hash → outbox → receipt.

### Never activate from webhook alone

Activation ke liye lazmi: provider observation + expected intent + amount match +
currency match + product match + customer/guest-token match + idempotency.
Webhook signature fail → observation `signature_ok=false`, process **nahi**;
reconciliation asli state khud dhoond leta hai.

## Guest checkout (sign-in redirect khatam)

- `POST /api/public/billing/guest-intent { product_key, seats }` → Supabase mein
  guest intent (truth pehle) → Polar checkout URL. Sign-in ki zaroorat nahi.
- Sign-in ke baad frontend `POST /api/billing/claim-guest { guest_token }` bhejta hai →
  `billing_guest_intent_claim()` intent ko user se jodta hai aur paid ho to entitlement lagata hai.
- Claim fail ho jaye to bhi paisa lost nahi: sweep + reconciliation baad mein jod deta hai.

## Cron (Supabase pg_cron ya server cron)

```
* * * * *  hot/warm sweep   → POST /api/public/billing/sync   (header x-anexomail-cron: $CRON_SECRET)
0 * * * *  cold sweep       → same endpoint
0 3 * * *  daily safety     → same endpoint
```

## Failure matrix

| Fail | Nateeja |
| --- | --- |
| Webhook dead | reconciliation Polar API se state le aata hai |
| Signature broken | observation logged, process nahi, reconcile recover |
| QUIC dead | outbox pending rehta hai, wapas aane par replay |
| Server 2 dead | state Supabase mein safe, queued execution |
| Server 1 dead | reconciliation Server 2 side se chalti rehti hai |
| Polar down | last canonical state retained + retry |
| Duplicate webhook | idempotency key → no duplicate grant |

## Monitoring

```sql
select * from public.billing_mesh_health;
select * from public.billing_reconcile_queue where priority in ('P0','P1');
```

`p0_paid_without_entitlement > 0` = paisa aaya, entitlement nahi — sab se pehle yeh fix hota hai.
