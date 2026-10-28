
-- E102 — FOUNDER ENGINE (super advanced): append-only audit chain + one-click action catalogue + approved devices.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase). Rust `anexomail-founder` sirf service_role se likhta/padhta hai; awam ke liye koi policy NAHI (RLS on, default deny).
--   1) founder_audit      — append-only, SHA-256 hash chain (hash format v1 neeche), advisory-lock se serial (do likhne wale chain nahi todte),
--                           UPDATE / DELETE / TRUNCATE trigger se band (service_role bhi nahi kar sakta; sirf superuser trigger hata sakta hai — aur yeh verify mein pakda jata hai)
--   2) founder_audit_sig  — alag insert-only table: Rust ka HMAC-SHA256(hash) (kunji DB mein NAHI). Browser kernel (Rule 52) chain + sig verify karta hai.
--   3) founder_audit_append()  — EK hi likhne wala darwaza: wajah (reason) kam az kam 8 akshar, action/target saaf, meta clamp.
--   4) founder_audit_verify()  — poori chain DB mein dobara hisaab: pehli kharabi ka seq (null = saaf). founder_audit_head() = aakhri hash.
--   5) founder_actions    — ONE-CLICK catalogue: har action ka deck, khatra-darja, passkey lazmi?, do-tap?, enabled (seed sab DISABLED; executor F8 mein).
--   6) founder_devices    — naya device purane approved device se manzoor hone tak band (passkey + device approval + IP allowlist protocol).
--   7) selftest (AAKHIR MEIN poora rollback).
-- HASH FORMAT v1: sha256( lp(prev_hash) || lp(seq) || lp(actor) || lp(action) || lp(target) || lp(reason) || lp(ts_ms) || lp(meta_text) ), lp(x) = 4-byte big-endian length || utf8 bytes.
-- PRIVACY (locked): audit mein mail/file ka CONTENT kabhi nahi — sirf kis ne, kya, kis par, wajah, metadata.
-- Dobara chalana safe. Polar :3400 NO-TOUCH.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = public, extensions;

create extension if not exists pgcrypto with schema extensions;

-- ===============================================================================================================
-- 1) founder_audit
-- ===============================================================================================================
create table if not exists public.founder_audit (
  seq        bigint generated always as identity primary key,
  ts_ms      bigint      not null,
  actor      uuid        not null,
  action     text        not null check (length(action) between 3 and 80),
  target     text        not null default '' check (length(target) <= 200),
  reason     text        not null check (length(reason) between 8 and 500),
  meta       jsonb       not null default '{}'::jsonb,
  prev_hash  text        not null check (prev_hash ~ '^[0-9a-f]{64}$'),
  hash       text        not null unique check (hash ~ '^[0-9a-f]{64}$')
);
create index if not exists founder_audit_actor_idx  on public.founder_audit (actor, seq desc);
create index if not exists founder_audit_action_idx on public.founder_audit (action, seq desc);

create table if not exists public.founder_audit_sig (
  seq  bigint primary key references public.founder_audit(seq),
  sig  text   not null check (sig ~ '^[0-9a-f]{64}$'),
  at   timestamptz not null default now()
);

alter table public.founder_audit     enable row level security;
alter table public.founder_audit_sig enable row level security;
revoke all on public.founder_audit, public.founder_audit_sig from public, anon, authenticated;
grant select, insert on public.founder_audit, public.founder_audit_sig to service_role;
-- Supabase default privileges service_role ko sab kuch dete hain: audit par UPDATE/DELETE/TRUNCATE saaf hata do (trigger ke upar doosri deewar)
revoke update, delete, truncate, references, trigger on public.founder_audit, public.founder_audit_sig from service_role;

create or replace function public._fa_lp(t text) returns bytea language sql immutable as $$
  select int4send(octet_length(convert_to(coalesce(t, ''), 'UTF8'))) || convert_to(coalesce(t, ''), 'UTF8')
