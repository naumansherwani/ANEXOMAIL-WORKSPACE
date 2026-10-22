
-- E68 — identity vault ko founder ke maujooda Block / Release / Appeal se jorna (founder ka koi naya kaam nahi)
--   * raw -> HMAC wrappers (key server env se aati hai, DB mein kabhi nahi)
--   * account_integrity 'blocked' => sab nishan blacklist; 'released' => ban hat jate hain (severe ke siwa)
--   * device appeal 'granted' => us account ke ban hat jate hain
--   * signup deny hone par logged-out appeal (identity_signup_appeals) + founder ka faisla
--   * review (shared device / weak match) signup rokta nahi: account_integrity mein 'suspicious' flag, faisla insaan ka
--   * identity_admin_overview: ek nazar ka hisaab
-- Rule 38 (advanced), 42 (editor compat), 43 (RLS ON), 44 (server se chalta hai). Idempotent.
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. canonical email + HMAC ---------------------------------------------------------------------------------------------------
create or replace function public.identity_canon_email(p_email text)
returns text language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select case when p_email is null or position('@' in p_email) < 2 then null else
    (select case when d in ('gmail.com', 'googlemail.com') then replace(split_part(l, '+', 1), '.', '') || '@gmail.com'
                 else split_part(l, '+', 1) || '@' || d end
       from (select lower(btrim(split_part(p_email, '@', 1))) as l, lower(btrim(split_part(p_email, '@', 2))) as d) x)
  end
$$;

create or replace function public.identity_hmac_hex(p_kind text, p_canon text, p_key text)
returns text language sql immutable parallel safe set search_path = pg_catalog, public, extensions as $$
  select case when p_canon is null or btrim(p_canon) = '' then null else
    encode(extensions.hmac(convert_to(p_canon, 'UTF8'),
             extensions.hmac(convert_to('anexomail/identity/v1/' || p_kind, 'UTF8'), convert_to(coalesce(nullif(p_key, ''), 'no-pepper'), 'UTF8'), 'sha256'),
             'sha256'), 'hex') end
$$;

-- raw nishaniyan -> signals jsonb (sirf jo diye gaye)
create or replace function public.identity_signals_raw(p_email text, p_recovery text, p_device_key text, p_shape text, p_network text, p_key text)
returns jsonb language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('kind', k, 'hmac', h)), '[]'::jsonb) from (
    values ('email',        public.identity_hmac_hex('email',        public.identity_canon_email(p_email), p_key)),
           ('recovery',     public.identity_hmac_hex('recovery',     public.identity_canon_email(p_recovery), p_key)),
           ('device_key',   public.identity_hmac_hex('device_key',   lower(btrim(p_device_key)), p_key)),
           ('device_shape', public.identity_hmac_hex('device_shape', lower(btrim(p_shape)), p_key)),
           ('network',      public.identity_hmac_hex('network',      lower(btrim(p_network)), p_key))
  ) v (k, h) where h is not null
$$;

create or replace function public.identity_signup_check_raw(p_email text, p_recovery text, p_device_key text, p_shape text, p_network text, p_key text)
returns jsonb language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare s jsonb := public.identity_signals_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_key);
begin
  if jsonb_array_length(s) = 0 then return jsonb_build_object('decision', 'allow', 'matched', '[]'::jsonb, 'appealable', true, 'reason', null); end if;
  return public.identity_signup_check(s);
end $$;

