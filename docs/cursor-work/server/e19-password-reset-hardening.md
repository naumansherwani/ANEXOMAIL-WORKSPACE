> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# E19 — password reset: no raw Supabase link, atomic token, rate limit (13 Oct 2026)

Founder tested "forgot password" live and got mailed a link to
`https://<project-ref>.supabase.co/auth/v1/verify?token=...&type=recovery&redirect_to=...`
— the backend vendor's raw domain, shown directly to an ANEXOMAIL user. Not
professional, and avoidable: the code already had a clean, branded link
system built (`account_recovery_tokens` + `https://anexomail.com/auth?mode=reset&recovery=...`)
but it was wired as the **error fallback** instead of the default, so the
common/success path sent Supabase's raw link instead.

## Root cause

`server/routes/auth.ts` `/forgot-password`:
1. Always called Supabase's `auth.admin.generateLink({ type: "recovery" })` first.
2. Only used the branded `account_recovery_tokens` path if that call *failed*.
3. On success (the normal case), it mailed `linkData.properties.action_link`
   — Supabase's raw `*.supabase.co/auth/v1/verify` URL — straight to the user.
4. No rate limit at all on reset requests.
5. `/reset-password`'s recovery-token branch did a `SELECT` then a separate
   `UPDATE` to mark a token used — a race window where two requests with the
   same link could both pass the check before either claimed it.

## Fix

- `server/routes/auth.ts` `/forgot-password`: removed `generateLink()` /
  `resetPasswordForEmail()` entirely from this path. It now **always** issues
  its own token and mails only `https://anexomail.com/auth?mode=reset&recovery=...`.
  Added a rate check (`password_reset_rate_ok`, max 5/hour/user) before
  issuing a new token. Unknown email still returns `{ ok: true }` (no
  enumeration leak).
- `server/routes/auth.ts` `/reset-password`: the recovery-token branch now
  calls `consume_password_reset_token` (one atomic `UPDATE ... RETURNING`),
  replacing the old SELECT-then-UPDATE race.
- `docs/cursor-work/sql/E19_password_reset_hardening.sql`:
  - `account_recovery_tokens` gets a `created_at` column (needed for rate
    limiting; the table itself is in the locked `phase63_f3a_passkey_family.sql`
    and was not touched — only `alter table add column if not exists`).
  - `password_reset_rate_ok(_user_id)` — read-only check, 5/hour cap.
  - `consume_password_reset_token(_token_hash)` — atomic claim.
  - `cleanup_password_reset_tokens()` — housekeeping, deletes rows expired
    more than a day ago (not scheduled yet — call manually or wire to a cron
    later if needed).

The Supabase-session `access_token` branch in `/reset-password` is untouched
(kept for any other Supabase-session-based flow); `generateLink`/
`resetPasswordForEmail` are simply no longer called anywhere in this file.

## Verify (zaroori, deploy ke baad)

1. `E19_password_reset_hardening.sql` Supabase #4 SQL Editor mein paste → Run.
2. Server deploy — same specific-file pattern as E18 (`auth.ts` already
   carries both E18 and E19 changes together, one file).
3. Live test: "forgot password" → email body mein **sirf**
   `https://anexomail.com/auth?mode=reset&recovery=...` ho, koi
   `supabase.co` link na ho.
4. Reset the password via that link, confirm login with the new password.
5. Click the same link twice — second attempt should say "invalid or expired".

**Status:** READY (repo mein, Supabase + server par abhi deploy/verify nahi
hui — Rule 5).