$$;

create or replace function public._fa_hash(p_prev text, p_seq bigint, p_actor uuid, p_action text, p_target text, p_reason text, p_ts bigint, p_meta jsonb)
returns text language sql immutable as $$
  select encode(extensions.digest(
    public._fa_lp(p_prev) || public._fa_lp(p_seq::text) || public._fa_lp(p_actor::text) || public._fa_lp(p_action)
    || public._fa_lp(p_target) || public._fa_lp(p_reason) || public._fa_lp(p_ts::text) || public._fa_lp(p_meta::text), 'sha256'), 'hex')
$$;

-- append-only: koi UPDATE / DELETE / TRUNCATE nahi
create or replace function public._fa_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'founder_audit append-only hai (% band)', tg_op using errcode = '42501';
end $$;
drop trigger if exists founder_audit_no_upd on public.founder_audit;
create trigger founder_audit_no_upd before update or delete on public.founder_audit for each row execute function public._fa_immutable();
drop trigger if exists founder_audit_no_trunc on public.founder_audit;
create trigger founder_audit_no_trunc before truncate on public.founder_audit for each statement execute function public._fa_immutable();
drop trigger if exists founder_audit_sig_no_upd on public.founder_audit_sig;
create trigger founder_audit_sig_no_upd before update or delete on public.founder_audit_sig for each row execute function public._fa_immutable();

-- ===============================================================================================================
-- 3) founder_audit_append — ek hi darwaza; advisory lock => chain serial
-- ===============================================================================================================
create or replace function public.founder_audit_append(p_actor uuid, p_action text, p_target text, p_reason text, p_meta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prev text; v_seq bigint; v_ts bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_hash text; v_meta jsonb;
begin
  if p_actor is null then raise exception 'actor lazmi'; end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'actor founder nahi' using errcode = '42501'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'wajah (reason) kam az kam 8 akshar'; end if;
  v_meta := coalesce(p_meta, '{}'::jsonb);
  if octet_length(v_meta::text) > 4000 then raise exception 'meta bohat bara (4000 byte tak)'; end if;
  perform pg_advisory_xact_lock(hashtext('founder_audit_chain'));
  select hash into v_prev from public.founder_audit order by seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  select coalesce(max(seq), 0) + 1 into v_seq from public.founder_audit;
  v_hash := public._fa_hash(v_prev, v_seq, p_actor, btrim(p_action), coalesce(btrim(p_target), ''), btrim(p_reason), v_ts, v_meta);
  insert into public.founder_audit (seq, ts_ms, actor, action, target, reason, meta, prev_hash, hash)
    overriding system value values (v_seq, v_ts, p_actor, btrim(p_action), coalesce(btrim(p_target), ''), btrim(p_reason), v_meta, v_prev, v_hash);
  return jsonb_build_object('seq', v_seq, 'hash', v_hash, 'prev_hash', v_prev, 'ts_ms', v_ts);
end $$;
revoke all on function public.founder_audit_append(uuid, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.founder_audit_append(uuid, text, text, text, jsonb) to service_role;

-- ===============================================================================================================
-- 4) verify + head
-- ===============================================================================================================
create or replace function public.founder_audit_verify(p_from bigint default 1)
returns bigint language plpgsql stable security definer set search_path = public, extensions as $$
declare r record; v_prev text; v_first boolean := true; v_expect bigint;
begin
  for r in select * from public.founder_audit where seq >= greatest(p_from, 1) order by seq loop
    if v_first then
      v_first := false;
      if r.seq = 1 then v_prev := repeat('0', 64);
      else select hash into v_prev from public.founder_audit where seq = r.seq - 1; if v_prev is null then return r.seq; end if; end if;
      v_expect := r.seq;
    end if;
    if r.seq <> v_expect or r.prev_hash <> v_prev
       or r.hash <> public._fa_hash(r.prev_hash, r.seq, r.actor, r.action, r.target, r.reason, r.ts_ms, r.meta) then
      return r.seq;
    end if;
    v_prev := r.hash; v_expect := r.seq + 1;
  end loop;
  return null;
end $$;
revoke all on function public.founder_audit_verify(bigint) from public, anon, authenticated;
grant execute on function public.founder_audit_verify(bigint) to service_role;

create or replace function public.founder_audit_head()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('seq', seq, 'hash', hash, 'ts_ms', ts_ms) from public.founder_audit order by seq desc limit 1),
                  jsonb_build_object('seq', 0, 'hash', repeat('0', 64), 'ts_ms', null))