-- register + review => founder ki maujooda queue mein 'suspicious' (signup phir bhi nahi rukta; faisla insaan karta hai)
create or replace function public.identity_register_raw(p_account uuid, p_email text, p_recovery text, p_device_key text, p_shape text, p_network text, p_key text)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare s jsonb := public.identity_signals_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_key); r jsonb;
begin
  if jsonb_array_length(s) = 0 then return jsonb_build_object('decision', 'allow', 'registered', 0); end if;
  r := public.identity_register(p_account, s);
  if r ->> 'decision' = 'review' and to_regclass('public.account_integrity') is not null then
    insert into public.account_integrity (user_id, state, reason, evidence)
    values (p_account, 'suspicious', 'identity vault: ' || coalesce(r ->> 'reason', 'review'), jsonb_build_object('source', 'identity_vault', 'reason', r ->> 'reason'))
    on conflict (user_id) do update
      set state = case when public.account_integrity.state = 'clean' then 'suspicious' else public.account_integrity.state end,
          reason = case when public.account_integrity.state = 'clean' then excluded.reason else public.account_integrity.reason end,
          updated_at = now();
  end if;
  return r;
end $$;

-- payment nishan (Polar webhook se, sirf padhne wala hawala): ek hi shakhs ka card/email dobara naya account na banaye
create or replace function public.identity_register_payment(p_account uuid, p_ref text, p_key text)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare h text := public.identity_hmac_hex('payment', lower(btrim(p_ref)), p_key); pol public.identity_vault_policy;
begin
  if p_account is null or h is null then return jsonb_build_object('registered', 0); end if;
  select * into pol from public.identity_vault_policy where id = 1;
  insert into public.identity_signals (account_id, kind, hmac, key_id, retain_until) values (p_account, 'payment', decode(h, 'hex'), pol.key_id, null)
  on conflict (account_id, kind, hmac) do update set last_seen = now(), seen_count = public.identity_signals.seen_count + 1;
  return jsonb_build_object('registered', 1);
end $$;

-- ---- 2. block / release / appeal => vault (maujooda buttons hi kaam karte hain) -------------------------------------------------
create or replace function public.identity_reason_from_text(p_text text)
returns text language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select case
    when p_text ~* '(severe|csam|child|terror|threat|violence|doxx)' then 'severe_pattern'
    when p_text ~* '(fraud|chargeback|stolen|scam|carding|payment abuse)' then 'fraud'
    when p_text ~* '(spam|bulk|phish)' then 'spam'
    when p_text ~* '(abuse|harass|bully|hate)' then 'abuse'
    else 'policy_violation' end
$$;

create or replace function public.identity_integrity_trg()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare rsn text;
begin
  if new.state = 'blocked' and old.state is distinct from 'blocked' then
    rsn := public.identity_reason_from_text(new.reason);
    perform public.identity_ban_account(new.user_id, rsn, false, new.blocked_by);
  elsif new.state = 'released' and old.state = 'blocked' then
    perform public.identity_ban_lift(new.user_id, coalesce(old.blocked_by, new.blocked_by, new.warned_by, '00000000-0000-0000-0000-000000000000'::uuid));
  end if;
  return new;
exception when others then
  -- vault ki galti account_integrity ka faisla kabhi nahi rokti; audit mein nishan chhod do
  insert into public.identity_vault_audit (event, account_id, detail) values ('deny', new.user_id, jsonb_build_object('trigger_error', left(sqlerrm, 200)));
  return new;
end $$;

create or replace function public.identity_appeal_trg()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if new.state = 'granted' and old.state is distinct from 'granted' and new.decided_by is not null then
    perform public.identity_ban_lift(new.user_id, new.decided_by);
  end if;
  return new;
exception when others then
  insert into public.identity_vault_audit (event, account_id, detail) values ('deny', new.user_id, jsonb_build_object('trigger_error', left(sqlerrm, 200)));
  return new;
end $$;

do $$
begin
  if to_regclass('public.account_integrity') is not null then
    drop trigger if exists identity_integrity_ai on public.account_integrity;
    create trigger identity_integrity_ai after update of state on public.account_integrity
      for each row execute function public.identity_integrity_trg();
  end if;
  if to_regclass('public.device_ban_appeals') is not null then
    drop trigger if exists identity_appeal_ai on public.device_ban_appeals;
    create trigger identity_appeal_ai after update of state on public.device_ban_appeals
      for each row execute function public.identity_appeal_trg();
  end if;
end $$;

