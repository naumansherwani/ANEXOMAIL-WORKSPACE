-- =============================================================================
-- E34 — Team ke teen baqi hisse (19 Oct 2026, founder "haan"): seat limit, tamper-evident audit chain, join par mailbox.
-- E33 ke BAAD chalti hai (E33 ke functions ko `create or replace` se badalti hai; koi drop/rename nahi, purane tables ko haath nahi).
--
--  1) SEAT LIMIT (plan ke hisaab se kitne member)
--       * Business / Basic / Pro (business workspace) per-seat bikte hain => khareede hue seats se zyada member nahi.
--       * Business Pro "unlimited internal users" hai (plans.ts) => kabhi nahi roka jata.
--       * Seats kahan se: owner ki `entitlement_state.seats` aur `workspace_subscriptions.seats` (jo bhi bada). Seat ginti na mile
--         (0 / row nahi) to limit LAGU NAHI hoti (website na toote; jawab mein `known:false` aata hai) — jhoota "full" kabhi nahi.
--       * Asli rok `team_invite_accept` mein hai (org-wise advisory lock ke andar ginti dobara): do log ek saath aakhri seat nahi le sakte.
--         Invite banate waqt Rust sirf pehle se bata deta hai (team_seat_state).
--       * Hataya hua (revoked) banda dobara aaye to naya seat leta hai; pehle se active member ka role badalna seat nahi leta.
--  2) AUDIT CHAIN: `team_audit()` ek hi call mein org_people_log (append-only) AUR Brain ki `org_audit_chain` (sha-256 hash chain, phase64)
--       likhta hai. Chain wali table/function na ho to sirf people log — kabhi action nahi rukta.
--  3) JOIN PAR MAILBOX: invitation mein optional `mailbox_local` (+ `mailbox_domain_id`). Join par `org_address_create` (E15: cap, domain verified,
--       address_taken) member ke naam se mailbox banata hai. Nakaam ho to join phir bhi hota hai; jawab mein `mailbox` = created / failed(+wajah)
--       / pending ("admin banayega"). Result invitation par `mailbox_result` mein rehta hai.
--
-- Hifazat: additive + idempotent; lock_timeout 15s; advisory lock; naye functions security definer + fixed search_path, browser ke roles se
-- execute chheena hua (sirf service_role). Schema (Part 1) aur self-test (Part 2) alag transactions; self-test ka saara data wapas.
-- Chalane ka tareeqa: poori file ek saath (Supabase SQL Editor ya psql). Aakhri jawab: ek row `e34_result`.
-- Fail ho to: usi file ko shuru se theek karo (naya naam banned).
-- =============================================================================

-- ============================ PART 1 — schema + functions (ek transaction) ===============================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E34'));

-- 0. preflight: E33 chalni chahiye
do $$
declare
  missing text[] := '{}';
begin
  if to_regclass('public.org_invitations') is null then missing := missing || 'org_invitations'; end if;
  if to_regclass('public.org_people_log')  is null then missing := missing || 'org_people_log'; end if;
  if to_regprocedure('public.team_invite_accept(uuid,uuid,text)') is null then missing := missing || 'team_invite_accept'; end if;
  if to_regprocedure('public.team_role_rank(text)') is null then missing := missing || 'team_role_rank'; end if;
  if to_regprocedure('public.team_col_type(text)') is null then missing := missing || 'team_col_type'; end if;
  if coalesce(array_length(missing, 1), 0) > 0 then
    raise exception 'E34 PREFLIGHT: yeh maujood nahi: % — pehle docs/cursor-work/sql/E33_team_invites.sql chalayen', array_to_string(missing, ', ')
      using errcode = 'AX041';
  end if;
end $$;

-- 1. invitation par optional mailbox
alter table public.org_invitations add column if not exists mailbox_local     text;
alter table public.org_invitations add column if not exists mailbox_domain_id uuid;
alter table public.org_invitations add column if not exists mailbox_result    jsonb;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'org_invitations_mailbox_local_chk'
                    and conrelid = 'public.org_invitations'::regclass) then
    alter table public.org_invitations
      add constraint org_invitations_mailbox_local_chk
      check (mailbox_local is null or mailbox_local ~ '^[a-z0-9]([a-z0-9._-]{0,62}[a-z0-9])?$') not valid;
  end if;
