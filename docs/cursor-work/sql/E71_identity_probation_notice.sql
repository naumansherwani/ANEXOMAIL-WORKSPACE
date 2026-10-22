-- ============================================================================================================================
-- E71 — IDENTITY: probation ki ASLI ROK + session backstop (DB-level) + manzoori ka khud-ba-khud notice.      Founder 23 Oct 2026
--   "yeh kisi bhi keemat pe hoga": E70 ke teen khule sawal band karta hai.
--
--   P1  PROBATION ENFORCEMENT: identity_probation_take(account, kind, ...) — Brain (mail send/schedule) aur Rust (invites, public link,
--       bulk import) isi ek function se poochte hain. Naye (probation wale) account ki had:
--         send        -> har message 20 recipients tak, din mein 50 messages tak (atomic counter, race nahi)
--         invite / public_link / bulk -> probation mein band (reason code saaf)
--       Probation se bahar (umar > probation_days, ya Polar paid, ya founder) => hamesha ok. DB/function error => caller fail-open
--       (outage mein sab ko lock nahi karte); ye function khud kabhi "ok" ka jhoota jawab nahi deta.
--   P2  SESSION BACKSTOP: auth.sessions / auth.refresh_tokens par BEFORE INSERT trigger — hold (pending) ya rejected account ke liye
--       session/refresh token BANNA hi nahi (exception). Yani passkey, OTP, magic-link, recovery-code, refresh: koi bhi raasta ho,
--       GoTrue ka banned_until check chuke ya na chuke, DB aakhri darwaza band rakhta hai. Trigger banane ki ijazat na ho (owner) to
--       migration girti nahi: identity_session_guard_status() batata hai installed hai ya nahi (CHECK_E71 dikhata hai).
--   P3  NOTICE: founder 'approve' kare to user ko khud-ba-khud ek saada email (recovery email par). identity_notice_pending/done
--       outbox ki tarah — bhejna fail ho to dobara koshish (max 6), kabhi dohra nahi. 'reject' par KOI notice nahi
--       (banned insaan ko wajah/hint dena nahi).
--
-- Rule 38 (advanced), 42 (editor compat), 43 (RLS ON), 44 (server se chalta hai). Idempotent. Koi DROP TABLE/COLUMN nahi.
-- WAPAS LENA: drop trigger if exists identity_session_guard_trg on auth.sessions; drop trigger if exists identity_session_guard_trg on auth.refresh_tokens;
-- ============================================================================================================================
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. probation ka din-wise hisab ------------------------------------------------------------------------------------------------
create table if not exists public.identity_probation_usage (
  account_id uuid   not null references auth.users (id) on delete cascade,
  day        date   not null,
  sends      int    not null default 0 check (sends >= 0),
  recipients int    not null default 0 check (recipients >= 0),
  denied     int    not null default 0 check (denied >= 0),
  primary key (account_id, day)
);
alter table public.identity_probation_usage enable row level security;
revoke all on public.identity_probation_usage from public, anon, authenticated;
grant select, insert, update, delete on public.identity_probation_usage to service_role;
create index if not exists identity_probation_usage_day_idx on public.identity_probation_usage (day);

-- ---- 2. probation ki rok: ek saaf jawab ---------------------------------------------------------------------------------------------
-- p_kind: send | invite | public_link | bulk.   p_recipients: send ke liye is message ke total (to+cc+bcc).
-- Jawab: {ok, probation, reason?, limit?, used?, until?}. reason: probation_recipients | probation_daily | probation_invites | probation_links | probation_bulk
create or replace function public.identity_probation_take(p_account uuid, p_kind text, p_recipients int default 0)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare lim jsonb; rules jsonb; today date := (now() at time zone 'utc')::date; used int; max_r int; max_m int;
begin
  if p_account is null or p_kind is null then return jsonb_build_object('ok', true, 'probation', false); end if;
  if p_kind not in ('send', 'invite', 'public_link', 'bulk') then raise exception 'bad_kind' using errcode = '22023'; end if;
  lim := public.identity_account_limits(p_account);
  if coalesce((lim ->> 'probation')::boolean, false) is not true then
    return jsonb_build_object('ok', true, 'probation', false);
  end if;
  rules := lim -> 'rules';
  max_r := coalesce((rules ->> 'max_recipients_per_message')::int, 20);
  max_m := coalesce((rules ->> 'max_messages_per_day')::int, 50);

  if p_kind = 'invite' or p_kind = 'public_link' or p_kind = 'bulk' then
    insert into public.identity_probation_usage (account_id, day, denied) values (p_account, today, 1)
    on conflict (account_id, day) do update set denied = public.identity_probation_usage.denied + 1;
    return jsonb_build_object('ok', false, 'probation', true, 'until', lim -> 'until',
      'reason', case p_kind when 'invite' then 'probation_invites' when 'public_link' then 'probation_links' else 'probation_bulk' end);
  end if;

  -- send
  if coalesce(p_recipients, 0) > max_r then
    insert into public.identity_probation_usage (account_id, day, denied) values (p_account, today, 1)
    on conflict (account_id, day) do update set denied = public.identity_probation_usage.denied + 1;
    return jsonb_build_object('ok', false, 'probation', true, 'reason', 'probation_recipients', 'limit', max_r, 'until', lim -> 'until');
  end if;
  -- atomic: counter badhao SIRF jab had se neeche ho (do ek saath bhejne wale ek hi slot nahi kha sakte)
  insert into public.identity_probation_usage (account_id, day, sends, recipients) values (p_account, today, 0, 0)
  on conflict (account_id, day) do nothing;
  update public.identity_probation_usage
     set sends = sends + 1, recipients = recipients + greatest(coalesce(p_recipients, 0), 0)
   where account_id = p_account and day = today and sends < max_m
  returning sends into used;
  if used is null then
    update public.identity_probation_usage set denied = denied + 1 where account_id = p_account and day = today;
    return jsonb_build_object('ok', false, 'probation', true, 'reason', 'probation_daily', 'limit', max_m, 'used', max_m, 'until', lim -> 'until');
  end if;
  return jsonb_build_object('ok', true, 'probation', true, 'limit', max_m, 'used', used, 'until', lim -> 'until');
