---
name: Phase 32 trial lifecycle
description: 48h trial lock — mandatory @anexomail.com claim, passkey+recovery, DB authority account_state(), AI hard zero, 30-day freeze, idempotent warnings
type: feature
---
LOCKED (founder final, 4 refinements included):
1. Signup social (Google/Apple/GitHub) -> mandatory @anexomail.com claim (skip nahi) -> 48h timer. Trial = Basic features only, AI HARD ZERO (koi complimentary credits nahi).
2. Trial ke andar passkey + recovery account MANDATORY set hote hain (social login 48h baad band).
3. Social login band hone par bhi RECOVERY PATH khula — koi account permanently inaccessible nahi.
4. Header strip factual: "17h 42m left in your trial" — koi red/flashing.
5. Expired -> /trial-ended: See plans + "Already subscribed? Sign in with @anexomail.com".
6. Subscribe (Basic £20/Pro £40/Business £85) -> payment green -> seedha dashboard "Welcome back — continue where you left off" (koi extra onboarding step nahi).
7. Data delete nahi: expired -> 24h baad frozen -> 30 din address reserved -> release. Frozen mailbox ki incoming mail HELD ya REJECTED (`trial_mail_holds`) — kabhi silently discard nahi.
8. Expired/frozen user ko account + billing + recovery access rehta hai, business data (mail/CRM/calendar/work) band.
9. DB = authority: `public.account_state(uuid)` -> {state, hours_left, can_social_login, ai_enabled, business_data, needs_claim/passkey/recovery}. Client timer sirf display. Helpers `entitled_full()` + `ai_enabled()` doosri tables ki RLS mein.
10. Warnings idempotent: `trial_events` unique index (user_id, event_type) for signup/claim/passkey_set/recovery_set/warn_24h/warn_2h/expired/frozen/released. Ledger append-only trigger.
11. Reserved handles table (admin/postmaster/hello/billing/support/leo/jimmy etc) + case-insensitive handle uniqueness.
12. pg_cron hourly `trial_sweep()` (5 * * * *) + cron endpoint POST /api/public/trial/sweep (x-cron-secret: TRIAL_CRON_SECRET).

FILES: sql/phase32_trial.sql · server/routes/trial.ts (mount: app.use("/api/trial", trialRouter); app.use("/api/public", trialCronRouter) — 404 handler se pehle) · src/lib/trial.ts · src/components/app/trial/TrialStrip.tsx (AppShell header ke neeche) · src/routes/trial-ended.tsx · /app gate app.tsx (expired/frozen/released -> /trial-ended).

ENDPOINTS: GET /api/trial/state · GET /api/trial/address?handle= · POST /api/trial/start · POST /api/trial/claim · POST /api/trial/security · POST /api/trial/subscribe (payment_ref required, Polar webhook TODO) · GET /api/trial/events · GET /api/trial/mail-holds · POST /api/public/trial/sweep.
