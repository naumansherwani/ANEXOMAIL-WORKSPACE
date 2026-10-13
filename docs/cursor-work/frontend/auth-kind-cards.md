# Auth — Create your account for workspace (login UX)

**Status:** READY (repo). **DONE** nahi jab tak live login + kind cards founder dekhe.

Polar / `plans.ts` / landing cards **no-touch**. `/plans` landing pe rehta hai. Login footer se **nahi**.

## Lovable pehle se (rakhha)

Signup POST `/api/auth/signup` — yahi fields:

- Full legal name, display name
- Work role + photo URL (optional, collapsed)
- Email, password 6–15, confirm
- Recovery kind + recovery email (SMS nahi)
- Device vault + family skip
- Passkey enrol after signup (awam)
- Then `/claim` → `@anexomail.com` → `/onboarding`

Login: email + password, passkey, magic link, forgot/reset. Social nahi.

## Ab flow (login pe)

1. **Sign in** — mail, people, calendar, work. Passkey / link neeche.
2. **New here? Create your account for workspace** (pehle “Choose your package” → `/plans` tha — hata diya).
3. **Kind cards** — Personal | Business (do columns). Polar SKU nahi.
4. **Create your account** — Lovable form. Kind `preferences.workspace_kind` mein save.
5. Passkey → **`/plans`** → Polar checkout. Payment success: Personal `/dashboard` · Business `/onboarding` (org name + domain). CRM Billing = `/app/billing`.

Masood / Humza **buyers** — is flow se nahi; seedha Sign in.

## Rust lock (next phases)

Naya backend **Rust :3200** `/rpc` + `/wt`. Auth **E2 Bun** rehta hai. Polar webhook no-touch.
