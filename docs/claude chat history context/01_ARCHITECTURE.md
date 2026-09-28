Anexomail - Architecture (stable facts, rarely changes)

WHICH CODEBASE IS LIVE (check this every time - this has caused bugs before):
- /opt/anexomail-web/ = REFERENCE / DEV COPY ONLY. Editing this has ZERO
  effect on the live site. A real bug once got "fixed" here by mistake
  while production stayed broken.
- /opt/anexomail/ = LIVE codebase. PM2 process anexomail-leo runs this.
  Every production fix MUST land here.
- /opt/anexomail-rust/ = Rust/Axum/Tokio backend. PM2 process
  anexomail-rust. Rule: all new backend work goes here, not Bun.

To verify which file a running process actually uses:
pm2 describe anexomail-leo | grep "script path"

REQUEST FLOW:
Frontend calls /rpc/* (Rust) first via rpcOrRest() helper. If Rust 404s,
it automatically falls back to /api/* (legacy Bun REST). Migrating a
route to Rust can never break the site mid-migration.

DATABASE:
Supabase / Postgres, RLS enabled everywhere. Heavy logic lives in
PL/pgSQL functions, called via service_role only. Rust helpers:
sb_rpc(), sb_select(), sb_patch(), sb_insert(), sb_upsert().
dispatch_crm(), dispatch_work(), dispatch_mail() in main.rs route a
"proc" name like "crm.contacts.recompute" to its handler.

DEPLOY PATTERN (every change follows this):
1. Edit file - usually via python3 heredoc or base64 patch script with
   exact string assert/replace.
2. Build: Rust = cd /opt/anexomail-rust && cargo build --release
          Frontend = cd /opt/anexomail-web && bun run build:bun
          (AND repeat on /opt/anexomail if it needs to be LIVE)
3. Deploy: pm2 restart <process> --update-env && pm2 save
4. Confirm live with curl - login via Supabase auth, hit the real
   /rpc/* or /api/* endpoint, check the JSON.

PLAN / ACCOUNT MODEL:
WorkspacePlanId: basic | pro | business | business_pro
AccountKind: personal | business
Personal accounts get Business-tier feature power at Pro price point.
resolveAccountKind() / featurePlan() in plan-surface.ts decide what a
user can see.

FRONTEND CONVENTIONS:
React + TypeScript, TanStack Query. lib/crm.ts, lib/mail.ts, lib/calendar.ts
hold typed hooks (useQuery/useMutation wrapping rpc()/rpcOrRest()/get()).
FeatureGate component handles plan-gated UI (variants: lock/wall/chip/hidden).
i18n via useLocale() -> t().

TEST ACCOUNTS:
masoodsherwani@anexomail.com = plan business, kind personal (Personal Pro+)
humzasherwani@anexomail.com = business_pro
anexomail27@gmail.com = basic (for gating tests)
Supabase project ref: katnpxawvzrgqdixlqfl

SECURITY NOTE:
Raw DB connection strings and passwords have been typed directly in
terminal sessions repeatedly. Before pushing code to GitHub (even
private), grep for and remove hardcoded secrets:
grep -rn "postgresql://" /opt/anexomail /opt/anexomail-rust --include="*.ts" --include="*.rs"
Keep real secrets in .env (gitignored), never in this docs system.
