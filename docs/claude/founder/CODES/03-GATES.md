# 03 GATES — founder pehchan ke 7 alag tareeqe (sab purane, ek jaisa nahi)
| # | Jagah | Kaise pehchanta hai |
|---|---|---|
| 1 | server/lib/founder-gate.ts (+core) | FOUNDER_EMAILS email YA founder_accounts, `admin.auth.getUser` network call |
| 2 | server/routes/founder.ts ctx() | apni FOUNDER_EMAILS copy + founder_accounts |
| 3 | server/routes/org.ts founderGuard | FOUNDER_EMAILS (org-authz) + founder_accounts |
| 4 | server/routes/crm.ts founderOnly | alag check |
| 5 | server/routes/billing-support.ts requireFounder | sirf founder_accounts (sahi tareeqa) |
| 6 | server/routes/analytics.ts who() | FOUNDERS email list + getUser |
| 7 | server/routes/auth.ts ~790 | FOUNDER_PASSWORD login path (LOOPHOLE) |
Awam client: src/lib/host.ts isFounderHost() = founderworkspace.* (+ localhost, lovable.app) ; SiteLock.tsx founder host open; auth.tsx `is_founder` flag.
**Naya gate:** Rust authed(): Bearer ES256 JWT local verify (JWKS) + uid in founder_accounts. 401/403. Bas yehi ek rakhna hai (FC3).
