-- =============================================================================
-- E33 — Team invitations + Teams (18 Oct 2026, shuru se dobara likhi): asli invitations, role maana jaye, accept se banda org mein judey.
--
-- Pehla version fail hua (founder, 18 Oct 05:2x PKT):
--   ERROR 42804  column "role" is of type org_role but expression is of type text
-- Wajah: live `org_members.role` ka type enum `org_role` hai; SQL text daal raha tha. Yeh sirf self-test ki galti nahi thi —
--   `team_invite_accept` ka apna INSERT/UPDATE bhi isi se girta (asli join toot jata).
-- Sabaq: ab accept `org_members.role` / `status` ka ASLI type database se khud dhoondh kar likhta hai (enum ho ya text, dono par chalta hai),
--        aur role ka label us enum mein na ho to ghalat role likhne ki bajaye saaf ruk jata hai (kuch badalta nahi).
--        Schema (Part 1) aur self-test (Part 2) alag transactions hain.
--
-- Kya banta hai (Rust engine `team.*` procs isi ko use karta hai):
--   * org_invitations        : har invitation ka ledger. `token` DB ka random uuid (email ke link mein jata hai).
--                              role / expiry / kisne bheja / mail gayi ya nahi — sab yahan; pending (org,email) unique.
--   * team_invite_lookup     : token se "kis org ne, kaun sa role" (join page ke liye; sirf uuid type — injection ka sawal nahi)
--   * team_invite_accept     : ATOMIC — invitation lock, member row (org_members + account_org_members), invitation `accepted`.
--                              Role invitation row se aata hai, kabhi client / user_metadata se nahi. Double-accept / expiry / revoke handled.
--                              Kisi ka ooncha role neeche nahi giraya jata (owner > admin > manager > member > viewer).
--   * org_teams, org_team_members : Teams aur unke log.
--   * org_people_log         : append-only saboot (update/delete trigger se band) — kisne kise invite kiya / kaun juda / role / hatana.
--
-- Hifazat: sirf additive + idempotent (koi drop/rename nahi); lock_timeout 15s; advisory lock; naye tables par RLS ON + anon/authenticated
--          ke liye KOI grant/policy nahi (E32 ka sabaq) — sirf service_role (engine). Functions security definer + fixed search_path,
--          browser ke roles se execute chheena hua.
-- Chalane ka tareeqa: poori file ek saath (Supabase SQL Editor ya psql). Aakhri jawab: ek row `e33_result`.
-- Fail ho to: usi file ko shuru se theek karo (naya naam banned).
-- =============================================================================

-- ============================ PART 1 — schema (ek transaction) ===============================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E33'));

-- 0. preflight
do $$
declare
  missing text[] := '{}';
  n text;
  need constant text[] := array['organisations.id', 'organisations.name', 'org_members.org_id', 'org_members.user_id', 'org_members.role'];
begin
  foreach n in array need loop
    if not exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = split_part(n, '.', 1) and column_name = split_part(n, '.', 2)
    ) then
      missing := missing || n;
    end if;
  end loop;
  if to_regclass('auth.users') is null then missing := missing || 'auth.users'; end if;
  if coalesce(array_length(missing, 1), 0) > 0 then
    raise exception 'E33 PREFLIGHT: yeh maujood nahi: % — pehle org/signup ke SQL (E28/phase60) chalne chahiye', array_to_string(missing, ', ')
      using errcode = 'AX033';
  end if;
end $$;

-- 1. org_members ke do columns jin par yeh feature tikta hai (mojooda hon to kuch nahi hota)
alter table public.org_members add column if not exists status text not null default 'active';
alter table public.org_members add column if not exists email  text;

