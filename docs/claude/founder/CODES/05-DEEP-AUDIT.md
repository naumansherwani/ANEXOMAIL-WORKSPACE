# 05 DEEP AUDIT (code parh kar, 28 Oct 2026)
## Critical
- C1 auth.ts FOUNDER_PASSWORD: env password match par `updateUserById` se password overwrite + `createUser(email_confirm)` + founder_accounts upsert, awam login se. Founder identity env-secret par tiki. Fix F1a.
- C2 Founder login awam login se hota hai (mfaGate hai, passkey step-up founder-specific nahi).
## High
- H1 7 gate tareeqe (03-GATES); 4 jagah FOUNDER_EMAILS defaults mein founder emails hard-coded (naumansherwani.founder@anexomail.com, @nexatect.com) — email-trust.
- H2 Gate har call GoTrue `getUser` network; GoTrue down = founder band; Rust local verify.
- H3 Founder writes bina audit: provision, ai-mail approve, org kill-switch, impersonate, movein transition/rollback/invoice/dns, release lock/roadmap/run, storage/volume, crm/toggle.
- H4 `/founder/org/impersonate` — founder awam user ban sakta hai; audit + passkey + two-tap lazmi hona chahiye (E102 mein high-danger action).
## Medium
- M1 `safe()` / try-catch{} khali (org.ts, crm.ts, founder.ts): error par fake khali/0.
- M2 rpcOrRest fallback (src/lib/founder.ts): alag authz raasta.
- M3 org.ts har request par 3 tables try karta hai (org_members, organization_members, memberships) — schema ambiguity.
- M4 analytics.ts in-memory rate limit (restart par reset, multi-process mein alag).
- M5 Naya Rust audit.rs hash DB v1 se alag (target/meta nahi) — align karo.
- M6 Passkey step-up aur browser mein sig verify (F1a/F2b) abhi nahi.
## Low / design
- L1 FounderBar awam bundle; preview flag localStorage.
- L2 /founder redirects bina auth (aage guard hai).
- L3 Do founder hosts (founderworkspace.* purana, founder.* naya) — Caddy allowlist alag.
## Jo THEEK hai (rakho)
- index.ts founderGate sab se pehle + index.order.test.ts guard.
- billing-support requireFounder sirf founder_accounts.
- E102: audit append-only triggers, service_role select+insert only, 12 actions seed disabled, CHECK_E102 9/9 OK.
## Server status (aap ke output se)
E102 green (9/9). Founder service + SPA 200/healthz 200 (127.0.0.1:3210). Naya binary (decks/actions/audit) install baqi; DNS+Caddy baqi.
