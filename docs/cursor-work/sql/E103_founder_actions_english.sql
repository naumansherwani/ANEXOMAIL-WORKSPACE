
-- E103 — FOUNDER ACTION CATALOGUE (super advanced): English text + SAFETY RATCHET + tamper-proof guard trigger + selftest.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase). E102 ka `founder_actions` (one-click catalogue) pehle se maujood; yeh sirf use mazboot karta hai.
--   1) Preflight        — E102 maujood na ho to saaf SKIP (kuch toota nahi). Advisory lock: do migration ek saath nahi.
--   2) Columns          — updated_at (har badlav ka waqt) + text_rev (kitni baar text badla) — audit/UI ke liye asli data.
--   3) English text     — Rule 67 (founder UI ki zubaan English): 12 actions ke title/summary. `IS DISTINCT FROM` => sirf jo badle usi par likhna;
--                         kitni rows badli RAISE NOTICE se. Dobara chalane par 0 rows (idempotent).
--   4) Text constraint  — title 3..60, summary 3..200, sirf printable ASCII. NOT VALID pehle, text theek karne ke BAAD VALIDATE (purani Roman-Urdu rows
--                         migration ko na rokein, aur nayi kabhi na ghusein).
--   5) SAFETY RATCHET   — BEFORE UPDATE trigger: key/deck badalna band; danger sirf BADH sakta hai (low<medium<high); needs_passkey / two_tap sirf
--                         false->true; reversible sirf true->false. Matlab: kisi ne service_role chaabi chura bhi li to "khatarnak kaam ko aasaan"
--                         karne ka raasta DB se band (sirf superuser trigger hata sakta hai — aur yeh CHECK mein pakda jata hai). `enabled` (F8) azad.
--   5b) DELETE/TRUNCATE  — Supabase default privileges service_role ko DELETE dete hain: revoke + trigger (warna delete+reinsert se ratchet bypass).
--   6) Selftest         — founder_actions_selftest(): ratchet + constraint + delete-block + valid badlav sab try, aakhir mein poora rollback, kuch persist nahi.
-- PRIVACY: yahan koi user data nahi. Dobara chalana safe. Polar :3400 NO-TOUCH.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = public, extensions;

do $$
declare v_changed int := 0;
begin
  if to_regclass('public.founder_actions') is null then
    raise notice 'E103 SKIP: founder_actions nahi mili (pehle E102 chalayein)';
    return;
  end if;
  perform pg_advisory_xact_lock(hashtext('founder_actions_catalogue'));

  -- 2) columns
  alter table public.founder_actions add column if not exists updated_at timestamptz not null default now();
  alter table public.founder_actions add column if not exists text_rev   integer     not null default 1;

  -- 3) English text (key se; sirf jo badle)
  with v(key, title, summary) as (values
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
  ), u as (
    update public.founder_actions f
       set title = v.title, summary = v.summary, text_rev = f.text_rev + 1, updated_at = now()
      from v
     where f.key = v.key and (f.title is distinct from v.title or f.summary is distinct from v.summary)
    returning 1
  )
  select count(*) into v_changed from u;
  raise notice 'E103: % action(s) ka text English kiya', v_changed;
end $$;

-- 4) text constraint (NOT VALID -> VALIDATE; sirf tab jab table maujood)
do $$
begin
  if to_regclass('public.founder_actions') is null then return; end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_actions_text_ascii' and conrelid = 'public.founder_actions'::regclass) then
    alter table public.founder_actions
      add constraint founder_actions_text_ascii
      check (title ~ '^[ -~]{3,60}$' and summary ~ '^[ -~]{3,200}$') not valid;
  end if;
  alter table public.founder_actions validate constraint founder_actions_text_ascii;
end $$;

-- 5) SAFETY RATCHET trigger
create or replace function public.founder_actions_guard() returns trigger
language plpgsql set search_path = public as $$
declare
  rk constant jsonb := '{"low":1,"medium":2,"high":3}';
begin
  if new.key is distinct from old.key or new.deck is distinct from old.deck then
    raise exception 'founder_actions: key/deck badal nahi sakte (%)', old.key using errcode = '42501';
  end if;
  if (rk ->> new.danger)::int < (rk ->> old.danger)::int then
    raise exception 'founder_actions: danger kam nahi ho sakta (% : % -> %)', old.key, old.danger, new.danger using errcode = '42501';
  end if;
  if (old.needs_passkey and not new.needs_passkey) or (old.two_tap and not new.two_tap) then
    raise exception 'founder_actions: passkey/two-tap band nahi ho sakta (%)', old.key using errcode = '42501';
  end if;
  if (not old.reversible) and new.reversible then
    raise exception 'founder_actions: irreversible ko reversible nahi likh sakte (%)', old.key using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke all on function public.founder_actions_guard() from public, anon, authenticated;

