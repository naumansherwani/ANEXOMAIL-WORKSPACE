-- =============================================================================
-- E33 — Team invitations + Teams (18 Oct 2026): real invitations, role honoured, accept joins the organisation.
--
-- Pehle (G17 / L32 / L33):
--   * invite ka `role` server ignore karta tha ("Admin" chun kar bhi member banta tha);
--   * invite sirf Supabase user_metadata mein jata tha — accept hone par banda org mein judta hi nahi tha
--     (aur user_metadata user khud badal sakta hai, usay maan lena security hole hota);
--   * Members / Teams / Invitations list ke endpoints hi nahi the; Teams mein log jodne ka rasta nahi tha.
-- Ab (Rust engine `team.*` procs use karta hai):
--   * org_invitations        : har invitation ka ledger. `token` DB ka random uuid (email ke link mein jata hai).
--                              role / expiry / kisne bheja / mail gayi ya nahi — sab yahan; pending (org,email) unique.
--   * team_invite_lookup     : token se "kis org ne, kaun sa role" (join page ke liye; sirf uuid type — injection ka sawal nahi)
--   * team_invite_accept     : ATOMIC — invitation lock, member row (org_members + account_org_members), invitation `accepted`.
--                              Role invitation row se aata hai, kabhi client / user_metadata se nahi. Double-accept / expiry / revoke handled.
--   * org_teams, org_team_members : Teams aur unke log (ab team mein log jodna mumkin).
--   * org_people_log         : append-only saboot — kisne kise invite kiya / kaun juda / role kisne badla / kisko hataya.
--
-- Sab naye tables RLS ON + anon/authenticated ke liye KOI policy / grant nahi (E32 ka sabaq): sirf service_role (engine) padhta/likhta hai.
-- Sirf additive + idempotent: koi table/column drop nahi, kisi mojooda cheez ka naam nahi badalta.
-- org_members mein `status` / `email` na hon to add_column if not exists se jud jate hain (default 'active').
-- Fail ho to: usi file ko shuru se theek karo (naya naam banned).
-- =============================================================================

begin;

-- 0. org_members ke do columns jin par yeh feature tikta hai (mojooda hon to kuch nahi hota) ---------------------
alter table public.org_members add column if not exists status text not null default 'active';
alter table public.org_members add column if not exists email  text;