end $$;

-- purani ginti saaf (retention): 40 din
create or replace function public.identity_probation_sweep()
returns int language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '30s' as $$
declare n int;
begin
  delete from public.identity_probation_usage where day < (now() at time zone 'utc')::date - 40;
  get diagnostics n = row_count;
  return n;
end $$;

-- ---- 3. SESSION BACKSTOP: hold/rejected account ka session/refresh banna hi nahi ------------------------------------------------------
-- BEFORE INSERT: exception => GoTrue ko error (sign-in nakam). Sirf pending/rejected par; approved/koi-state-nahi par gujar jata hai.
-- Fast path: ek primary-key lookup. Table na ho (E70 se pehle) to function khud chup-chaap guzar deta hai.
create or replace function public.identity_session_guard()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid; st text;
begin
  uid := new.user_id;
  if uid is null then return new; end if;
  if to_regclass('public.identity_account_state') is null then return new; end if;
  select s.state into st from public.identity_account_state s where s.account_id = uid;
  if st in ('pending', 'rejected') then
    raise exception 'account_pending' using errcode = '42501', hint = 'identity hold';
  end if;
  return new;
end $$;
revoke all on function public.identity_session_guard() from public, anon, authenticated;

-- trigger lagana: auth schema ka owner alag ho sakta hai. Girna nahi — result alag function se dikhta hai.
do $$
begin
  begin
    execute 'drop trigger if exists identity_session_guard_trg on auth.sessions';
    execute 'create trigger identity_session_guard_trg before insert on auth.sessions for each row execute function public.identity_session_guard()';
  exception when others then
    raise notice 'E71: auth.sessions trigger nahi laga (%): %', sqlstate, sqlerrm;
  end;
  begin
    execute 'drop trigger if exists identity_session_guard_trg on auth.refresh_tokens';
    execute 'create trigger identity_session_guard_trg before insert on auth.refresh_tokens for each row execute function public.identity_session_guard()';
  exception when others then
    raise notice 'E71: auth.refresh_tokens trigger nahi laga (%): %', sqlstate, sqlerrm;
  end;
end $$;

-- refresh_tokens.user_id text hota hai (GoTrue purane schema) — trigger function uuid cast karta hai, isliye alag wrapper agar column text ho
do $$
declare t text;
begin
  select data_type into t from information_schema.columns where table_schema = 'auth' and table_name = 'refresh_tokens' and column_name = 'user_id';
  if t is not null and t <> 'uuid' then
    execute $f$
      create or replace function public.identity_session_guard_text()
      returns trigger language plpgsql security definer set search_path = pg_catalog, public as $g$
      declare st text; uid uuid;
      begin
        begin uid := nullif(new.user_id::text, '')::uuid; exception when others then return new; end;
        if uid is null or to_regclass('public.identity_account_state') is null then return new; end if;
        select s.state into st from public.identity_account_state s where s.account_id = uid;
        if st in ('pending', 'rejected') then raise exception 'account_pending' using errcode = '42501', hint = 'identity hold'; end if;
        return new;
      end $g$
    $f$;
    execute 'revoke all on function public.identity_session_guard_text() from public, anon, authenticated';
    begin
      execute 'drop trigger if exists identity_session_guard_trg on auth.refresh_tokens';
      execute 'create trigger identity_session_guard_trg before insert on auth.refresh_tokens for each row execute function public.identity_session_guard_text()';
    exception when others then
      raise notice 'E71: refresh_tokens (text) trigger nahi laga (%): %', sqlstate, sqlerrm;
    end;
  end if;