-- ---- 3. logged-out appeal (signup deny hone par) ------------------------------------------------------------------------------------
create table if not exists public.identity_signup_appeals (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  contact     text        not null check (char_length(contact) between 5 and 254),   -- jawab dene ka pata; 90 din baad mit jata hai
  statement   text        not null check (char_length(statement) between 20 and 2000),
  source_refs uuid[]      not null default '{}',                                       -- kis (mit chuke) account ke ban se takra raha hai
  state       text        not null default 'new' check (state in ('new', 'granted', 'denied')),
  decided_by  uuid,
  decided_at  timestamptz,
  decision_reason text check (decision_reason is null or char_length(decision_reason) between 12 and 1000),
  constraint identity_signup_appeals_dec_ck check ((state = 'new') = (decided_at is null))
);
create index if not exists identity_signup_appeals_state_idx on public.identity_signup_appeals (state, created_at desc);
alter table public.identity_signup_appeals enable row level security;
revoke all on table public.identity_signup_appeals from public, anon, authenticated;
grant select, insert, update, delete on table public.identity_signup_appeals to service_role;
do $$
begin
  if not exists (select 1 from pg_policy p where p.polrelid = 'public.identity_signup_appeals'::regclass and p.polname = 'ax_service_role_only') then
    create policy ax_service_role_only on public.identity_signup_appeals for all to service_role using (true) with check (true);
  end if;
end $$;

create or replace function public.identity_signup_appeal_open(p_contact text, p_statement text, p_email text, p_recovery text, p_device_key text, p_shape text, p_network text, p_key text)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare s jsonb := public.identity_signals_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_key); refs uuid[]; id uuid; ap boolean;
begin
  if char_length(btrim(coalesce(p_statement, ''))) < 20 then return jsonb_build_object('ok', false, 'error', 'statement_required'); end if;
  if public.identity_canon_email(p_contact) is null then return jsonb_build_object('ok', false, 'error', 'contact_required'); end if;
  if jsonb_array_length(s) = 0 then return jsonb_build_object('ok', false, 'error', 'nothing_to_appeal'); end if;
  select array_agg(distinct b.source_ref) filter (where b.source_ref is not null), bool_and(b.appealable) into refs, ap
    from public.identity_parse_signals(s) x
    join public.identity_bans b on b.kind = x.kind and b.hmac = x.hmac and b.lifted_at is null and (b.expires_at is null or b.expires_at > now())
   where public.identity_kind_strong(x.kind);
  if ap is null then return jsonb_build_object('ok', false, 'error', 'nothing_to_appeal'); end if;
  if not ap then return jsonb_build_object('ok', false, 'error', 'not_appealable'); end if;
  if (select count(*) from public.identity_signup_appeals a where a.contact = lower(btrim(p_contact)) and a.state = 'new') >= 1 then
    return jsonb_build_object('ok', false, 'error', 'appeal_already_open');
  end if;
  insert into public.identity_signup_appeals (contact, statement, source_refs)
  values (lower(btrim(p_contact)), btrim(p_statement), coalesce(refs, '{}')) returning identity_signup_appeals.id into id;
  return jsonb_build_object('ok', true, 'appeal_id', id);
end $$;

