# Trial — build plan (jab Founder account ready ho)
Pehle: Pro green -> Founder account. Phir:
1. **SQL** (E9x): plan `trial` (storage_plans 1GB, mailbox 1, send/din 25, attach 10MB, caps), org kind 'trial', account_state ko `trial` + kind, chat_caps calls=false, billing/analytics views `kind<>'trial'`.
2. **Rust** `trialn` module: trial.state (countdown, caps, checklist), trial.start (address claim + provision), trial.convert (keep/fresh), trial.invite (2 guests), gate: sab business procs par 48h ke baad domain error `trial_expired` (4xx, 404 nahi — Rule 59). resolve_plan mein 'trial'.
3. **Realtime:** countdown event WebTransport (poll nahi).
4. **UI:** get-started (cinematic landing hissa Rule 60), trial shell (non-cinematic), checklist, countdown banner, Pro chips, trial-ended -> seedha /plans gate, convert dialog.
5. **Mojooda trialx** (security/events/holds, LIVE) barqarar; trial.ts ke 6 purane endpoints naye module se replace (Bun twin fallback).
6. **Proof:** trial probe (user banao, limits, no-mix test, 48h expiry simulation via SQL clock, convert keep/fresh), Chrome click-through, data-isolation counters.
7. **Founder dashboards:** Trials line alag.