do $$
begin
  if to_regclass('public.founder_actions') is null then return; end if;
  drop trigger if exists founder_actions_guard_upd on public.founder_actions;
  create trigger founder_actions_guard_upd before update on public.founder_actions
    for each row execute function public.founder_actions_guard();
end $$;

-- 5b) DELETE/TRUNCATE band: warna "delete + naya insert" se ratchet bypass ho jata (Supabase default privileges service_role ko DELETE bhi dete hain)
create or replace function public.founder_actions_no_delete() returns trigger
language plpgsql set search_path = public as $$
begin
  raise exception 'founder_actions: delete/truncate band hai (catalogue sirf badhta/mazboot hota hai)' using errcode = '42501';
end $$;
revoke all on function public.founder_actions_no_delete() from public, anon, authenticated;

do $$
begin
  if to_regclass('public.founder_actions') is null then return; end if;
  revoke delete, truncate, references, trigger on public.founder_actions from service_role, anon, authenticated;
  drop trigger if exists founder_actions_no_del on public.founder_actions;
  create trigger founder_actions_no_del before delete on public.founder_actions
    for each row execute function public.founder_actions_no_delete();
  drop trigger if exists founder_actions_no_trunc on public.founder_actions;
  create trigger founder_actions_no_trunc before truncate on public.founder_actions
    for each statement execute function public.founder_actions_no_delete();
end $$;

-- 6) selftest (poora rollback; kuch persist nahi)
create or replace function public.founder_actions_selftest() returns text
language plpgsql security definer set search_path = public as $$
begin
  if to_regclass('public.founder_actions') is null or not exists (select 1 from public.founder_actions where key = 'release.rollback') then
    return 'E103 selftest SKIP — catalogue khali';
  end if;
  -- a) danger kam karna roka jaye
  begin update public.founder_actions set danger = 'low' where key = 'release.rollback';
        raise exception 'E103 FAIL: danger kam ho gaya';
  exception when insufficient_privilege then null; end;
  -- b) passkey band karna roka jaye
  begin update public.founder_actions set needs_passkey = false where key = 'release.rollback';
        raise exception 'E103 FAIL: needs_passkey band ho gaya';
  exception when insufficient_privilege then null; end;
  -- c) two-tap band karna roka jaye
  begin update public.founder_actions set two_tap = false where key = 'release.rollback';
        raise exception 'E103 FAIL: two_tap band ho gaya';
  exception when insufficient_privilege then null; end;
  -- d) key badalna roka jaye
  begin update public.founder_actions set key = 'release.rollback2' where key = 'release.rollback';
        raise exception 'E103 FAIL: key badal gayi';
  exception when insufficient_privilege then null; end;
  -- e) non-ASCII / lamba text roka jaye
  begin update public.founder_actions set title = 'Wapas — £' where key = 'systems.recheck_health';
        raise exception 'E103 FAIL: non-ASCII title chala gaya';
  exception when check_violation then null; end;
  begin update public.founder_actions set summary = repeat('x', 201) where key = 'systems.recheck_health';
        raise exception 'E103 FAIL: lamba summary chala gaya';
  exception when check_violation then null; end;
  -- e2) delete roka jaye (warna delete+reinsert se ratchet bypass)
  begin delete from public.founder_actions where key = 'release.rollback';
        raise exception 'E103 FAIL: delete chal gaya';
  exception when insufficient_privilege then null; end;
  -- f) jaiz badlav chalta hai (danger BADHANA + text), phir rollback
  begin
    update public.founder_actions set danger = 'high', title = 'Restart Rust engine (x)' where key = 'systems.restart_rust';
    if not found then raise exception 'E103 FAIL: jaiz badlav nahi hua'; end if;
    raise exception 'E103_ROLLBACK';
  exception when others then
    if sqlerrm <> 'E103_ROLLBACK' then raise; end if;
  end;
  return 'E103 selftest OK';
end $$;
revoke all on function public.founder_actions_selftest() from public, anon, authenticated;
grant execute on function public.founder_actions_selftest() to service_role;

comment on function public.founder_actions_guard() is 'E103 safety ratchet: danger/passkey/two-tap sirf mazboot ho sakte hain, key/deck immutable.';
comment on constraint founder_actions_text_ascii on public.founder_actions is 'E103: English UI text, printable ASCII, title 3..60, summary 3..200 (Rule 67).';