$$;
revoke all on function public.founder_audit_head() from public, anon, authenticated;
grant execute on function public.founder_audit_head() to service_role;

-- ===============================================================================================================
-- 5) founder_actions — ONE-CLICK catalogue (executor F8; abhi sab DISABLED)
-- ===============================================================================================================
create table if not exists public.founder_actions (
  key              text primary key check (key ~ '^[a-z_]+(\.[a-z_]+)+$'),
  deck             text not null check (deck in ('people','mail_desk','release','move_in','systems','control')),
  title            text not null,
  summary          text not null,
  danger           text not null default 'low' check (danger in ('low','medium','high')),
  needs_passkey    boolean not null default true,
  two_tap          boolean not null default true,
  reversible       boolean not null default true,
  enabled          boolean not null default false,
  runbook          text,
  created_at       timestamptz not null default now(),
  constraint founder_actions_high_needs_passkey check (danger <> 'high' or (needs_passkey and two_tap))
);
alter table public.founder_actions enable row level security;
revoke all on public.founder_actions from public, anon, authenticated;
grant select, insert, update on public.founder_actions to service_role;

insert into public.founder_actions (key, deck, title, summary, danger, reversible, runbook) values
 ('release.pull_web',        'release', 'Web pull',                 'Naya web build pull + restart (pull.sh)',                      'medium', true,  'docs/cursor-work/server/pull.sh'),
 ('release.run_sql',         'release', 'SQL chalao (AUTO)',        'sql-run.sh bare: sha ledger se sirf naye E-files',             'high',   false, 'docs/cursor-work/server/sql-run.sh'),
 ('release.rust_install',    'release', 'Rust engine install',      'rust-engine-install.sh + restart + rollback-on-fail',          'high',   true,  'docs/cursor-work/server/rust-engine-install.sh'),
 ('release.rollback',        'release', 'Pichla build wapas',       'Aakhri backup binary/web wapas',                               'high',   true,  null),
 ('systems.recheck_health',  'systems', 'Sab health dobara',        'Rust/Brain/Caddy/DB/queue ki jaanch abhi',                     'low',    true,  null),
 ('systems.restart_rust',    'systems', 'Rust engine restart',      'pm2 restart anexomail-rust + /rpc/health saboot',              'medium', true,  null),
 ('mail_desk.requeue_failed','mail_desk','Failed mail dobara',      'mail_outbox failed -> queued (limit ke saath)',                'medium', true,  null),
 ('people.suspend_user',     'people',  'User suspend',             'User ko band karna (metadata hi, content nahi), wajah lazmi',  'high',   true,  null),
 ('people.unsuspend_user',   'people',  'User wapas chalu',         'Suspend khatam',                                               'medium', true,  null),
 ('control.maintenance_on',  'control', 'Maintenance mode ON',      'Awam ko saaf "maintenance" page; founder chalta rahe',         'high',   true,  null),
 ('control.maintenance_off', 'control', 'Maintenance mode OFF',     'Awam wapas',                                                   'medium', true,  null),
 ('control.freeze_signups',  'control', 'Naye signup band',         'Naye accounts rok do (hamla / capacity)',                      'high',   true,  null)
on conflict (key) do nothing;

