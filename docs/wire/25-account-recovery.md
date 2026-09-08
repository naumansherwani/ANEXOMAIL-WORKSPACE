# 25 — Account recovery and Brain sync

Status: READY

## One command

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-all.sh
```

The command now applies phase57, phase58, phase59, then phase56; verifies the live v59 mail contract; builds the web app; and syncs the Brain API without touching `.env`.

## Safety stop

`server/deploy-brain.sh` checks every route imported by `server/index.ts` before restarting PM2. Existing valid modules under `/opt/anexomail/src/routes` are preserved. If any required module is absent from both the repo and the existing Brain installation, deployment stops with `RED Brain import missing` instead of replacing a working process with a broken one.

## Account contract restored

- Signup: legal name, display name, optional role/avatar/preferences, strong password, email confirmation.
- Login, session, logout and revocable device sessions.
- Forgot, reset and signed-in password change.
- Magic-link send and PKCE callback exchange.
- Profile, organisation membership and session storage from phase59.
- Founder/public role data stays outside the profile row.

## Proof required for DONE

```bash
curl -sS http://127.0.0.1:3100/api/health
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3100/api/auth/session
bash server/gates/mail-gate.sh
postqueue -p
```

Expected: health JSON with `ok:true`, unauthenticated session `401`, mail gate PASS-only, and an empty queue. Browser proof must separately cover signup confirmation, login, forgot/reset/change password and every protected-route redirect; READY is not DONE until those live checks pass.