end $$;

-- install ki halat (CHECK_E71 / founder panel)
create or replace function public.identity_session_guard_status()
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'sessions',       exists (select 1 from pg_trigger where tgname = 'identity_session_guard_trg' and tgrelid = 'auth.sessions'::regclass and not tgisinternal),
    'refresh_tokens', exists (select 1 from pg_trigger where tgname = 'identity_session_guard_trg' and tgrelid = 'auth.refresh_tokens'::regclass and not tgisinternal))
$$;

-- ---- 4. NOTICE: manzoori ka email ---------------------------------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'identity_account_state' and column_name = 'notify_state') then
    alter table public.identity_account_state add column notify_state text check (notify_state in ('sent', 'no_target', 'gave_up'));
    update public.identity_account_state set notify_state = 'no_target' where state = 'approved';   -- purani manzooriyan: notice nahi
  end if;
end $$;
alter table public.identity_account_state
  add column if not exists notified_at     timestamptz,
  add column if not exists notify_attempts smallint not null default 0,
  add column if not exists notify_last_at  timestamptz;

-- Kise bhejna hai: approved + abhi tak notice nahi + (pichli koshish ko 5 min guzre) + attempts < 6.
-- Target = recovery email (jo user ne sign-up par diya). account_recovery table na ho ya khali ho to bhejne ki jagah nahi: 'no_target'.
create or replace function public.identity_notice_pending(p_limit int default 20)
returns table (account_id uuid, to_email text, display_name text)
language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
#variable_conflict use_column
declare r record; tgt text;
begin
  for r in
    select s.account_id as aid from public.identity_account_state s
     where s.state = 'approved' and s.notify_state is null and s.notify_attempts < 6
       and (s.notify_last_at is null or s.notify_last_at < now() - interval '5 minutes')
     order by s.decided_at nulls last limit greatest(1, least(coalesce(p_limit, 20), 100))
     for update of s skip locked
  loop
    tgt := null;
    if to_regclass('public.account_recovery') is not null then
      execute 'select email from public.account_recovery where user_id = $1 and email is not null limit 1' into tgt using r.aid;
    end if;
    if tgt is null or tgt !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(tgt) > 254 then
      update public.identity_account_state set notify_state = 'no_target', notified_at = now(), notify_last_at = now() where account_id = r.aid;
      continue;
    end if;
    update public.identity_account_state set notify_attempts = notify_attempts + 1, notify_last_at = now() where account_id = r.aid;
    account_id := r.aid; to_email := tgt;
    display_name := null;
    if to_regclass('public.account_profiles') is not null then
      execute 'select display_name from public.account_profiles where user_id = $1' into display_name using r.aid;
    end if;
    return next;
  end loop;
end $$;

create or replace function public.identity_notice_done(p_account uuid, p_ok boolean)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
begin
  if p_ok then
    update public.identity_account_state set notify_state = 'sent', notified_at = now(), notify_last_at = now()
     where account_id = p_account and state = 'approved' and notify_state is null;
  else
    update public.identity_account_state
       set notify_state = case when notify_attempts >= 6 then 'gave_up' else notify_state end, notify_last_at = now()
     where account_id = p_account and state = 'approved' and notify_state is null;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Purani (E71 se pehle ki) manzooriyon ko notice nahi bhejna: backfill SIRF pehli baar (jab notify_state column abhi bana ho).
-- (Neeche ka flag column 'notify_state' ke banne se pehle padha jata hai — dobara chalane par nayi manzooriyan kabhi 'no_target' nahi hoti.)
-- ---- 5. purge worker: probation ginti bhi saaf ---------------------------------------------------------------------------------------
create or replace function public.identity_vault_purge_probation()
returns int language sql volatile security definer set search_path = pg_catalog, public as $$
  select public.identity_probation_sweep()
$$;

-- ---- 6. haq: sirf service_role ----------------------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.identity_probation_take(uuid,text,int)', 'public.identity_probation_sweep()', 'public.identity_session_guard_status()',
    'public.identity_notice_pending(int)', 'public.identity_notice_done(uuid,boolean)', 'public.identity_vault_purge_probation()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ---- 7. post-conditions ---------------------------------------------------------------------------------------------------------------
do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.identity_probation_usage'::regclass) then raise exception 'E71: RLS off'; end if;
  if has_table_privilege('anon', 'public.identity_probation_usage', 'select') or has_table_privilege('authenticated', 'public.identity_probation_usage', 'select') then
    raise exception 'E71: usage table khuli hai';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null) then
    raise exception 'E71: koi identity_* function bina search_path pin ke';
  end if;
end $$;