create or replace function public.identity_signup_appeal_decide(p_actor uuid, p_appeal uuid, p_decision text, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare a public.identity_signup_appeals; n integer := 0; rsn text := btrim(coalesce(p_reason, ''));
begin
  if not public.safety_can_review(p_actor) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if p_decision not in ('granted', 'denied') then return jsonb_build_object('ok', false, 'error', 'bad_decision'); end if;
  if char_length(rsn) < 12 then return jsonb_build_object('ok', false, 'error', 'reason_required'); end if;
  select * into a from public.identity_signup_appeals where id = p_appeal for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if a.state <> 'new' then return jsonb_build_object('ok', false, 'error', 'already_decided', 'state', a.state); end if;
  update public.identity_signup_appeals set state = p_decision, decided_by = p_actor, decided_at = now(), decision_reason = rsn where id = p_appeal;
  if p_decision = 'granted' then
    update public.identity_bans set lifted_at = now(), lifted_by = p_actor where source_ref = any (a.source_refs) and lifted_at is null and appealable;
    get diagnostics n = row_count;
    insert into public.identity_vault_audit (event, detail) values ('lift', jsonb_build_object('lifted', n, 'via', 'signup_appeal'));
  end if;
  return jsonb_build_object('ok', true, 'state', p_decision, 'lifted', n);
end $$;

-- ---- 4. founder ke liye ek nazar ka hisaab -------------------------------------------------------------------------------------------
create or replace function public.identity_admin_overview(p_actor uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
begin
  if not public.safety_can_review(p_actor) then return jsonb_build_object('allowed', false); end if;
  return jsonb_build_object(
    'allowed', true,
    'bans_active', (select count(*) from public.identity_bans where lifted_at is null and (expires_at is null or expires_at > now())),
    'bans_by_reason', coalesce((select jsonb_object_agg(reason, c) from (select reason, count(*) c from public.identity_bans where lifted_at is null and (expires_at is null or expires_at > now()) group by reason) x), '{}'::jsonb),
    'bans_permanent', (select count(*) from public.identity_bans where lifted_at is null and expires_at is null),
    'bans_expiring_30d', (select count(*) from public.identity_bans where lifted_at is null and expires_at between now() and now() + interval '30 days'),
    'signups_denied_30d', (select count(*) from public.identity_vault_audit where event = 'deny' and at > now() - interval '30 days' and detail ? 'matched'),
    'signups_review_30d', (select count(*) from public.identity_vault_audit where event = 'review' and at > now() - interval '30 days'),
    'signals_total', (select count(*) from public.identity_signals),
    'appeals', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'created_at', a.created_at, 'contact', a.contact, 'statement', a.statement) order by a.created_at)
                           from public.identity_signup_appeals a where a.state = 'new'), '[]'::jsonb),
    'appeals_open', (select count(*) from public.identity_signup_appeals where state = 'new'));
end $$;

-- ---- 5. purge: purani appeals (90 din baad faisla ho chuka) ---------------------------------------------------------------------------
create or replace function public.identity_signup_appeals_purge()
returns integer language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '15s' as $$
declare n integer;
begin
  delete from public.identity_signup_appeals where state <> 'new' and decided_at < now() - interval '90 days';
  get diagnostics n = row_count;
  return n;
end $$;

-- ---- 6. privileges (Rule 43) --------------------------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.identity_canon_email(text)', 'public.identity_hmac_hex(text,text,text)',
    'public.identity_signals_raw(text,text,text,text,text,text)', 'public.identity_signup_check_raw(text,text,text,text,text,text)',
    'public.identity_register_raw(uuid,text,text,text,text,text,text)', 'public.identity_register_payment(uuid,text,text)',
    'public.identity_reason_from_text(text)', 'public.identity_integrity_trg()', 'public.identity_appeal_trg()',
    'public.identity_signup_appeal_open(text,text,text,text,text,text,text,text)', 'public.identity_signup_appeal_decide(uuid,uuid,text,text)',
    'public.identity_admin_overview(uuid)', 'public.identity_signup_appeals_purge()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on table public.identity_signup_appeals is 'Logged-out appeal after a signup was refused by the identity vault (E68). Founder decides; contact is erased 90 days after the decision.';
comment on function public.identity_admin_overview(uuid) is 'Founder-only summary of identity bans, review flags and open signup appeals (E68). Never returns hashes.';

do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.identity_signup_appeals'::regclass) then
    raise exception 'E68 POST-CONDITION: identity_signup_appeals par RLS ON nahi' using errcode = 'AX068';
  end if;
  if has_function_privilege('authenticated', 'public.identity_admin_overview(uuid)', 'execute') then
    raise exception 'E68 POST-CONDITION: authenticated ko execute mil gaya' using errcode = 'AX068';
  end if;
end $$;