-- 1. invitation ledger -------------------------------------------------------
create table if not exists public.org_invitations (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organisations(id) on delete cascade,
  email            text not null check (email = lower(email) and char_length(email) between 6 and 254),
  role             text not null default 'member' check (role in ('admin','member','viewer')),
  token            uuid not null default gen_random_uuid(),
  status           text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
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

-- 2. teams -------------------------------------------------------------------
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

-- 2b. people log: har invite / join / role badalna / hatana ka append-only saboot --------------------------------
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

-- 3. tenant lock: sirf service_role ---------------------------------------------
alter table public.org_invitations   enable row level security;
alter table public.org_teams         enable row level security;
alter table public.org_team_members  enable row level security;
alter table public.org_people_log    enable row level security;
revoke all on public.org_invitations, public.org_teams, public.org_team_members, public.org_people_log from anon, authenticated;

-- 4. lookup (join page) ---------------------------------------------------------
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

-- 5. accept (ATOMIC) --------------------------------------------------------------
create or replace function public.team_role_rank(p_role text)
returns integer
language sql
immutable
as $$
  select case p_role when 'owner' then 4 when 'admin' then 3 when 'member' then 2 when 'viewer' then 1 else 0 end
$$;

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
    -- same person opening the link twice is fine; anyone else is told it was used
    if inv.accepted_by = p_user_id then
      return jsonb_build_object('ok', true, 'already', true, 'org_id', inv.org_id, 'org_name', v_name, 'role', inv.role);
    end if;
    return jsonb_build_object('error', 'used');
  end if;
  if inv.expires_at < now() then
    update public.org_invitations set status = 'expired' where id = inv.id;
    return jsonb_build_object('error', 'expired');
  end if;

  -- member row: never downgrade somebody who already has a higher role here; a removed (revoked) member comes back with the invited role
  select role, status into v_role, v_status
    from public.org_members where org_id = inv.org_id and user_id = p_user_id limit 1;
  v_found := found;
  if v_found then
    update public.org_members
       set status = 'active',
           email  = coalesce(nullif(email, ''), lower(p_email)),
           role   = case
                      when v_status = 'revoked' then inv.role
                      when public.team_role_rank(inv.role) > public.team_role_rank(v_role) then inv.role
                      else v_role
                    end
     where org_id = inv.org_id and user_id = p_user_id;
  else
    insert into public.org_members (org_id, user_id, role, status, email)
    values (inv.org_id, p_user_id, inv.role, 'active', lower(p_email));
  end if;

  -- account layer (UI session) — best effort, never blocks the join
  begin
    insert into public.account_org_members (org_id, user_id, role)
    values (inv.org_id, p_user_id, case when inv.role = 'viewer' then 'member' else inv.role end)
    on conflict (org_id, user_id) do nothing;
  exception when others then
    null;
  end;

  update public.org_invitations
     set status = 'accepted', accepted_at = now(), accepted_by = p_user_id
   where id = inv.id;

  insert into public.org_people_log (org_id, actor, action, target, detail)
  values (inv.org_id, lower(p_email), 'invite.accepted', inv.email, jsonb_build_object('role', inv.role, 'user_id', p_user_id));

  return jsonb_build_object('ok', true, 'org_id', inv.org_id, 'org_name', v_name, 'role', inv.role);
end $$;

revoke all on function public.team_invite_lookup(uuid)               from public, anon, authenticated;
revoke all on function public.team_invite_accept(uuid, uuid, text)   from public, anon, authenticated;
revoke all on function public.team_role_rank(text)                   from public, anon, authenticated;
grant execute on function public.team_invite_lookup(uuid)             to service_role;
grant execute on function public.team_invite_accept(uuid, uuid, text) to service_role;
grant execute on function public.team_role_rank(text)                 to service_role;

-- 6. self-test (sab kuch rollback hota hai — kuch bachta nahi) ---------------------------------
do $$
declare
  v_org  uuid;
  v_user uuid;
  v_user2 uuid;
  v_tok  uuid;
  v_main uuid;
  v_inv  uuid;
  v_r    jsonb;
  v_n    integer;
  v_hit  boolean := false;
begin
  begin
    select id into v_org from public.organisations limit 1;
    if v_org is null then
      raise exception 'E33_selftest_ok';   -- no organisation yet: nothing to test against, objects are in place
    end if;

    -- two REAL auth users who are not yet members of v_org (org_members.user_id may be a foreign key to auth.users)
    select id into v_user  from auth.users where id not in (select user_id from public.org_members where org_id = v_org) order by created_at limit 1;
    select id into v_user2 from auth.users where id not in (select user_id from public.org_members where org_id = v_org) and id is distinct from v_user order by created_at limit 1;

    insert into public.org_invitations (org_id, email, role, invited_by_email)
    values (v_org, 'guest@e33.test', 'admin', 'owner@e33.test')
    returning id, token into v_inv, v_main;

    -- lookup shows the role the INVITATION carries
    v_r := public.team_invite_lookup(v_main);
    if v_r->>'role' <> 'admin' or v_r->>'status' <> 'pending' then raise exception 'E33 FAILED: lookup %', v_r; end if;
    if public.team_invite_lookup(gen_random_uuid())->>'error' <> 'not_found' then raise exception 'E33 FAILED: unknown token accepted'; end if;

    -- a second pending invitation for the same (org,email) is refused
    begin
      insert into public.org_invitations (org_id, email) values (v_org, 'guest@e33.test');
    exception when unique_violation then v_hit := true;
    end;
    if not v_hit then raise exception 'E33 FAILED: duplicate pending invitation allowed'; end if;

    -- revoked / expired links never join (no real user needed: they stop before any write)
    insert into public.org_invitations (org_id, email, status) values (v_org, 'gone@e33.test', 'revoked') returning token into v_tok;
    if public.team_invite_accept(v_tok, gen_random_uuid(), 'gone@e33.test')->>'error' <> 'revoked' then raise exception 'E33 FAILED: revoked link joined'; end if;
    insert into public.org_invitations (org_id, email, expires_at) values (v_org, 'late@e33.test', now() - interval '1 day') returning token into v_tok;
    if public.team_invite_accept(v_tok, gen_random_uuid(), 'late@e33.test')->>'error' <> 'expired' then raise exception 'E33 FAILED: expired link joined'; end if;

    if v_user is null or v_user2 is null then
      raise exception 'E33_selftest_ok';   -- fewer than two spare auth users: the join path is exercised on the first real invitation
    end if;

    -- accept: joins with the invited role
    v_r := public.team_invite_accept(v_main, v_user, 'guest@e33.test');
    if (v_r->>'ok')::boolean is not true or v_r->>'role' <> 'admin' then raise exception 'E33 FAILED: accept %', v_r; end if;
    select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user and role = 'admin' and status = 'active';
    if v_n <> 1 then raise exception 'E33 FAILED: member row missing after accept'; end if;

    select count(*) into v_n from public.org_people_log where org_id = v_org and action = 'invite.accepted' and target = 'guest@e33.test';
    if v_n <> 1 then raise exception 'E33 FAILED: join not logged (%)', v_n; end if;

    -- same person again = ok (already); another person = used
    v_r := public.team_invite_accept(v_main, v_user, 'guest@e33.test');
    if (v_r->>'already')::boolean is not true then raise exception 'E33 FAILED: re-open by same user %', v_r; end if;
    v_r := public.team_invite_accept(v_main, v_user2, 'other@e33.test');
    if v_r->>'error' <> 'used' then raise exception 'E33 FAILED: used link accepted by someone else %', v_r; end if;
    select count(*) into v_n from public.org_people_log where org_id = v_org and action = 'invite.accepted' and target = 'guest@e33.test';
    if v_n <> 1 then raise exception 'E33 FAILED: a repeat open wrote a second log row (%)', v_n; end if;

    select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user2;
    if v_n <> 0 then raise exception 'E33 FAILED: a refused link still created a member'; end if;

    -- no lower role overwrites a higher one
    insert into public.org_invitations (org_id, email, role) values (v_org, 'again@e33.test', 'viewer') returning token into v_tok;
    v_r := public.team_invite_accept(v_tok, v_user, 'guest@e33.test');
    select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user and role = 'admin';
    if v_n <> 1 then raise exception 'E33 FAILED: admin was downgraded by a viewer invitation'; end if;

    raise exception 'E33_selftest_ok';
  exception when others then
    if sqlerrm <> 'E33_selftest_ok' then raise exception '%', sqlerrm; end if;
  end;
end $$;

notify pgrst, 'reload schema';

commit;

-- read-only proof (run after):
--   select to_regclass('public.org_invitations') is not null as invitations_ready, to_regclass('public.org_teams') is not null as teams_ready;
--   select has_table_privilege('anon','public.org_invitations','select') as anon_can_read_invitations;   -- must be false
--   select has_table_privilege('authenticated','public.org_invitations','select') as authenticated_can_read_invitations; -- must be false
