Anexomail - Architecture (stable facts, rarely changes)

WHICH CODEBASE IS LIVE (check this every time - this has caused bugs before):
- /opt/anexomail-web/ = frontend (React/SSR). PM2 process anexomail-web runs
  .output/server/index.mjs. UI changes (src/routes, src/lib) go here and
  need: cd /opt/anexomail-web && bun run build:bun, then pm2 restart
  anexomail-web.
- /opt/anexomail/ = backend API. The bun process listening on port 3100
  (the /api/* routes: crm, mail, work, calendar) is the PM2 process
  anexomail-leo, started from /opt/anexomail. Backend route changes go in
  /opt/anexomail/src/routes/*.ts, then pm2 restart anexomail-leo. No build
  step is needed.
- WARNING: /opt/anexomail-web/server/routes/*.ts is NOT what port 3100 runs.
  Editing it has no effect on the live API. Past fixes made only there never
  went live.
- Unknown / still to confirm: whether ai.anexomail.com uses the same
  anexomail-leo process.
- /opt/anexomail-rust/ = Rust/Axum/Tokio backend, shared by both. PM2
  process anexomail-rust. Rule: all new backend work goes here, not Bun.

To verify which process owns a port and which folder it runs from:
ss -ltnp | grep ':3100'
pm2 pid anexomail-leo
pm2 describe anexomail-leo | grep "exec cwd"

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

BACKUP RULE (owner, 2026-10-07): ALWAYS back up before changing anything.
- Frontend builds: run /root/bin/safe-build-web.sh, never bare bun run build:bun. It saves the
  source, saves the old .output, and restores the old .output if the new build fails.
  (A failed build deletes .output/public/assets and leaves the live site without JS and CSS.)
- Any file edit: cp the file to file.bak-<name> first, or take a tar into /root/backups.
- Backups live in /root/backups. Full backup command: tar the source folders (not node_modules,
  target, .output) plus pg_dump --schema-only.
- Large code pasted through a terminal can lose text that starts with <. Give big files in small
  pieces and check after each piece.
