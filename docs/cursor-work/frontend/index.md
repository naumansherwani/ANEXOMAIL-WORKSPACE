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
