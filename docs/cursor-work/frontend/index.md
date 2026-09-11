# Frontend — docs/cursor-work/frontend/

Ab se har frontend change ka record yahan.

## Pull + build command (hamesha yahi ek)
```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```

## Status
| File | Kya badla | Status |
|---|---|---|
| src/routes/auth.tsx | Password Eye icon fix | READY — pull se aayega |
| src/lib/api.ts | Error message fix | READY — pull se aayega |
| src/lib/host.ts | isPublicMailHost() | READY — pull se aayega |
| src/components/site/SiteLock.tsx | anexomail.com bypass | READY — pull se aayega |
| src/routes/app.tsx | /app → /auth redirect | READY — pull se aayega |
| src/components/app/AppShell.tsx | Awam nav hide | READY — pull se aayega |
| F3 mail inbox | ThreadList + MailRail + /api/mail/threads + counts | READY — live unproven |
| F3 A family testers | `f3a-family-awam-testers.md` + `sql/phase63_f3a_passkey_family.sql` — WebAuthn store, recovery, family grants | READY — live unproven |
| F3 B awam onboarding | `f3b-awam-onboarding-polish.md` — Personal\|Business, no day-1 domain, claim skip, org API fix | READY — live unproven |
| Personal vs Business kind | Polar SKU alag nahi — `personal-business-kind.md` + `sql/phase65_account_kind.sql` | READY — live unproven |
| Auth kind cards | Login “Choose your package” hata → Create your account for workspace + Personal\|Business cards | READY — live unproven |
| Personal Polar map | `personal-polar-map.md` — paise landing 4 cards; Personal Basic/Pro/Premium = Polar Basic/Pro/Business Pro + kind | READY — live unproven |
| Last name + /dashboard + business domain | Signup last name; personal → `/dashboard`; business org name + domain | READY — live unproven |
