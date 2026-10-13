-- =============================================================================
-- E24 — account delete system (founder request, 14 Oct 2026).
-- Supabase #4 SQL Editor mein poori file paste -> Run. Idempotent.
--
-- KYA BANTA HAI
--   1) public.account_deletions        — schedule + audit (user_id par FK NAHI: user
--                                         delete ho jaye to bhi record rahe).
--   2) account_deletion_blockers()     — kaun si cheez delete rokti hai.
--   3) account_deletion_request/cancel/state() — self-service (Bun route, service_role).
--   4) account_purge()                 — asli delete. SIRF founder, SQL Editor se.
--                                         Default DRY-RUN. App/API isay kabhi nahi bulati.
--
-- SAFETY (locked)
--   * Request ke baad 7 din ka grace; user beech mein cancel kar sakta hai.
--   * Request/cancel/state sirf service_role (Bun user ki id verify karke bulata hai).
--   * account_purge par KISI role ka execute nahi (service_role ka bhi nahi) —
--     sirf SQL Editor (postgres).
--   * Dry-run asli deletes chalata hai aur phir rollback karta hai, to FK / trigger
--     ki har rukawat dry-run mein hi dikh jati hai. Asli run ya poora hota hai
--     ya kuch bhi nahi (ek transaction).
--   * Blockers: founder account, aise org ka owner jis mein dusre members hon,
--     active/past_due/grace Polar subscription, Storage mein files.
--   * Sirf us user ka data: user_id/owner_id/owner_user_id wali rows + woh orgs
--     jin mein woh AKELA member hai (unki org_id rows samet). Dusre ke org ko
--     haath nahi.
--
-- FOUNDER DECISIONS (jo is file mein baked hain)
--   * 7 "immutable ledger" tables (trial_events, billing_event_receipts,
--     ai_credit_ledger, movein_audit, mail_inbound_raw, mail_outbox_log,
--     crm_evidence) purge ki transaction mein HI unlock hote hain, sirf un
--     tables par jin mein is user ki rows hon; auth user delete hote hi
--     dobara locked (usi transaction mein). Wajah: unke triggers cascade delete ko bhi rok dete hain.
--   * ON DELETE SET NULL wali tables (tickets, release events waghera) delete
--     nahi hoti, sirf user_id null hota hai (report mein anonymised_rows).
--   * Hataya hua @anexomail.com handle dobara kisi ko nahi milta
--     (reserved_handles, reason 'deleted') jab tak _release_handle = true na ho.
-- =============================================================================
set search_path = public, extensions;

-- 1) schedule + audit ---------------------------------------------------------
create table if not exists public.account_deletions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null,
  email         text,
  email_hash    text,
  state         text not null default 'scheduled'
                  check (state in ('scheduled', 'cancelled', 'purged')),
  requested_by  text not null default 'self' check (requested_by in ('self', 'founder')),
  requested_at  timestamptz not null default now(),
  scheduled_for timestamptz not null,
  cancelled_at  timestamptz,
  purged_at     timestamptz,
  purge_report  jsonb
);
create unique index if not exists account_deletions_one_scheduled_uq
  on public.account_deletions (user_id) where state = 'scheduled';
create index if not exists account_deletions_due_idx
  on public.account_deletions (scheduled_for) where state = 'scheduled';

alter table public.account_deletions enable row level security;
revoke all on public.account_deletions from anon, authenticated;
grant all on public.account_deletions to service_role;

-- 2) helpers (andar ke, koi role execute nahi kar sakta) -----------------------
create or replace function public._ad_has_col(_tbl text, _col text)
returns boolean language sql stable set search_path = public, pg_temp as $$
  select exists (
    select 1 from pg_attribute a
     where a.attrelid = to_regclass('public.' || quote_ident(_tbl))
       and a.attname = _col and a.attnum > 0 and not a.attisdropped
  )
$$;

-- user kin orgs ka hissa hai; kis ka owner hai; baqi kitne members hain.
create or replace function public.account_deletion_orgs(_user uuid)
returns table (org_id uuid, is_owner boolean, other_members int)
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  r record;
  ids uuid[] := '{}';
  owners uuid[] := '{}';
  one uuid;
  q text;
  st text;
  n int;
