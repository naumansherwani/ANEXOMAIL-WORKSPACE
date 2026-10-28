
-- E103 — founder_actions catalogue ka title/summary ENGLISH (Rule 67: founder UI ki zubaan English).
-- Technology: Postgres 15+ (Supabase). Sirf text badalta hai: key/deck/danger/enabled/runbook kabhi nahi. E102 ka seed pehle se chal chuka hai.
-- Dobara chalana safe (idempotent). Polar :3400 NO-TOUCH.
set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = public, extensions;

do $$
begin
  if to_regclass('public.founder_actions') is null then
    raise notice 'E103 SKIP: founder_actions nahi mili (pehle E102 chalayein)';
    return;
  end if;
  update public.founder_actions f set title = v.title, summary = v.summary
  from (values
    ('release.pull_web',         'Web pull',               'Pull the new web build and restart (pull.sh)'),
    ('release.run_sql',          'Run SQL (AUTO)',         'sql-run.sh bare: runs only new E-files from the sha ledger'),
    ('release.rust_install',     'Install Rust engine',    'rust-engine-install.sh + restart, rolls back on failure'),
    ('release.rollback',         'Roll back last build',   'Restore the last backed-up binary and web build'),
    ('systems.recheck_health',   'Recheck all health',     'Check Rust, Brain, Caddy, database and queue right now'),
    ('systems.restart_rust',     'Restart Rust engine',    'pm2 restart anexomail-rust + /rpc/health proof'),
    ('mail_desk.requeue_failed', 'Requeue failed mail',    'mail_outbox failed -> queued (with a limit)'),
    ('people.suspend_user',      'Suspend user',           'Block a user (metadata only, never content); a reason is required'),
    ('people.unsuspend_user',    'Unsuspend user',         'End the suspension'),
    ('control.maintenance_on',   'Maintenance mode ON',    'Show customers a clear maintenance page; the founder keeps working'),
    ('control.maintenance_off',  'Maintenance mode OFF',   'Bring customers back'),
    ('control.freeze_signups',   'Freeze new sign-ups',    'Stop new accounts (attack or capacity)')
  ) as v(key, title, summary)
  where f.key = v.key;
end $$;