-- ===============================================================================================================
-- 6) founder_devices — approved device (passkey + device approval protocol)
-- ===============================================================================================================
create table if not exists public.founder_devices (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.founder_accounts(user_id) on delete cascade,
  label         text not null check (length(label) between 1 and 80),
  ua_hash       text not null check (ua_hash ~ '^[0-9a-f]{64}$'),
  approved_by   uuid references public.founder_devices(id),
  approved_at   timestamptz,
  revoked_at    timestamptz,
  last_seen_at  timestamptz,
  created_at    timestamptz not null default now(),
  unique (user_id, ua_hash)
);
alter table public.founder_devices enable row level security;
revoke all on public.founder_devices from public, anon, authenticated;
grant select, insert, update on public.founder_devices to service_role;

-- ===============================================================================================================
-- 7) selftest
-- ===============================================================================================================
create or replace function public.founder_audit_selftest() returns text language plpgsql security definer set search_path = public, extensions as $$
declare v_uid uuid; r text := ''; v_before bigint; v_res jsonb; v_bad bigint; v_ok boolean;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E102 selftest SKIP — founder_accounts khali'; end if;
  select count(*) into v_before from public.founder_audit;
  begin
    v_res := public.founder_audit_append(v_uid, 'selftest.one',   't1', 'selftest pehli entry', '{"k":1}');
    perform public.founder_audit_append(v_uid, 'selftest.two',   't2', 'selftest doosri entry', '{}');
    perform public.founder_audit_append(v_uid, 'selftest.three', 't3', 'selftest teesri entry', '{"z":[1,2]}');
    r := r || 'append x3 OK; ';
    if public.founder_audit_verify(1) is not null then raise exception 'saaf chain verify mein kharab'; end if;
    r := r || 'verify saaf OK; ';
    v_ok := false; begin update public.founder_audit set reason = 'badla hua!!' where seq = (v_res ->> 'seq')::bigint; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'UPDATE band nahi'; end if;
    v_ok := false; begin delete from public.founder_audit where seq = (v_res ->> 'seq')::bigint; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'DELETE band nahi'; end if;
    v_ok := false; begin perform public.founder_audit_append(v_uid, 'selftest.short', 't', 'chhota', '{}'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'chhoti wajah qubool ho gayi'; end if;
    v_ok := false; begin perform public.founder_audit_append(gen_random_uuid(), 'selftest.nonfounder', 't', 'founder nahi hai yeh', '{}'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'gair-founder actor qubool ho gaya'; end if;
    r := r || 'update/delete/short-reason/non-founder band OK; ';
    -- tamper: trigger hata kar badlo, verify pakde, phir (rollback mein) sab wapas
    alter table public.founder_audit disable trigger founder_audit_no_upd;
    update public.founder_audit set reason = 'tamper kiya gaya' where seq = (v_res ->> 'seq')::bigint;
    alter table public.founder_audit enable trigger founder_audit_no_upd;
    v_bad := public.founder_audit_verify(1);
    if v_bad is distinct from (v_res ->> 'seq')::bigint then raise exception 'tamper pakda nahi (bad=%)', v_bad; end if;
    r := r || 'tamper pakda gaya OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then
      begin alter table public.founder_audit enable trigger founder_audit_no_upd; exception when others then null; end;
      raise exception 'E102 selftest FAIL: %', sqlerrm;
    end if;
  end;
  if (select count(*) from public.founder_audit) <> v_before then raise exception 'E102 selftest ne saaf nahi kiya'; end if;
  if not exists (select 1 from pg_trigger where tgname = 'founder_audit_no_upd' and tgenabled = 'O') then raise exception 'immutability trigger band reh gaya!'; end if;
  return 'E102 selftest OK — ' || r || 'rollback saaf, trigger chalu';
end $$;
revoke all on function public.founder_audit_selftest() from public, anon, authenticated;
grant execute on function public.founder_audit_selftest() to service_role;

do $$ begin
  raise notice '%', public.founder_audit_selftest();
end $$;