begin
  if to_regclass('public.org_members') is not null then
    for r in execute format(
      'select m.org_id as org_ref, (m.role::text = ''owner'') as own from public.org_members m where m.user_id = %L', _user)
    loop
      ids := ids || r.org_ref;
      if r.own then owners := owners || r.org_ref; end if;
    end loop;
  end if;
  if to_regclass('public.organisations') is not null and public._ad_has_col('organisations', 'owner_id') then
    for r in execute format('select o.id as org_ref from public.organisations o where o.owner_id = %L', _user) loop
      ids := ids || r.org_ref;
      owners := owners || r.org_ref;
    end loop;
  end if;
  if to_regclass('public.account_org_members') is not null then
    for r in execute format(
      'select m.org_id as org_ref, (m.role = ''owner'') as own from public.account_org_members m where m.user_id = %L', _user)
    loop
      ids := ids || r.org_ref;
      if r.own then owners := owners || r.org_ref; end if;
    end loop;
  end if;
  if to_regclass('public.account_organisations') is not null then
    for r in execute format('select o.id as org_ref from public.account_organisations o where o.created_by = %L', _user) loop
      ids := ids || r.org_ref;
      owners := owners || r.org_ref;
    end loop;
  end if;

  for one in select distinct x from unnest(ids) as x loop
    q := '';
    if to_regclass('public.org_members') is not null then
      st := case when public._ad_has_col('org_members', 'status')
                 then ' and coalesce(m.status::text, ''active'') not in (''removed'',''revoked'',''inactive'',''disabled'',''declined'')'
                 else '' end;
      q := format('select m.user_id from public.org_members m where m.org_id = %L and m.user_id <> %L', one, _user) || st;
    end if;
    if to_regclass('public.account_org_members') is not null then
      q := case when q = '' then '' else q || ' union ' end
        || format('select m.user_id from public.account_org_members m where m.org_id = %L and m.user_id <> %L', one, _user);
    end if;
    if q = '' then
      n := 0;
    else
      execute 'select count(*) from (' || q || ') s' into n;
    end if;
    org_id := one;
    is_owner := one = any(owners);
    other_members := n;
    return next;
  end loop;
end $$;
revoke all on function public._ad_has_col(text, text) from public, anon, authenticated, service_role;
revoke all on function public.account_deletion_orgs(uuid) from public, anon, authenticated, service_role;