-- 2. invitation ledger
create table if not exists public.org_invitations (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organisations(id) on delete cascade,
  email            text not null check (email = lower(email) and char_length(email) between 6 and 254),
  role             text not null default 'member' check (role in ('admin', 'member', 'viewer')),
  token            uuid not null default gen_random_uuid(),
  status           text not null default 'pending' check (status in ('pending', 'accepted', 'revoked', 'expired')),
  invited_by       uuid,
  invited_by_email text,
  invite_count     integer not null default 0,
  last_sent_at     timestamptz,
  send_error       text,
  expires_at       timestamptz not null default (now() + interval '14 days'),
  created_at       timestamptz not null default now(),
  accepted_at      timestamptz,
  accepted_by      uuid
);
create unique index if not exists org_invitations_token_uq   on public.org_invitations (token);
create unique index if not exists org_invitations_pending_uq on public.org_invitations (org_id, email) where status = 'pending';
create index        if not exists org_invitations_org_idx    on public.org_invitations (org_id, status, created_at desc);
create index        if not exists org_invitations_sent_idx   on public.org_invitations (org_id, last_sent_at);
create index        if not exists org_invitations_mail_idx   on public.org_invitations (email, status);

-- 3. teams
create table if not exists public.org_teams (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organisations(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 80),
  slug       text not null,
  created_by uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists org_teams_slug_uq on public.org_teams (org_id, slug);

create table if not exists public.org_team_members (
  team_id  uuid not null references public.org_teams(id) on delete cascade,
  user_id  uuid not null,
  added_by uuid,
  added_at timestamptz not null default now(),
  primary key (team_id, user_id)
);
create index if not exists org_team_members_user_idx on public.org_team_members (user_id);

-- 4. people log (append-only)
create table if not exists public.org_people_log (
  id         bigint generated always as identity primary key,
  org_id     uuid not null references public.organisations(id) on delete cascade,
  actor      text,
  action     text not null,
  target     text,
  detail     jsonb,
  created_at timestamptz not null default now()
);
create index if not exists org_people_log_org_idx on public.org_people_log (org_id, created_at desc);

create or replace function public.org_people_log_guard()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- org delete ka cascade (FK) apni jagah chalta hai: tg_op = DELETE, magar parent org ab nahi — us haal mein safai ki ijazat
  if tg_op = 'DELETE' and not exists (select 1 from public.organisations o where o.id = old.org_id) then
    return old;
  end if;
  if current_setting('anexo.ledger_maintenance', true) = 'on' then
    return coalesce(new, old);
  end if;
  raise exception 'org_people_log append-only hai (% band)', tg_op using errcode = 'AX034';
end $$;
drop trigger if exists org_people_log_append_only on public.org_people_log;
create trigger org_people_log_append_only
  before update or delete on public.org_people_log
  for each row execute function public.org_people_log_guard();

-- 5. tenant lock: sirf service_role
alter table public.org_invitations  enable row level security;
alter table public.org_teams        enable row level security;
alter table public.org_team_members enable row level security;
alter table public.org_people_log   enable row level security;
revoke all on public.org_invitations, public.org_teams, public.org_team_members, public.org_people_log from anon, authenticated;
grant all on public.org_invitations, public.org_teams, public.org_team_members, public.org_people_log to service_role;
do $$
declare t text;
begin
  foreach t in array array['org_invitations', 'org_teams', 'org_team_members', 'org_people_log'] loop
    execute format('drop policy if exists service_role_all on public.%I', t);
    execute format('create policy service_role_all on public.%I for all to service_role using (true) with check (true)', t);
  end loop;
end $$;

-- 6. functions ----------------------------------------------------------------
create or replace function public.team_role_rank(p_role text)
returns integer
language sql
immutable
as $$
  select case p_role when 'owner' then 5 when 'admin' then 4 when 'manager' then 3 when 'member' then 2 when 'viewer' then 1 else 0 end
$$;

-- live column ka ASLI type (schema-qualified, quote kiya hua): `public.org_role` ya `pg_catalog.text`
create or replace function public.team_col_type(p_col text)
returns text
language sql
stable
set search_path = pg_catalog, public
as $$
  select format('%I.%I', n.nspname, t.typname)
    from pg_attribute a
    join pg_type t      on t.oid = a.atttypid
    join pg_namespace n on n.oid = t.typnamespace
   where a.attrelid = 'public.org_members'::regclass
     and a.attname = p_col and a.attnum > 0 and not a.attisdropped
$$;

create or replace function public.team_invite_lookup(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare r record;
begin
  select i.email, i.role, i.status, i.expires_at, i.invited_by_email, o.name as org_name
    into r
    from public.org_invitations i
    join public.organisations o on o.id = i.org_id
   where i.token = p_token;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  return jsonb_build_object(
    'org_name',   r.org_name,
    'role',       r.role,
    'email',      r.email,
    'invited_by', r.invited_by_email,
    'expires_at', r.expires_at,
    'status',     case when r.status = 'pending' and r.expires_at < now() then 'expired' else r.status end
  );
end $$;

create or replace function public.team_invite_accept(p_token uuid, p_user_id uuid, p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  inv      record;
  v_name   text;
  v_role   text;
  v_status text;
  v_found  boolean;
  v_new    text;
  v_email  text := lower(btrim(coalesce(p_email, '')));
  t_role   text := public.team_col_type('role');
  t_status text := public.team_col_type('status');
  v_acct   boolean := false;
begin
  select * into inv from public.org_invitations where token = p_token for update;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  select name into v_name from public.organisations where id = inv.org_id;

  if inv.status = 'revoked' then
    return jsonb_build_object('error', 'revoked');
  end if;
  if inv.status = 'accepted' then
    -- wahi banda link dobara khole to theek; koi aur ho to "used"
    if inv.accepted_by = p_user_id then
      return jsonb_build_object('ok', true, 'already', true, 'org_id', inv.org_id, 'org_name', v_name, 'role', inv.role);
    end if;
    return jsonb_build_object('error', 'used');
  end if;
  if inv.expires_at < now() then
    update public.org_invitations set status = 'expired' where id = inv.id;
    return jsonb_build_object('error', 'expired');
  end if;

  -- yahan se aage kuch ghalat ho to exception (poora transaction wapas — kuch nahi badalta; Rust "could not add you, try again" dikhata hai)
  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'E33: user % auth.users mein nahi', p_user_id using errcode = 'AX035';
  end if;
  if exists (select 1 from pg_type ty where ty.oid = t_role::regtype and ty.typtype = 'e')
     and not exists (select 1 from pg_enum en where en.enumtypid = t_role::regtype and en.enumlabel = inv.role) then
    raise exception 'E33: role "%" live org_members.role (%) mein nahi', inv.role, t_role using errcode = 'AX036';
  end if;

  -- member row. Ooncha role neeche nahi; hataya hua (revoked) banda invitation ke role ke saath wapas aata hai
  select m.role::text, m.status::text into v_role, v_status
    from public.org_members m where m.org_id = inv.org_id and m.user_id = p_user_id limit 1;
  v_found := found;
  if v_found then
    v_new := case
               when v_status = 'revoked' then inv.role
               when public.team_role_rank(inv.role) > public.team_role_rank(v_role) then inv.role
               else v_role
             end;
    execute format(
      'update public.org_members set status = %L::%s, email = coalesce(nullif(email, %L), $3), role = $4::%s where org_id = $1 and user_id = $2',
      'active', t_status, '', t_role)
      using inv.org_id, p_user_id, v_email, v_new;
  else
    v_new := inv.role;
    execute format(
      'insert into public.org_members (org_id, user_id, role, status, email) values ($1, $2, $3::%s, %L::%s, $4)',
      t_role, 'active', t_status)
      using inv.org_id, p_user_id, v_new, v_email;
  end if;

  -- account layer (UI session) — best effort, join ko kabhi nahi rokta. (on conflict nahi: us ke liye unique constraint chahiye)
  begin
    insert into public.account_org_members (org_id, user_id, role)
    select inv.org_id, p_user_id, case when v_new in ('owner', 'admin') then v_new else 'member' end
     where not exists (select 1 from public.account_org_members a where a.org_id = inv.org_id and a.user_id = p_user_id);
    v_acct := true;
  exception when others then
    v_acct := false;
  end;

  update public.org_invitations
     set status = 'accepted', accepted_at = now(), accepted_by = p_user_id
   where id = inv.id;

  insert into public.org_people_log (org_id, actor, action, target, detail)
  values (inv.org_id, v_email, 'invite.accepted', inv.email,
          jsonb_build_object('role', v_new, 'invited_role', inv.role, 'user_id', p_user_id, 'rejoin', coalesce(v_status = 'revoked', false)));

  return jsonb_build_object('ok', true, 'org_id', inv.org_id, 'org_name', v_name, 'role', v_new, 'account_layer', v_acct);
end $$;

revoke all on function public.org_people_log_guard()                    from public, anon, authenticated;
revoke all on function public.team_col_type(text)                       from public, anon, authenticated;
revoke all on function public.team_invite_lookup(uuid)                  from public, anon, authenticated;
revoke all on function public.team_invite_accept(uuid, uuid, text)      from public, anon, authenticated;
revoke all on function public.team_role_rank(text)                      from public, anon, authenticated;
grant execute on function public.team_col_type(text)                    to service_role;
grant execute on function public.team_invite_lookup(uuid)               to service_role;
grant execute on function public.team_invite_accept(uuid, uuid, text)   to service_role;
grant execute on function public.team_role_rank(text)                   to service_role;

notify pgrst, 'reload schema';
commit;

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
-- Asli organisation + asli auth users use hote hain (org_members.org_id / user_id par FK ho sakte hain).
-- Test ka saaman na ban sake (org / do khali auth user nahi) to wahi hissa SKIPPED likhta hai — schema tab bhi lag chuka hota hai.
-- Mantiq ki ya type ki galti (jaise pehli baar ka org_role) = FAIL.
do $$
declare
  v_org    uuid;
  v_user   uuid;
  v_user2  uuid;
  v_inv    uuid;
  v_tok    uuid;
  v_main   uuid;
  v_team   uuid;
  v_r      jsonb;
  v_n      integer;
  v_chk    integer := 0;
  v_hit    boolean;
  v_note   text := '';
  v_sql    text;
  v_pair   record;
  v_first  boolean := true;
  v_role_t text := public.team_col_type('role');
  v_labels text[];
begin
  perform set_config('anexo.e33_selftest', 'not run', false);
  begin
    -- 1. ek org jise sab FK maante hain (organisations + org_members.org_id ke FK targets)
    v_sql := 'select t.id from public.organisations t where true';
    for v_pair in
      select distinct c.confrelid::regclass as tab, a.attname as col
        from pg_constraint c
        join pg_attribute a on a.attrelid = c.confrelid and a.attnum = c.confkey[1]
       where c.contype = 'f' and c.conrelid = 'public.org_members'::regclass
         and c.conkey = array[(select x.attnum from pg_attribute x where x.attrelid = c.conrelid and x.attname = 'org_id')]
         and c.confrelid <> 'public.organisations'::regclass
    loop
      v_sql := v_sql || format(' and exists (select 1 from %s u where u.%I = t.id)', v_pair.tab, v_pair.col);
    end loop;
    execute v_sql || ' limit 1' into v_org;
    if v_org is null then
      v_note := 'koi organisation row nahi — sirf objects check hue';
    else
      -- role ke labels (enum ho to uske, text ho to chaaron)
      select coalesce(array_agg(e.enumlabel::text), array['owner', 'admin', 'member', 'viewer'])
        into v_labels
        from pg_enum e where e.enumtypid = v_role_t::regtype;

      -- 2. do ASLI auth users jo is org ke member nahi
      select u.id into v_user  from auth.users u
       where not exists (select 1 from public.org_members m where m.org_id = v_org and m.user_id = u.id)
       order by u.created_at, u.id limit 1;
      select u.id into v_user2 from auth.users u
       where not exists (select 1 from public.org_members m where m.org_id = v_org and m.user_id = u.id)
         and u.id is distinct from v_user
       order by u.created_at, u.id limit 1;

      -- 3. invitation: lookup role wahi dikhata hai jo invitation mein hai
      insert into public.org_invitations (org_id, email, role, invited_by_email)
      values (v_org, 'guest@e33.test', 'admin', 'owner@e33.test')
      returning id, token into v_inv, v_main;
      v_r := public.team_invite_lookup(v_main);
      if v_r->>'role' <> 'admin' or v_r->>'status' <> 'pending' or v_r->>'invited_by' <> 'owner@e33.test' then
        raise exception 'E33 FAILED: lookup %', v_r using errcode = 'AX033';
      end if;
      if public.team_invite_lookup(gen_random_uuid())->>'error' is distinct from 'not_found' then
        raise exception 'E33 FAILED: anjaan token qabool hua' using errcode = 'AX033';
      end if;
      v_chk := v_chk + 2;

      -- ek hi (org, email) par do pending invitation nahi
      v_hit := false;
      begin
        insert into public.org_invitations (org_id, email) values (v_org, 'guest@e33.test');
      exception when unique_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: duplicate pending invitation chal gaya' using errcode = 'AX033'; end if;
      -- email chhote haroof mein hi (warna pending-unique dhoka kha jata)
      v_hit := false;
      begin
        insert into public.org_invitations (org_id, email) values (v_org, 'UPPER@e33.test');
      exception when check_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: bade haroof wali email chal gayi' using errcode = 'AX033'; end if;
      -- ghalat role invitation mein nahi (owner invitation se nahi milta)
      v_hit := false;
      begin
        insert into public.org_invitations (org_id, email, role) values (v_org, 'boss@e33.test', 'owner');
      exception when check_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: invitation se owner ban sakta hai' using errcode = 'AX033'; end if;
      v_chk := v_chk + 3;

      -- revoked / expired link kabhi join nahi karte (kisi asli user ki zaroorat nahi: yeh join se pehle ruk jate hain)
      insert into public.org_invitations (org_id, email, status) values (v_org, 'gone@e33.test', 'revoked') returning token into v_tok;
      if public.team_invite_accept(v_tok, gen_random_uuid(), 'gone@e33.test')->>'error' is distinct from 'revoked' then
        raise exception 'E33 FAILED: revoked link join ho gaya' using errcode = 'AX033';
      end if;
      insert into public.org_invitations (org_id, email, expires_at) values (v_org, 'late@e33.test', now() - interval '1 day') returning token into v_tok;
      if public.team_invite_accept(v_tok, gen_random_uuid(), 'late@e33.test')->>'error' is distinct from 'expired' then
        raise exception 'E33 FAILED: expired link join ho gaya' using errcode = 'AX033';
      end if;
      if public.team_invite_lookup(v_tok)->>'status' is distinct from 'expired' then
        raise exception 'E33 FAILED: lookup ne expired ko expired nahi dikhaya' using errcode = 'AX033';
      end if;
      v_chk := v_chk + 3;

      -- unknown user: exception (kuch nahi badalta), org_members mein koi row nahi banti
      v_hit := false;
      begin
        perform public.team_invite_accept(v_main, gen_random_uuid(), 'ghost@e33.test');
      exception when sqlstate 'AX035' then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: auth mein na hone wala user join ho gaya' using errcode = 'AX033'; end if;
      select count(*) into v_n from public.org_invitations where id = v_inv and status = 'pending';
      if v_n <> 1 then raise exception 'E33 FAILED: refuse hui call ne invitation badal di' using errcode = 'AX033'; end if;
      v_chk := v_chk + 2;

      if v_user is null or v_user2 is null then
        v_note := 'join wala hissa SKIPPED — is org ke baghair-member do auth users nahi mile';
      elsif not ('admin' = any (v_labels)) then
        v_note := 'join wala hissa SKIPPED — role type (' || v_role_t || ') mein "admin" label nahi';
      else
        -- accept: invitation ke role ke saath judta hai (yahi wo jagah hai jahan pehla version org_role par gira tha)
        v_r := public.team_invite_accept(v_main, v_user, 'Guest@E33.test');
        if (v_r->>'ok')::boolean is not true or v_r->>'role' <> 'admin' then raise exception 'E33 FAILED: accept %', v_r using errcode = 'AX033'; end if;
        select count(*) into v_n from public.org_members m
         where m.org_id = v_org and m.user_id = v_user and m.role::text = 'admin' and m.status::text = 'active' and lower(m.email) = 'guest@e33.test';
        if v_n <> 1 then raise exception 'E33 FAILED: accept ke baad member row (role/status/email) theek nahi' using errcode = 'AX033'; end if;
        select count(*) into v_n from public.org_invitations where id = v_inv and status = 'accepted' and accepted_by = v_user;
        if v_n <> 1 then raise exception 'E33 FAILED: invitation accepted nahi hui' using errcode = 'AX033'; end if;
        select count(*) into v_n from public.org_people_log where org_id = v_org and action = 'invite.accepted' and target = 'guest@e33.test';
        if v_n <> 1 then raise exception 'E33 FAILED: join log nahi hua (%)', v_n using errcode = 'AX033'; end if;
        v_chk := v_chk + 4;

        -- wahi banda dobara = ok (already), koi aur = used, dobara log nahi, refuse hone par member nahi banta
        v_r := public.team_invite_accept(v_main, v_user, 'guest@e33.test');
        if (v_r->>'already')::boolean is not true then raise exception 'E33 FAILED: wahi user dobara %', v_r using errcode = 'AX033'; end if;
        v_r := public.team_invite_accept(v_main, v_user2, 'other@e33.test');
        if v_r->>'error' is distinct from 'used' then raise exception 'E33 FAILED: istemal shuda link doosre ne le liya %', v_r using errcode = 'AX033'; end if;
        select count(*) into v_n from public.org_people_log where org_id = v_org and action = 'invite.accepted' and target = 'guest@e33.test';
        if v_n <> 1 then raise exception 'E33 FAILED: dobara kholne par doosri log row (%)', v_n using errcode = 'AX033'; end if;
        select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user2;
        if v_n <> 0 then raise exception 'E33 FAILED: refuse hone par bhi member ban gaya' using errcode = 'AX033'; end if;
        v_chk := v_chk + 4;

        -- kam role ooncha role ko overwrite nahi karta
        insert into public.org_invitations (org_id, email, role) values (v_org, 'again@e33.test', 'member') returning token into v_tok;
        perform public.team_invite_accept(v_tok, v_user, 'guest@e33.test');
        select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user and role::text = 'admin';
        if v_n <> 1 then raise exception 'E33 FAILED: admin member-invitation se neeche gira' using errcode = 'AX033'; end if;
        v_chk := v_chk + 1;

        -- manager (agar label hai) member-invitation se neeche nahi girta
        if 'manager' = any (v_labels) then
          update public.org_members set role = 'manager' where org_id = v_org and user_id = v_user;
          insert into public.org_invitations (org_id, email, role) values (v_org, 'again2@e33.test', 'member') returning token into v_tok;
          perform public.team_invite_accept(v_tok, v_user, 'guest@e33.test');
          select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user and role::text = 'manager';
          if v_n <> 1 then raise exception 'E33 FAILED: manager member-invitation se neeche gira' using errcode = 'AX033'; end if;
          v_chk := v_chk + 1;
        end if;

        -- hataya hua (revoked) banda naye invitation ke role ke saath wapas aata hai
        begin
          update public.org_members set status = 'revoked' where org_id = v_org and user_id = v_user;
          insert into public.org_invitations (org_id, email, role) values (v_org, 'back@e33.test', 'member') returning token into v_tok;
          v_r := public.team_invite_accept(v_tok, v_user, 'guest@e33.test');
          select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user and status::text = 'active' and role::text = 'member';
          if v_n <> 1 then raise exception 'E33 FAILED: revoked banda wapas nahi aaya (%)', v_r using errcode = 'AX033'; end if;
          v_chk := v_chk + 1;
        exception when invalid_text_representation then
          v_note := v_note || ' revoked-wapsi check SKIPPED (status type mein "revoked" label nahi);';
        end;
      end if;

      -- teams: slug unique, team ka member cascade hota hai
      insert into public.org_teams (org_id, name, slug) values (v_org, 'E33 Team', 'e33-team') returning id into v_team;
      v_hit := false;
      begin
        insert into public.org_teams (org_id, name, slug) values (v_org, 'Dup', 'e33-team');
      exception when unique_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: ek org mein wahi team-slug do baar' using errcode = 'AX033'; end if;
      insert into public.org_team_members (team_id, user_id) values (v_team, coalesce(v_user, gen_random_uuid()));
      delete from public.org_teams where id = v_team;
      select count(*) into v_n from public.org_team_members where team_id = v_team;
      if v_n <> 0 then raise exception 'E33 FAILED: team mitane par uske members nahi gaye' using errcode = 'AX033'; end if;
      v_chk := v_chk + 2;

      -- people log append-only
      insert into public.org_people_log (org_id, actor, action, target) values (v_org, 'selftest', 'e33.selftest', 'x');
      v_hit := false;
      begin
        update public.org_people_log set actor = 'tampered' where action = 'e33.selftest';
      exception when sqlstate 'AX034' then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: people log badla ja saka' using errcode = 'AX033'; end if;
      v_hit := false;
      begin
        delete from public.org_people_log where action = 'e33.selftest';
      exception when sqlstate 'AX034' then v_hit := true;
      end;
      if not v_hit then raise exception 'E33 FAILED: people log mita diya gaya' using errcode = 'AX033'; end if;
      v_chk := v_chk + 2;
    end if;

    -- huqooq: browser ke roles ko na naye tables na functions
    if has_table_privilege('anon', 'public.org_invitations', 'select') or has_table_privilege('authenticated', 'public.org_invitations', 'select')
       or has_table_privilege('authenticated', 'public.org_teams', 'select') or has_table_privilege('authenticated', 'public.org_team_members', 'select')
       or has_table_privilege('authenticated', 'public.org_people_log', 'select')
       or has_function_privilege('anon', 'public.team_invite_accept(uuid,uuid,text)', 'execute')
       or has_function_privilege('authenticated', 'public.team_invite_accept(uuid,uuid,text)', 'execute')
       or has_function_privilege('authenticated', 'public.team_invite_lookup(uuid)', 'execute') then
      raise exception 'E33 FAILED: browser ke roles ko naye tables/functions ke huqooq mile hue hain' using errcode = 'AX033';
    end if;
    if not has_function_privilege('service_role', 'public.team_invite_accept(uuid,uuid,text)', 'execute')
       or not has_table_privilege('service_role', 'public.org_invitations', 'insert') then
      raise exception 'E33 FAILED: service_role (engine) ko huqooq nahi mile' using errcode = 'AX033';
    end if;
    v_chk := v_chk + 2;

    raise exception 'rollback marker' using errcode = 'AX099';   -- test ka saara data wapas (AX099: '...000' class-code hota to AX033 bhi pakad leta)
  exception when sqlstate 'AX099' then
    null;
  end;

  perform set_config('anexo.e33_selftest',
    case when v_note = '' then format('PASSED (%s checks, sab rollback)', v_chk)
         else format('PASSED with notes (%s checks, sab rollback) — %s (yeh line mujhe bhej dein)', v_chk, btrim(v_note)) end,
    false);
end $$;

-- ============================ jawab: ek row ===============================
select
  'E33 OK — schema lag gaya' as e33_result,
  current_setting('anexo.e33_selftest', true) as selftest,
  public.team_col_type('role') as org_members_role_type,
  (select string_agg(e.enumlabel::text, ',' order by e.enumsortorder) from pg_enum e where e.enumtypid = public.team_col_type('role')::regtype) as role_labels,
  (select count(*) from public.org_invitations) as invitations,
  (select count(*) from public.org_teams) as teams,
  (has_table_privilege('anon', 'public.org_invitations', 'select') or has_table_privilege('authenticated', 'public.org_invitations', 'select')) as invitations_readable_by_browser;