end $$;
alter table public.org_invitations validate constraint org_invitations_mailbox_local_chk;

-- 2. seat hisaab: pure faisla (yehi self-test mein har soorat par parkha jata hai) + data jama karne wala
create or replace function public.team_seat_calc(p_plan text, p_seats integer, p_used integer, p_pending integer)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'plan',      p_plan,
    'unlimited', coalesce(p_plan, '') = 'business_pro',
    'known',     coalesce(p_seats, 0) > 0,
    'enforced',  coalesce(p_plan, '') <> 'business_pro' and coalesce(p_seats, 0) > 0,
    'seats',     case when coalesce(p_plan, '') <> 'business_pro' and coalesce(p_seats, 0) > 0 then p_seats else null end,
    'used',      greatest(coalesce(p_used, 0), 0),
    'pending',   greatest(coalesce(p_pending, 0), 0),
    'free',      case when coalesce(p_plan, '') <> 'business_pro' and coalesce(p_seats, 0) > 0
                      then greatest(p_seats - greatest(coalesce(p_used, 0), 0) - greatest(coalesce(p_pending, 0), 0), 0)
                      else null end
  )
$$;

create or replace function public.team_seat_state(p_org uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_plan    text;
  v_seats   integer := 0;
  v_seats2  integer := 0;
  v_used    integer;
  v_pending integer;
begin
  begin
    v_plan := public.org_plan_of(p_org);
  exception when undefined_function then
    v_plan := null;
  end;
  select coalesce(max(e.seats), 0) into v_seats
    from public.entitlement_state e
   where e.user_id in (select m.user_id from public.org_members m where m.org_id = p_org and m.role::text = 'owner');
  if to_regclass('public.workspace_subscriptions') is not null then
    begin
      execute 'select coalesce(max(s.seats), 0) from public.workspace_subscriptions s
                where s.user_id in (select m.user_id from public.org_members m where m.org_id = $1 and m.role::text = ''owner'')'
        into v_seats2 using p_org;
    exception when others then
      v_seats2 := 0;
    end;
  end if;
  select count(*) into v_used from public.org_members m
   where m.org_id = p_org and coalesce(m.status::text, 'active') <> 'revoked';
  select count(*) into v_pending from public.org_invitations i
   where i.org_id = p_org and i.status = 'pending' and i.expires_at > now();
  return public.team_seat_calc(v_plan, greatest(v_seats, v_seats2), v_used, v_pending);
end $$;

-- 3. audit: people log + hash chain, ek call
create or replace function public.team_audit(
  p_org uuid, p_actor text, p_action text, p_target text default null, p_detail jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seq   bigint;
  v_chain boolean := false;
begin
  insert into public.org_people_log (org_id, actor, action, target, detail)
  values (p_org, coalesce(p_actor, ''), p_action, p_target, coalesce(p_detail, '{}'::jsonb));
  if to_regprocedure('public.org_chain_append(text,text,text,text,uuid)') is not null then
    begin
      v_seq := public.org_chain_append(
        coalesce(p_actor, ''), 'team.' || p_action,
        left(coalesce(p_target, '') || case when p_detail is null or p_detail = '{}'::jsonb then '' else ' ' || p_detail::text end, 500),
        null, p_org);
      v_chain := true;
    exception when others then
      v_chain := false;      -- chain optional: jis action ko yeh likhta hai use kabhi nahi rokta
    end;
  end if;
  return jsonb_build_object('log', true, 'chain', v_chain, 'seq', v_seq);
end $$;

-- 4. mailbox ke liye domain: invitation ne jo diya, warna org ka pehla verified domain
create or replace function public.team_invite_domain(p_org uuid, p_domain_id uuid)
returns table (id uuid, domain text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if to_regclass('public.org_domains') is null then
    return;
  end if;
  return query execute
    'select d.id, d.domain::text from public.org_domains d
      where d.org_id = $1 and d.status = ''verified'' and ($2 is null or d.id = $2)
      order by d.domain limit 1'
    using p_org, p_domain_id;
end $$;

-- 5. lookup: join page ko dikhane ke liye ke mailbox milega ya nahi
create or replace function public.team_invite_lookup(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r    record;
  v_d  record;
  v_mb text := null;
begin
  select i.org_id, i.email, i.role, i.status, i.expires_at, i.invited_by_email, i.mailbox_local, i.mailbox_domain_id, o.name as org_name
    into r
    from public.org_invitations i
    join public.organisations o on o.id = i.org_id
   where i.token = p_token;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  if coalesce(r.mailbox_local, '') <> '' then
    begin
      select d.id, d.domain into v_d from public.team_invite_domain(r.org_id, r.mailbox_domain_id) d;
      if v_d.id is not null then v_mb := r.mailbox_local || '@' || v_d.domain; end if;
    exception when others then
      v_mb := null;
    end;
  end if;
  return jsonb_build_object(
    'org_name',   r.org_name,
    'role',       r.role,
    'email',      r.email,
    'invited_by', r.invited_by_email,
    'expires_at', r.expires_at,
    'mailbox',    v_mb,
    'status',     case when r.status = 'pending' and r.expires_at < now() then 'expired' else r.status end
  );
end $$;

-- 6. accept: E33 ka poora kaam + seat rok + mailbox + audit chain
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
  v_seats  jsonb;
  v_dom    record;
  v_mb     jsonb;
  v_r      jsonb;
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
    if inv.accepted_by = p_user_id then
      return jsonb_build_object('ok', true, 'already', true, 'org_id', inv.org_id, 'org_name', v_name, 'role', inv.role,
                                'mailbox', coalesce(inv.mailbox_result, jsonb_build_object('status', 'pending')));
    end if;
    return jsonb_build_object('error', 'used');
  end if;
  if inv.expires_at < now() then
    update public.org_invitations set status = 'expired' where id = inv.id;
    return jsonb_build_object('error', 'expired');
  end if;

  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'E33: user % auth.users mein nahi', p_user_id using errcode = 'AX035';
  end if;
  if exists (select 1 from pg_type ty where ty.oid = t_role::regtype and ty.typtype = 'e')
     and not exists (select 1 from pg_enum en where en.enumtypid = t_role::regtype and en.enumlabel = inv.role) then
    raise exception 'E33: role "%" live org_members.role (%) mein nahi', inv.role, t_role using errcode = 'AX036';
  end if;

  -- do log ek saath aakhri seat na le sakein: org-wise lock, ginti uske ANDAR
  perform pg_advisory_xact_lock(hashtextextended('team_seats:' || inv.org_id::text, 0));

  select m.role::text, m.status::text into v_role, v_status
    from public.org_members m where m.org_id = inv.org_id and m.user_id = p_user_id limit 1;
  v_found := found;

  if not v_found or v_status = 'revoked' then          -- naya seat (pehle se active member ka role badalna seat nahi leta)
    v_seats := public.team_seat_state(inv.org_id);
    if coalesce((v_seats->>'enforced')::boolean, false)
       and (v_seats->>'used')::integer >= (v_seats->>'seats')::integer then
      return jsonb_build_object('error', 'seats_full', 'org_name', v_name,
                                'seats', (v_seats->>'seats')::integer, 'used', (v_seats->>'used')::integer);
    end if;
  end if;

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

  begin
    insert into public.account_org_members (org_id, user_id, role)
    select inv.org_id, p_user_id, case when v_new in ('owner', 'admin') then v_new else 'member' end
     where not exists (select 1 from public.account_org_members a where a.org_id = inv.org_id and a.user_id = p_user_id);
    v_acct := true;
  exception when others then
    v_acct := false;
  end;

  -- mailbox: manga gaya ho to banao, warna "pending" (admin banayega). Kuch bhi ho, join nahi rukta.
  if coalesce(inv.mailbox_local, '') <> '' then
    begin
      select d.id, d.domain into v_dom from public.team_invite_domain(inv.org_id, inv.mailbox_domain_id) d;
      if v_dom.id is null then
        v_mb := jsonb_build_object('status', 'failed', 'error', 'domain_not_verified');
      else
        v_r := public.org_address_create(inv.org_id, v_dom.id, inv.mailbox_local, 'mailbox', p_user_id, null);
        if coalesce((v_r->>'ok')::boolean, false) then
          v_mb := jsonb_build_object('status', 'created', 'address', coalesce(v_r->'address'->>'address', inv.mailbox_local || '@' || v_dom.domain));
        else
          v_mb := jsonb_build_object('status', 'failed', 'error', coalesce(v_r->>'error', 'unknown'));
        end if;
      end if;
    exception when others then
      v_mb := jsonb_build_object('status', 'failed', 'error', 'mailbox_failed');
    end;
  else
    v_mb := jsonb_build_object('status', 'pending');
  end if;

  update public.org_invitations
     set status = 'accepted', accepted_at = now(), accepted_by = p_user_id, mailbox_result = v_mb
   where id = inv.id;

  perform public.team_audit(inv.org_id, v_email, 'invite.accepted', inv.email,
          jsonb_build_object('role', v_new, 'invited_role', inv.role, 'user_id', p_user_id,
                             'rejoin', coalesce(v_status = 'revoked', false), 'mailbox', v_mb->>'status'));

  return jsonb_build_object('ok', true, 'org_id', inv.org_id, 'org_name', v_name, 'role', v_new, 'account_layer', v_acct, 'mailbox', v_mb);
end $$;

-- 7. huqooq: sirf engine (service_role)
revoke all on function public.team_seat_calc(text, integer, integer, integer)               from public, anon, authenticated;
revoke all on function public.team_seat_state(uuid)                                        from public, anon, authenticated;
revoke all on function public.team_audit(uuid, text, text, text, jsonb)                    from public, anon, authenticated;
revoke all on function public.team_invite_domain(uuid, uuid)                               from public, anon, authenticated;
revoke all on function public.team_invite_lookup(uuid)                                     from public, anon, authenticated;
revoke all on function public.team_invite_accept(uuid, uuid, text)                         from public, anon, authenticated;
grant execute on function public.team_seat_calc(text, integer, integer, integer)           to service_role;
grant execute on function public.team_seat_state(uuid)                                     to service_role;
grant execute on function public.team_audit(uuid, text, text, text, jsonb)                 to service_role;
grant execute on function public.team_invite_domain(uuid, uuid)                            to service_role;
grant execute on function public.team_invite_lookup(uuid)                                  to service_role;
grant execute on function public.team_invite_accept(uuid, uuid, text)                      to service_role;

notify pgrst, 'reload schema';
commit;

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
do $$
declare
  v_org    uuid;
  v_user   uuid;
  v_user2  uuid;
  v_user3  uuid;
  v_tok    uuid;
  v_tok2   uuid;
  v_tok3   uuid;
  v_r      jsonb;
  v_n      integer;
  v_chk    integer := 0;
  v_note   text := '';
  v_sql    text;
  v_pair   record;
  v_labels text[];
  v_role_t text := public.team_col_type('role');
  v_seq0   bigint;
  v_seq1   bigint;
  v_hit    boolean;
begin
  perform set_config('anexo.e34_selftest', 'not run', false);
  begin
    -- ---- A. seat hisaab (pure; kisi data ki zaroorat nahi) ----
    v_r := public.team_seat_calc('business_pro', 3, 900, 5);
    if (v_r->>'enforced')::boolean or not (v_r->>'unlimited')::boolean or v_r->'free' <> 'null'::jsonb then
      raise exception 'E34 FAILED: business_pro ko roka ja raha hai %', v_r using errcode = 'AX040';
    end if;
    v_r := public.team_seat_calc('business', 0, 7, 0);
    if (v_r->>'enforced')::boolean or (v_r->>'known')::boolean then
      raise exception 'E34 FAILED: seat ginti na ho to bhi limit lag gayi %', v_r using errcode = 'AX040';
    end if;
    v_r := public.team_seat_calc('business', 5, 3, 1);
    if not (v_r->>'enforced')::boolean or (v_r->>'free')::integer <> 1 then
      raise exception 'E34 FAILED: 5 seat, 3 used, 1 pending => free 1 hona chahiye %', v_r using errcode = 'AX040';
    end if;
    v_r := public.team_seat_calc('pro', 2, 2, 0);
    if (v_r->>'free')::integer <> 0 or not (v_r->>'enforced')::boolean then
      raise exception 'E34 FAILED: bhara hua org free nahi 0 %', v_r using errcode = 'AX040';
    end if;
    v_r := public.team_seat_calc('basic', 2, 5, 4);
    if (v_r->>'free')::integer <> 0 then
      raise exception 'E34 FAILED: seats se zyada used par free negative/ghalat %', v_r using errcode = 'AX040';
    end if;
    v_chk := v_chk + 5;

    -- ---- B. ek org jise sab FK maante hain (E33 jaisa dhoondna) ----
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
      v_note := 'koi organisation row nahi — sirf pure seat-hisaab check hua;';
    else
      select coalesce(array_agg(e.enumlabel::text), array['owner', 'admin', 'member', 'viewer'])
        into v_labels from pg_enum e where e.enumtypid = v_role_t::regtype;

      -- team_seat_state ka shape + ginti asli table se milti hai
      v_r := public.team_seat_state(v_org);
      select count(*) into v_n from public.org_members m where m.org_id = v_org and coalesce(m.status::text, 'active') <> 'revoked';
      if (v_r->>'used')::integer <> v_n or not (v_r ? 'enforced') or not (v_r ? 'pending') then
        raise exception 'E34 FAILED: team_seat_state ka shape/ginti %', v_r using errcode = 'AX040';
      end if;
      v_chk := v_chk + 1;

      -- ---- C. audit: log + chain, ek call mein ----
      if to_regprocedure('public.org_chain_append(text,text,text,text,uuid)') is not null then
        select coalesce(max(c.seq), 0) into v_seq0 from public.org_audit_chain c where c.org_id = v_org;
        v_r := public.team_audit(v_org, 'e34@selftest', 'member.role', 'x@e34.test', jsonb_build_object('from', 'member', 'to', 'admin'));
        select coalesce(max(c.seq), 0) into v_seq1 from public.org_audit_chain c where c.org_id = v_org;
        if not (v_r->>'chain')::boolean or v_seq1 <> v_seq0 + 1 then
          raise exception 'E34 FAILED: chain mein entry nahi gayi % (% -> %)', v_r, v_seq0, v_seq1 using errcode = 'AX040';
        end if;
        select count(*) into v_n from public.org_audit_chain c
         where c.org_id = v_org and c.seq = v_seq1 and c.action = 'team.member.role' and c.actor = 'e34@selftest';
        if v_n <> 1 then raise exception 'E34 FAILED: chain entry ka action/actor ghalat' using errcode = 'AX040'; end if;
        if not exists (select 1 from public.org_chain_verify(v_org) o where o.ok) then
          raise exception 'E34 FAILED: chain verify nahi hui' using errcode = 'AX040';
        end if;
        v_chk := v_chk + 3;
      else
        v_note := v_note || ' chain wala hissa SKIPPED (org_chain_append maujood nahi — phase64 nahi chali);';
      end if;
      v_r := public.team_audit(v_org, 'e34@selftest', 'e34.selftest', 'y', '{}'::jsonb);
      select count(*) into v_n from public.org_people_log where org_id = v_org and action = 'e34.selftest';
      if v_n <> 1 or not (v_r->>'log')::boolean then raise exception 'E34 FAILED: people log nahi likha' using errcode = 'AX040'; end if;
      v_chk := v_chk + 1;

      -- ---- D. join ke teen raaste: seat full, seat khali, mailbox ----
      select u.id into v_user  from auth.users u
       where not exists (select 1 from public.org_members m where m.org_id = v_org and m.user_id = u.id)
       order by u.created_at, u.id limit 1;
      select u.id into v_user2 from auth.users u
       where not exists (select 1 from public.org_members m where m.org_id = v_org and m.user_id = u.id) and u.id is distinct from v_user
       order by u.created_at, u.id limit 1;
      select u.id into v_user3 from auth.users u
       where not exists (select 1 from public.org_members m where m.org_id = v_org and m.user_id = u.id)
         and u.id is distinct from v_user and u.id is distinct from v_user2
       order by u.created_at, u.id limit 1;

      if v_user is null or v_user2 is null or v_user3 is null then
        v_note := v_note || ' join wala hissa SKIPPED — is org ke baghair-member teen auth users nahi mile;';
      elsif not ('member' = any (v_labels)) then
        v_note := v_note || ' join wala hissa SKIPPED — role type mein "member" label nahi;';
      else
        -- (D1) seats bhar gaye => 'seats_full', koi member/invitation badla nahi
        execute $f$create or replace function public.team_seat_state(p_org uuid) returns jsonb language sql as
                   $b$select public.team_seat_calc('business', 4, 4, 1)$b$ $f$;
        insert into public.org_invitations (org_id, email, role) values (v_org, 'full@e34.test', 'member') returning token into v_tok;
        v_r := public.team_invite_accept(v_tok, v_user, 'full@e34.test');
        if v_r->>'error' is distinct from 'seats_full' then raise exception 'E34 FAILED: bhare org mein join ho gaya %', v_r using errcode = 'AX040'; end if;
        select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user;
        if v_n <> 0 then raise exception 'E34 FAILED: seats_full ke baad bhi member ban gaya' using errcode = 'AX040'; end if;
        select count(*) into v_n from public.org_invitations where token = v_tok and status = 'pending';
        if v_n <> 1 then raise exception 'E34 FAILED: seats_full ne invitation kharch kar di' using errcode = 'AX040'; end if;
        v_chk := v_chk + 3;

        -- (D2) business_pro kabhi nahi rukta
        execute $f$create or replace function public.team_seat_state(p_org uuid) returns jsonb language sql as
                   $b$select public.team_seat_calc('business_pro', 1, 999, 0)$b$ $f$;
        v_r := public.team_invite_accept(v_tok, v_user, 'full@e34.test');
        if (v_r->>'ok')::boolean is not true then raise exception 'E34 FAILED: business_pro join nahi hua %', v_r using errcode = 'AX040'; end if;
        if v_r->'mailbox'->>'status' is distinct from 'pending' then raise exception 'E34 FAILED: mailbox maanga nahi tha, pending hona chahiye %', v_r using errcode = 'AX040'; end if;
        v_chk := v_chk + 2;

        -- (D3) khali seat => join; ek seat bacha ho to bhi join (used 3 < seats 4)
        execute $f$create or replace function public.team_seat_state(p_org uuid) returns jsonb language sql as
                   $b$select public.team_seat_calc('business', 4, 3, 1)$b$ $f$;
        insert into public.org_invitations (org_id, email, role) values (v_org, 'free@e34.test', 'member') returning token into v_tok2;
        v_r := public.team_invite_accept(v_tok2, v_user2, 'free@e34.test');
        if (v_r->>'ok')::boolean is not true then raise exception 'E34 FAILED: khali seat par join nahi hua %', v_r using errcode = 'AX040'; end if;
        v_chk := v_chk + 1;

        -- (D4) pehle se active member ka role badalna seat nahi leta (org bhara hone par bhi)
        execute $f$create or replace function public.team_seat_state(p_org uuid) returns jsonb language sql as
                   $b$select public.team_seat_calc('business', 4, 4, 0)$b$ $f$;
        insert into public.org_invitations (org_id, email, role) values (v_org, 'again@e34.test', 'viewer') returning token into v_tok3;
        v_r := public.team_invite_accept(v_tok3, v_user2, 'free@e34.test');
        if (v_r->>'ok')::boolean is not true then raise exception 'E34 FAILED: bhare org mein purane member ki invitation ruk gayi %', v_r using errcode = 'AX040'; end if;
        v_chk := v_chk + 1;

        -- (D5) hataya hua banda wapas aaye to naya seat lagta hai => bhare org mein roka jata hai
        begin
          update public.org_members set status = 'revoked' where org_id = v_org and user_id = v_user2;
          insert into public.org_invitations (org_id, email, role) values (v_org, 'back@e34.test', 'member') returning token into v_tok3;
          v_r := public.team_invite_accept(v_tok3, v_user2, 'free@e34.test');
          if v_r->>'error' is distinct from 'seats_full' then raise exception 'E34 FAILED: revoked banda bhare org mein wapas aa gaya %', v_r using errcode = 'AX040'; end if;
          v_chk := v_chk + 1;
        exception when invalid_text_representation then
          v_note := v_note || ' revoked-wapsi check SKIPPED (status type mein "revoked" label nahi);';
        end;

        -- (D6) mailbox: ban gaya / nakaam / exception — teeno mein join ho jata hai
        execute $f$create or replace function public.team_seat_state(p_org uuid) returns jsonb language sql as
                   $b$select public.team_seat_calc('business_pro', 0, 0, 0)$b$ $f$;
        execute $f$create or replace function public.team_invite_domain(p_org uuid, p_domain_id uuid) returns table (id uuid, domain text)
                   language sql as $b$select gen_random_uuid(), 'e34.test'::text$b$ $f$;
        execute $f$create or replace function public.org_address_create(
                      _org uuid, _domain_id uuid, _local text, _kind text default 'mailbox', _owner uuid default null, _alias_target text default null)
                   returns jsonb language sql as
                   $b$select case when _local = 'taken' then jsonb_build_object('ok', false, 'error', 'address_taken')
                                  else jsonb_build_object('ok', true, 'address', jsonb_build_object('address', _local || '@e34.test', 'owner', _owner)) end$b$ $f$;
        insert into public.org_invitations (org_id, email, role, mailbox_local) values (v_org, 'mb@e34.test', 'member', 'sara') returning token into v_tok;
        v_r := public.team_invite_accept(v_tok, v_user3, 'mb@e34.test');
        if v_r->'mailbox'->>'status' is distinct from 'created' or v_r->'mailbox'->>'address' is distinct from 'sara@e34.test' then
          raise exception 'E34 FAILED: mailbox nahi bana %', v_r using errcode = 'AX040';
        end if;
        select count(*) into v_n from public.org_invitations where token = v_tok and mailbox_result->>'status' = 'created';
        if v_n <> 1 then raise exception 'E34 FAILED: mailbox_result invitation par nahi likha' using errcode = 'AX040'; end if;
        if public.team_invite_accept(v_tok, v_user3, 'mb@e34.test')->'mailbox'->>'status' is distinct from 'created' then
          raise exception 'E34 FAILED: dobara kholne par mailbox jawab badal gaya' using errcode = 'AX040';
        end if;
        v_chk := v_chk + 3;

        -- nakaam mailbox join nahi rokta
        update public.org_members set status = 'revoked' where org_id = v_org and user_id = v_user3;
        insert into public.org_invitations (org_id, email, role, mailbox_local) values (v_org, 'taken@e34.test', 'member', 'taken') returning token into v_tok2;
        v_r := public.team_invite_accept(v_tok2, v_user3, 'taken@e34.test');
        if (v_r->>'ok')::boolean is not true or v_r->'mailbox'->>'error' is distinct from 'address_taken' then
          raise exception 'E34 FAILED: nakaam mailbox ne join roka ya wajah gum %', v_r using errcode = 'AX040';
        end if;
        select count(*) into v_n from public.org_members where org_id = v_org and user_id = v_user3 and status::text = 'active';
        if v_n <> 1 then raise exception 'E34 FAILED: mailbox nakaam hone par member nahi bana' using errcode = 'AX040'; end if;
        v_chk := v_chk + 2;

        -- exception wala mailbox (function toot jaye) bhi join nahi rokta
        execute $f$create or replace function public.org_address_create(
                      _org uuid, _domain_id uuid, _local text, _kind text default 'mailbox', _owner uuid default null, _alias_target text default null)
                   returns jsonb language plpgsql as $b$begin raise exception 'boom'; end$b$ $f$;
        update public.org_members set status = 'revoked' where org_id = v_org and user_id = v_user3;
        insert into public.org_invitations (org_id, email, role, mailbox_local) values (v_org, 'boom@e34.test', 'member', 'boom') returning token into v_tok2;
        v_r := public.team_invite_accept(v_tok2, v_user3, 'boom@e34.test');
        if (v_r->>'ok')::boolean is not true or v_r->'mailbox'->>'status' is distinct from 'failed' then
          raise exception 'E34 FAILED: toota hua mailbox function join rok gaya %', v_r using errcode = 'AX040';
        end if;
        v_chk := v_chk + 1;

        -- join ka audit: chain/log mein 'invite.accepted' ek hi baar
        select count(*) into v_n from public.org_people_log where org_id = v_org and action = 'invite.accepted' and target = 'mb@e34.test';
        if v_n <> 1 then raise exception 'E34 FAILED: join ka people log (%)', v_n using errcode = 'AX040'; end if;
        v_chk := v_chk + 1;
      end if;

      -- ghalat mailbox naam (check constraint)
      v_hit := false;
      begin
        insert into public.org_invitations (org_id, email, mailbox_local) values (v_org, 'bad@e34.test', 'Bad Name');
      exception when check_violation then v_hit := true;
      end;
      if not v_hit then raise exception 'E34 FAILED: ghalat mailbox naam chal gaya' using errcode = 'AX040'; end if;
      v_chk := v_chk + 1;
    end if;

    -- huqooq
    if has_function_privilege('anon', 'public.team_seat_state(uuid)', 'execute')
       or has_function_privilege('authenticated', 'public.team_seat_state(uuid)', 'execute')
       or has_function_privilege('authenticated', 'public.team_audit(uuid,text,text,text,jsonb)', 'execute')
       or has_function_privilege('authenticated', 'public.team_invite_accept(uuid,uuid,text)', 'execute') then
      raise exception 'E34 FAILED: browser ke roles ko naye functions ke huqooq mile hue hain' using errcode = 'AX040';
    end if;
    if not has_function_privilege('service_role', 'public.team_seat_state(uuid)', 'execute')
       or not has_function_privilege('service_role', 'public.team_audit(uuid,text,text,text,jsonb)', 'execute') then
      raise exception 'E34 FAILED: service_role ko huqooq nahi mile' using errcode = 'AX040';
    end if;
    v_chk := v_chk + 2;

    raise exception 'rollback marker' using errcode = 'AX099';   -- test ka saara data AUR test mein badle hue stub functions wapas
  exception when sqlstate 'AX099' then
    null;
  end;

  perform set_config('anexo.e34_selftest',
    case when v_note = '' then format('PASSED (%s checks, sab rollback)', v_chk)
         else format('PASSED with notes (%s checks, sab rollback) — %s (yeh line mujhe bhej dein)', v_chk, btrim(v_note)) end,
    false);
end $$;

-- ============================ jawab: ek row ===============================
select
  'E34 OK — schema lag gaya' as e34_result,
  current_setting('anexo.e34_selftest', true) as selftest,
  pg_get_functiondef('public.team_seat_state(uuid)'::regprocedure) like '%org_plan_of%' as seat_state_is_the_real_one,
  (to_regprocedure('public.org_chain_append(text,text,text,text,uuid)') is not null) as audit_chain_available,
  (to_regprocedure('public.org_address_create(uuid,uuid,text,text,uuid,text)') is not null) as mailbox_creator_available,
  (select count(*) from public.org_invitations where mailbox_local is not null) as invitations_with_mailbox;