-- 3) blockers ------------------------------------------------------------------
create or replace function public.account_deletion_blockers(_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  out jsonb := '[]'::jsonb;
  r record;
  n bigint;
begin
  if to_regclass('public.founder_accounts') is not null then
    execute format('select count(*) from public.founder_accounts where user_id = %L', _user) into n;
    if n > 0 then
      out := out || jsonb_build_array(jsonb_build_object(
        'code', 'founder_account', 'message', 'Founder accounts cannot be deleted.'));
    end if;
  end if;

  for r in select * from public.account_deletion_orgs(_user) o where o.is_owner and o.other_members > 0 loop
    out := out || jsonb_build_array(jsonb_build_object(
      'code', 'org_has_other_members', 'org_id', r.org_id, 'members', r.other_members,
      'message', 'Your workspace still has other members. Remove them or transfer ownership first.'));
  end loop;

  if to_regclass('public.polar_subscriptions') is not null then
    execute format(
      'select count(*) from public.polar_subscriptions where user_id = %L and status in (''active'',''past_due'',''grace'')',
      _user) into n;
    if n > 0 then
      out := out || jsonb_build_array(jsonb_build_object(
        'code', 'active_subscription',
        'message', 'You still have an active paid plan. It has to be cancelled and ended before the account can be deleted — contact support if you need help.'));
    end if;
  end if;

  return out;
end $$;
revoke all on function public.account_deletion_blockers(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_blockers(uuid) to service_role;

-- 4) self-service: state / request / cancel ------------------------------------
create or replace function public.account_deletion_state(_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  d public.account_deletions;
  b jsonb;
begin
  b := public.account_deletion_blockers(_user);
  select * into d from public.account_deletions where user_id = _user and state = 'scheduled';
  if d.id is null then
    return jsonb_build_object('scheduled', false, 'blockers', b);
  end if;
  return jsonb_build_object(
    'scheduled', true,
    'requested_at', d.requested_at,
    'scheduled_for', d.scheduled_for,
    'days_left', greatest(0, ceil(extract(epoch from (d.scheduled_for - now())) / 86400)::int),
    'blockers', b);
end $$;
revoke all on function public.account_deletion_state(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_state(uuid) to service_role;

create or replace function public.account_deletion_request(_user uuid, _confirm_email text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_email text;
  d public.account_deletions;
  b jsonb;
begin
  select u.email into v_email from auth.users u where u.id = _user;
  if v_email is null then
    return jsonb_build_object('ok', false, 'error', 'user_not_found');
  end if;
  if lower(btrim(coalesce(_confirm_email, ''))) <> lower(btrim(v_email)) then
    return jsonb_build_object('ok', false, 'error', 'email_mismatch');
  end if;

  select * into d from public.account_deletions where user_id = _user and state = 'scheduled';
  if d.id is not null then
    return jsonb_build_object('ok', true, 'already_scheduled', true, 'scheduled_for', d.scheduled_for);
  end if;

  b := public.account_deletion_blockers(_user);
  if jsonb_array_length(b) > 0 then
    return jsonb_build_object('ok', false, 'error', 'blocked', 'blockers', b);
  end if;

  insert into public.account_deletions (user_id, email, email_hash, requested_by, scheduled_for)
  values (_user, v_email, encode(sha256(convert_to(lower(v_email), 'UTF8')), 'hex'), 'self', now() + interval '7 days')
  returning * into d;
  return jsonb_build_object('ok', true, 'already_scheduled', false, 'scheduled_for', d.scheduled_for);
exception when unique_violation then
  select * into d from public.account_deletions where user_id = _user and state = 'scheduled';
  return jsonb_build_object('ok', true, 'already_scheduled', true, 'scheduled_for', d.scheduled_for);
end $$;
revoke all on function public.account_deletion_request(uuid, text) from public, anon, authenticated;
grant execute on function public.account_deletion_request(uuid, text) to service_role;

create or replace function public.account_deletion_cancel(_user uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  n bigint;
begin
  update public.account_deletions
     set state = 'cancelled', cancelled_at = now()
   where user_id = _user and state = 'scheduled';
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'cancelled', n > 0);
end $$;
revoke all on function public.account_deletion_cancel(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_cancel(uuid) to service_role;

-- 5) PURGE — sirf founder, SQL Editor se -----------------------------------------
--   dry-run (default):  select jsonb_pretty(public.account_purge('<user uuid>'));
--   asli (grace ke baad): select jsonb_pretty(public.account_purge('<uuid>', false));
--   grace chhod kar (test account): ... account_purge('<uuid>', false, true);
--   handle dobara istemal ke liye chhodna: ... , _release_handle => true
create or replace function public.account_purge(
  _user uuid,
  _dry_run boolean default true,
  _skip_grace boolean default false,
  _release_handle boolean default false
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_email    text;
  v_hash     text;
  v_d        public.account_deletions;
  v_blockers jsonb;
  v_orgs     uuid[] := '{}';
  r          record;
  w          jsonb;
  v_work     jsonb := '[]'::jsonb;
  v_pending  jsonb;
  v_next     jsonb;
  v_pass     int := 0;
  v_n        bigint;
  key        text;
  v_pre      jsonb := '{}'::jsonb;
  v_expl     jsonb := '{}'::jsonb;
  v_casc     jsonb := '{}'::jsonb;
  v_anon     jsonb := '{}'::jsonb;
  v_ledgers  text[] := '{}';
  v_unlocked jsonb := '[]'::jsonb;
  v_addrs    text[] := '{}';
  v_domains  text[] := '{}';
  v_tmp      text[];
  v_handle   text;
  v_addr0    text;
  v_report   jsonb;
begin
  select u.email into v_email from auth.users u where u.id = _user;
  if v_email is null then
    return jsonb_build_object('ok', false, 'error', 'user_not_found');
  end if;
  v_hash := encode(sha256(convert_to(lower(v_email), 'UTF8')), 'hex');

  v_blockers := public.account_deletion_blockers(_user);
  if jsonb_array_length(v_blockers) > 0 then
    return jsonb_build_object('ok', false, 'error', 'blocked', 'blockers', v_blockers);
  end if;

  select * into v_d from public.account_deletions where user_id = _user and state = 'scheduled';
  if not _dry_run and not _skip_grace then
    if v_d.id is null then
      return jsonb_build_object('ok', false, 'error', 'not_scheduled',
        'hint', 'Pehle user se request karwao, ya test account ke liye _skip_grace => true.');
    end if;
    if v_d.scheduled_for > now() then
      return jsonb_build_object('ok', false, 'error', 'grace_not_over', 'scheduled_for', v_d.scheduled_for);
    end if;
  end if;

  -- Supabase Storage ki files SQL se delete nahi hoti (bucket mein orphan reh jati hain).
  if to_regclass('storage.objects') is not null then
    for r in
      select a.attname::text as col from pg_attribute a
       where a.attrelid = to_regclass('storage.objects') and a.attname in ('owner_id', 'owner')
         and a.attnum > 0 and not a.attisdropped
    loop
      execute format('select count(*) from storage.objects where %I::text = %L', r.col, _user::text) into v_n;
      if v_n > 0 then
        return jsonb_build_object('ok', false, 'error', 'storage_objects_exist', 'count', v_n,
          'hint', 'Pehle Storage mein is user ki files delete karo (Dashboard ya Storage API), phir purge.');
      end if;
    end loop;
  end if;

  -- sirf woh orgs jin mein yeh akela member hai
  select coalesce(array_agg(o.org_id), '{}') into v_orgs
    from public.account_deletion_orgs(_user) o where o.other_members = 0;

  -- delete se PEHLE woh cheezein padh lo jo baad mein server cleanup ke kaam aayengi
  select t.anexomail_handle, t.anexomail_address into v_handle, v_addr0
    from public.trial_accounts t where t.user_id = _user;
  if v_addr0 is not null then v_addrs := array[lower(v_addr0)]; end if;
  if cardinality(v_orgs) > 0 then
    for r in select * from (values ('mail_accounts', 'address'), ('mailboxes', 'address'), ('org_addresses', 'address')) as v(t, c) loop
      if to_regclass('public.' || quote_ident(r.t)) is not null
         and public._ad_has_col(r.t, 'org_id') and public._ad_has_col(r.t, r.c) then
        execute format('select array_agg(distinct lower(%I::text)) from public.%I where org_id = any(%L::uuid[])',
                       r.c, r.t, v_orgs) into v_tmp;
        v_addrs := v_addrs || coalesce(v_tmp, '{}');
      end if;
    end loop;
    if to_regclass('public.org_domains') is not null and public._ad_has_col('org_domains', 'org_id') then
      execute format('select array_agg(distinct lower(domain::text)) from public.org_domains where org_id = any(%L::uuid[])',
                     v_orgs) into v_tmp;
      v_domains := coalesce(v_tmp, '{}');
    end if;
  end if;

  begin  -- ek unit: poora ya kuch nahi (dry-run mein bhi rollback)
    perform set_config('lock_timeout', '5s', true);

    -- A) auth.users par FK wali tables
    for r in
      select n.nspname::text as s, c.relname::text as t, a.attname::text as col, con.confdeltype::text as d
        from pg_constraint con
        join pg_class c on c.oid = con.conrelid
        join pg_namespace n on n.oid = c.relnamespace
        join pg_attribute a on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
       where con.contype = 'f' and con.confrelid = to_regclass('auth.users')
         and cardinality(con.conkey) = 1 and con.conparentid = 0
         and n.nspname not in ('auth', 'pg_catalog', 'information_schema')
         and c.relkind in ('r', 'p')
    loop
      execute format('select count(*) from %I.%I where %I = %L', r.s, r.t, r.col, _user) into v_n;
      if r.s <> 'public' then
        if v_n > 0 then
          raise exception 'foreign_schema_rows: %.% has % row(s) for this user — delete them first', r.s, r.t, v_n;
        end if;
        continue;
      end if;
      key := r.t;
      v_pre := v_pre || jsonb_build_object(key, coalesce((v_pre ->> key)::bigint, 0) + v_n);
      if r.d = 'c' then
        if v_n > 0 then v_casc := v_casc || jsonb_build_object(key, coalesce((v_casc ->> key)::bigint, 0) + v_n); end if;
      elsif r.d in ('n', 'd') then
        if v_n > 0 then v_anon := v_anon || jsonb_build_object(key, coalesce((v_anon ->> key)::bigint, 0) + v_n); end if;
      elsif v_n > 0 then
        v_work := v_work || jsonb_build_array(jsonb_build_object('s', r.s, 't', r.t, 'c', r.col, 'm', 'user'));
      end if;
    end loop;

    -- B) FK ke baghair user_id / owner_id / owner_user_id
    for r in
      select c.relname::text as t, a.attname::text as col
        from pg_attribute a
        join pg_class c on c.oid = a.attrelid
        join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition
         and a.attnum > 0 and not a.attisdropped and a.atttypid = 'uuid'::regtype
         and a.attname in ('user_id', 'owner_id', 'owner_user_id')
         and c.relname not in ('account_deletions', 'organisations', 'orgs', 'account_organisations')
         and not exists (
           select 1 from pg_constraint k
            where k.conrelid = c.oid and k.contype = 'f' and k.confrelid = to_regclass('auth.users')
              and cardinality(k.conkey) = 1 and k.conkey[1] = a.attnum)
    loop
      execute format('select count(*) from public.%I where %I = %L', r.t, r.col, _user) into v_n;
      if v_n > 0 then
        key := r.t;
        v_pre := v_pre || jsonb_build_object(key, coalesce((v_pre ->> key)::bigint, 0) + v_n);
        v_work := v_work || jsonb_build_array(jsonb_build_object('s', 'public', 't', r.t, 'c', r.col, 'm', 'user'));
      end if;
    end loop;

    -- C) sole-member orgs: unki org_id wali rows, phir org ki apni row
    if cardinality(v_orgs) > 0 then
      for r in
        select c.relname::text as t
          from pg_attribute a
          join pg_class c on c.oid = a.attrelid
          join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition
           and a.attname = 'org_id' and a.attnum > 0 and not a.attisdropped and a.atttypid = 'uuid'::regtype
           and c.relname not in ('account_deletions', 'organisations', 'orgs', 'account_organisations')
      loop
        execute format('select count(*) from public.%I where org_id = any(%L::uuid[])', r.t, v_orgs) into v_n;
        if v_n > 0 then
          key := r.t;
          v_pre := v_pre || jsonb_build_object(key, coalesce((v_pre ->> key)::bigint, 0) + v_n);
          v_work := v_work || jsonb_build_array(jsonb_build_object('s', 'public', 't', r.t, 'c', 'org_id', 'm', 'org'));
        end if;
      end loop;
      for r in select * from (values ('organisations'), ('orgs'), ('account_organisations')) as v(t) loop
        if to_regclass('public.' || quote_ident(r.t)) is not null then
          execute format('select count(*) from public.%I where id = any(%L::uuid[])', r.t, v_orgs) into v_n;
          if v_n > 0 then
            key := r.t;
            v_pre := v_pre || jsonb_build_object(key, v_n);
            v_work := v_work || jsonb_build_array(jsonb_build_object('s', 'public', 't', r.t, 'c', 'id', 'm', 'org'));
          end if;
        end if;
      end loop;
    end if;

    -- D) immutable ledgers: sirf jin mein is user ki rows hon, sirf is transaction ke liye
    for r in
      select n.nspname::text as s, c.relname::text as t, g.tgname::text as trg, g.tgenabled::text as en
        from pg_trigger g
        join pg_class c on c.oid = g.tgrelid
        join pg_namespace n on n.oid = c.relnamespace
       where not g.tgisinternal and n.nspname = 'public' and g.tgenabled <> 'D'
         and (c.relname::text, g.tgname::text) in (
           values ('trial_events', 'trial_events_no_update'),
                  ('billing_event_receipts', 'billing_receipts_immutable'),
                  ('ai_credit_ledger', 'ai_ledger_no_update'),
                  ('movein_audit', 'movein_audit_no_change'),
                  ('mail_inbound_raw', 'mail_inbound_raw_immutable'),
                  ('mail_outbox_log', 'mail_outbox_log_immutable'),
                  ('crm_evidence', 'crm_evidence_no_update'))
    loop
      if coalesce((v_pre ->> r.t)::bigint, 0) > 0 then
        execute format('alter table %I.%I disable trigger %I', r.s, r.t, r.trg);
        v_ledgers := v_ledgers || r.t;
        v_unlocked := v_unlocked || jsonb_build_array(
          jsonb_build_object('s', r.s, 't', r.t, 'trg', r.trg, 'en', r.en));
      end if;
    end loop;

    -- E) explicit deletes; FK ki wajah se rukein to agle pass mein dobara
    v_pending := v_work;
    loop
      exit when jsonb_array_length(v_pending) = 0;
      v_pass := v_pass + 1;
      v_next := '[]'::jsonb;
      for w in select value from jsonb_array_elements(v_pending) loop
        begin
          if w ->> 'm' = 'user' then
            execute format('delete from %I.%I where %I = %L', w ->> 's', w ->> 't', w ->> 'c', _user);
          else
            execute format('delete from %I.%I where %I = any(%L::uuid[])', w ->> 's', w ->> 't', w ->> 'c', v_orgs);
          end if;
          get diagnostics v_n = row_count;
          if v_n > 0 then
            key := w ->> 't';
            v_expl := v_expl || jsonb_build_object(key, coalesce((v_expl ->> key)::bigint, 0) + v_n);
          end if;
        exception when foreign_key_violation then
          v_next := v_next || jsonb_build_array(w);
        end;
      end loop;
      exit when jsonb_array_length(v_next) = jsonb_array_length(v_pending) or v_pass >= 10;
      v_pending := v_next;
    end loop;
    if jsonb_array_length(v_pending) > 0 then
      raise exception 'purge_blocked: FK ke wajah se in tables se rows nahi hati: %', v_pending::text;
    end if;

    -- F) handle quarantine, phir auth user (baqi cascade/set null DB khud karta hai)
    if v_handle is not null and not _release_handle then
      insert into public.reserved_handles (handle, reason) values (lower(v_handle), 'deleted')
      on conflict (handle) do nothing;
    end if;

    delete from auth.users where id = _user;
    get diagnostics v_n = row_count;
    if v_n <> 1 then
      raise exception 'auth_user_not_deleted';
    end if;

    -- ledgers wapas LOCK (asli run mein yeh commit hota hai — dobara enable zaroori hai)
    for w in select value from jsonb_array_elements(v_unlocked) loop
      execute format('alter table %I.%I %s trigger %I', w ->> 's', w ->> 't',
        case w ->> 'en' when 'A' then 'enable always' when 'R' then 'enable replica' else 'enable' end,
        w ->> 'trg');
    end loop;

    v_report := jsonb_build_object(
      'ok', true,
      'dry_run', _dry_run,
      'user_id', _user,
      'handle', v_handle,
      'handle_quarantined', (v_handle is not null and not _release_handle),
      'orgs_purged', to_jsonb(v_orgs),
      'mail_addresses', to_jsonb(array(select distinct unnest(v_addrs) order by 1)),
      'domains', to_jsonb(array(select distinct unnest(v_domains) order by 1)),
      'deleted_rows', v_expl,
      'cascaded_rows', v_casc,
      'anonymised_rows', v_anon,
      'ledgers_unlocked', to_jsonb(v_ledgers),
      'grace', jsonb_build_object('scheduled_for', v_d.scheduled_for, 'over', v_d.scheduled_for <= now()));

    if _dry_run then
      raise exception 'dry_run' using errcode = 'DR001';
    end if;

    update public.account_deletions
       set email = null, email_hash = v_hash
     where user_id = _user;
    update public.account_deletions
       set state = 'purged', purged_at = now(), purge_report = v_report - 'mail_addresses' - 'handle'
     where user_id = _user and state = 'scheduled';
    get diagnostics v_n = row_count;
    if v_n = 0 then
      insert into public.account_deletions
        (user_id, email_hash, state, requested_by, scheduled_for, purged_at, purge_report)
      values (_user, v_hash, 'purged', 'founder', now(), now(), v_report - 'mail_addresses' - 'handle');
    end if;
    return v_report;
  exception
    when sqlstate 'DR001' then
      return v_report;
    when others then
      return jsonb_build_object('ok', false, 'error', 'purge_failed', 'dry_run', _dry_run,
                                'detail', sqlerrm, 'sqlstate', sqlstate);
  end;
end $$;
revoke all on function public.account_purge(uuid, boolean, boolean, boolean)
  from public, anon, authenticated, service_role;

notify pgrst, 'reload schema';

-- Verify (read-only):
-- select proname from pg_proc where proname in
--   ('account_purge','account_deletion_request','account_deletion_cancel','account_deletion_state','account_deletion_blockers');
-- select has_function_privilege('service_role', 'public.account_purge(uuid,boolean,boolean,boolean)', 'execute') as purge_open_to_service_role; -- false hona chahiye
