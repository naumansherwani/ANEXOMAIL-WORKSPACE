-- E37 — aane wali mail KABHI kisi aur customer ke inbox mein nahi — 20 Oct 2026 (founder "haan", 05:37/06:07 PKT)
--
-- Kyun (live login, Basic test account): basic.test ke inbox mein root@anexomail.com ke 54 "Cron <root@mail> … Syntax error" mails.
-- Jad: purani `mail_ingest` (phase58) jab pane wala (envelope_to) kisi account/mailbox ka na ho to "koi bhi org" pakad leti thi:
--   "same mailbox ka purana thread -> SABSE NAYA thread kisi bhi org ka -> orgs ki pehli row -> ek hard-coded org".
--   Matlab: root@, galat spelling wala pata, khali handle — jo bhi aaye, us customer ke inbox mein jata jis ka thread sabse naya ho.
--   Ye privacy ka sabse bada khatra hai (ek customer doosre ke naam ki mail padh sakta hai).
--
-- Kya karti hai (live body ko chhuye baghair — sirf aage ek darwaza):
--   1. live `mail_ingest(jsonb)` ka naam `mail_ingest_core(jsonb)` (body/grants jaise thay). Dobara chalane par ye qadam chhod deti hai.
--   2. naya `mail_ingest(jsonb)` (wohi naam/signature; Postfix pipe aur E35 ka test isi ko bulate hain):
--        a) system pate @anexomail.com (root, admin, administrator, hostmaster, webmaster, security, mailer-daemon, cron) ->
--           envelope_to = resolved@anexomail.com (support/ops inbox — server ke cron alerts founder ko dikhenge, customer ko kabhi nahi).
--           postmaster/abuse/dmarc pehle se mailboxes mein alias -> resolved@ hain (phase56) — unhein nahi chheda.
--        b) pata kisi `mail_accounts.address` ya `mailboxes.address` ka hai -> core (purana raasta, bilkul wahi).
--        c) warna -> `mail_quarantine` (org nahi, kisi customer ko nahi dikhta) + {ok:true, quarantined:true}: Postfix dobara nahi bhejta.
--   3. purane system-pate wale threads/messages (root@ wagaira) jo kisi customer org mein pade hain -> resolved@ wali org mein
--      (mailbox_address bhi resolved@). Agar resolved@ ki org na mile to sirf 'trash' folder. Delete kuch nahi hota.
--   4. self-test (sab rollback): system pata -> resolved@, anjaan pata -> quarantine (koi thread nahi bana), jaana pata -> core.
-- Grants: naya mail_ingest sirf service_role (+ owner); mail_ingest_core public/anon/authenticated se wapas (bypass band).
-- Chalane ka tareeqa: Supabase SQL Editor mein poori file paste -> Run (psql ka koi \-command nahi), ya server se:
--   . /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E37_mail_ingest_no_stray_org.sql
-- Fail ho to poora rollback (ek hi transaction). SQL fail rule: isi file ko theek kiya jayega.
set search_path = public, extensions;
begin;
select pg_advisory_xact_lock(hashtext('E37_mail_ingest_no_stray_org'));

-- 0) zaroori cheezein maujood hain?
do $$
begin
  if to_regprocedure('public.mail_ingest(jsonb)') is null then
    raise exception 'E37: public.mail_ingest(jsonb) nahi mili — pehle phase58 chahiye';
  end if;
  if to_regclass('public.mailboxes') is null then
    raise exception 'E37: public.mailboxes nahi';
  end if;
end $$;

-- 1) quarantine table: anjaan pane wali mail yahan, kisi org mein nahi (RLS on, koi policy nahi => sirf service role / owner)
create table if not exists public.mail_quarantine (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  reason        text not null,
  envelope_from text,
  envelope_to   text not null,
  from_address  text,
  subject       text,
  message_id    text,
  raw_size      integer,
  raw_sha256    text,
  payload       jsonb not null
);
create index if not exists mail_quarantine_created_idx on public.mail_quarantine (created_at desc);
create index if not exists mail_quarantine_to_idx on public.mail_quarantine (lower(envelope_to));
alter table public.mail_quarantine enable row level security;
revoke all on public.mail_quarantine from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then execute 'revoke all on public.mail_quarantine from anon'; end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then execute 'revoke all on public.mail_quarantine from authenticated'; end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then execute 'grant select, insert, delete on public.mail_quarantine to service_role'; end if;
end $$;
comment on table public.mail_quarantine is
  'E37: inbound mail whose recipient belongs to no account/mailbox. Never shown to any customer org. Founder/ops only.';

-- 2) live mail_ingest -> mail_ingest_core (sirf pehli dafa)
do $$
begin
  if to_regprocedure('public.mail_ingest_core(jsonb)') is null then
    alter function public.mail_ingest(jsonb) rename to mail_ingest_core;
  elsif exists (
    select 1 from pg_proc p where p.oid = 'public.mail_ingest(jsonb)'::regprocedure
       and pg_get_functiondef(p.oid) not like '%E37 gate%') then
    -- core pehle se hai AUR mail_ingest bhi E37 wali nahi => kisi ne beech mein naya mail_ingest bana diya. Andaza nahi lagate.
    raise exception 'E37: mail_ingest_core pehle se hai aur mail_ingest E37 wala nahi — haath se dekhna padega (kuch nahi badla)';
  end if;
end $$;
revoke all on function public.mail_ingest_core(jsonb) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then execute 'revoke all on function public.mail_ingest_core(jsonb) from anon'; end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then execute 'revoke all on function public.mail_ingest_core(jsonb) from authenticated'; end if;
end $$;

-- 3) pata kis ka hai? (sirf wohi do jagah jo core bhi pehle dekhta hai: mail_accounts.address, mailboxes.address)
create or replace function public.mail_recipient_known(p_addr text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  a   text := lower(btrim(coalesce(p_addr, '')));
  hit boolean := false;
begin
  if a = '' then return false; end if;
  if to_regclass('public.mail_accounts') is not null
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'mail_accounts' and column_name = 'address') then
    execute 'select exists (select 1 from public.mail_accounts where lower(address) = $1)' into hit using a;
    if hit then return true; end if;
  end if;
  return exists (select 1 from public.mailboxes where lower(address) = a);
end $$;
revoke all on function public.mail_recipient_known(text) from public;

-- system pate (anexomail.com par; customer kabhi in handles ka malik nahi — reserved_handles 'system')
create or replace function public.mail_system_local_part(p_addr text)
returns boolean
language sql
immutable
as $$
  select lower(btrim(coalesce(p_addr, ''))) ~ '^(root|admin|administrator|hostmaster|webmaster|security|mailer-daemon|cron|daemon|nobody|www-data|vmail)@(mail\.)?anexomail\.com$'
$$;

-- 4) naya darwaza: wohi naam aur signature
create or replace function public.mail_ingest(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
-- E37 gate: koi bhi mail kisi aur customer ki org mein nahi. Andar wahi purana raasta (mail_ingest_core) chalta hai.
declare
  v_to      text := lower(btrim(coalesce(payload->>'envelope_to', '')));
  v_ops     text := 'resolved@anexomail.com';
  v_payload jsonb := payload;
begin
  if v_to = '' then
    raise exception 'mail_ingest_missing_envelope_to';
  end if;

  -- a) system pata -> ops inbox (agar woh maujood ho)
  if public.mail_system_local_part(v_to) and public.mail_recipient_known(v_ops) then
    v_payload := jsonb_set(v_payload, '{envelope_to}', to_jsonb(v_ops))
                 || jsonb_build_object('original_envelope_to', v_to);
    return public.mail_ingest_core(v_payload) || jsonb_build_object('rerouted_from', v_to);
  end if;

  -- b) jaana pehchana pata -> purana raasta
  if public.mail_recipient_known(v_to) then
    return public.mail_ingest_core(v_payload);
  end if;

  -- c) anjaan pata -> quarantine. Kisi org ko nahi. Postfix ko "ok" taake woh baar baar na bheje.
  insert into public.mail_quarantine
    (reason, envelope_from, envelope_to, from_address, subject, message_id, raw_size, raw_sha256, payload)
  values
    (case when public.mail_system_local_part(v_to) then 'system_address_no_ops_inbox' else 'unknown_recipient' end,
     payload->>'envelope_from', v_to, payload->>'from_address', left(payload->>'subject', 500), payload->>'message_id',
     nullif(payload->>'raw_size', '')::integer, payload->>'raw_sha256', payload);
  return jsonb_build_object('ok', true, 'quarantined', true, 'reason', 'unknown_recipient');
end $$;
revoke all on function public.mail_ingest(jsonb) from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then execute 'revoke all on function public.mail_ingest(jsonb) from anon'; end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then execute 'revoke all on function public.mail_ingest(jsonb) from authenticated'; end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then execute 'grant execute on function public.mail_ingest(jsonb) to service_role'; end if;
end $$;

-- 5) self-test (savepoint; sab wapas) — fail => poori file rollback
do $$
declare
  v_known text;
  r       jsonb;
  n0      bigint;
  n1      bigint;
  q0      bigint;
  q1      bigint;
  tag     text := 'e37-selftest-' || md5(clock_timestamp()::text);
begin
  begin
    -- anjaan pata: quarantine, koi thread/message nahi
    select count(*) into n0 from public.mail_messages;
    select count(*) into q0 from public.mail_quarantine;
    r := public.mail_ingest(jsonb_build_object('envelope_from', 'x@example.com', 'envelope_to', 'zz-' || tag || '@anexomail.com',
           'message_id', tag || '-u', 'from_address', 'x@example.com', 'subject', 'E37 test', 'body_text', 't', 'to', jsonb_build_array('zz@anexomail.com')));
    select count(*) into n1 from public.mail_messages;
    select count(*) into q1 from public.mail_quarantine;
    if coalesce((r->>'quarantined')::boolean, false) is not true or n1 <> n0 or q1 <> q0 + 1 then
      raise exception 'E37 SELFTEST FAIL: anjaan pata quarantine nahi hua (r=%, messages % -> %, quarantine % -> %)', r, n0, n1, q0, q1;
    end if;

    -- system pata: resolved@ par (agar resolved@ maujood) warna quarantine — kisi customer org mein KABHI nahi
    r := public.mail_ingest(jsonb_build_object('envelope_from', 'root@mail.anexomail.com', 'envelope_to', 'root@anexomail.com',
           'message_id', tag || '-r', 'from_address', 'root@anexomail.com', 'subject', 'Cron test', 'body_text', 't', 'to', jsonb_build_array('root@anexomail.com')));
    if public.mail_recipient_known('resolved@anexomail.com') then
      if not exists (select 1 from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
                      where m.message_id = tag || '-r' and lower(t.mailbox_address) = 'resolved@anexomail.com') then
        raise exception 'E37 SELFTEST FAIL: root@ resolved@ par nahi gaya (r=%)', r;
      end if;
    elsif coalesce((r->>'quarantined')::boolean, false) is not true then
      raise exception 'E37 SELFTEST FAIL: resolved@ nahi aur root@ quarantine bhi nahi (r=%)', r;
    end if;

    -- jaana pata: core ka purana raasta (thread usi mailbox par)
    select lower(address) into v_known from public.mailboxes
     where coalesce(box_type::text, 'mailbox') = 'mailbox' and org_id is not null and lower(address) like '%@%' limit 1;
    if v_known is not null then
      r := public.mail_ingest(jsonb_build_object('envelope_from', 'x@example.com', 'envelope_to', v_known,
             'message_id', tag || '-k', 'from_address', 'x@example.com', 'subject', 'E37 known', 'body_text', 't', 'to', jsonb_build_array(v_known)));
      if coalesce((r->>'quarantined')::boolean, false) or not exists (
           select 1 from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
            where m.message_id = tag || '-k' and lower(t.mailbox_address) = v_known
              and t.org_id = (select org_id from public.mailboxes where lower(address) = v_known limit 1)) then
        raise exception 'E37 SELFTEST FAIL: jaana pata (%) apni hi org mein nahi pahuncha (r=%)', v_known, r;
      end if;
    end if;
    raise exception 'E37_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'E37_SELFTEST_OK' then raise; end if;
  end;
end $$;

-- 6) purani bikhri hui system mail (root@ wagaira) jo kisi customer org mein padi hai -> ops (resolved@) ki org, warna trash
create temp table e37_moved (what text, n bigint) on commit drop;
do $$
declare
  v_ops_org uuid;
  v_ops_acc uuid;
  v_threads uuid[];
  n_t bigint := 0;
  n_m bigint := 0;
begin
  select org_id, account_id into v_ops_org, v_ops_acc from public.mailboxes where lower(address) = 'resolved@anexomail.com' limit 1;
  select coalesce(array_agg(id), '{}') into v_threads from public.mail_threads
   where public.mail_system_local_part(mailbox_address)
     and (v_ops_org is null or org_id is distinct from v_ops_org);
  if cardinality(v_threads) = 0 then
    insert into e37_moved values ('bikhri system threads', 0);
    return;
  end if;
  if v_ops_org is not null then
    update public.mail_messages set org_id = v_ops_org where thread_id = any(v_threads);
    get diagnostics n_m = row_count;
    update public.mail_threads
       set org_id = v_ops_org,
           account_id = v_ops_acc,
           mailbox_address = 'resolved@anexomail.com'
     where id = any(v_threads);
    get diagnostics n_t = row_count;
    insert into e37_moved values ('system threads -> resolved@ (ops)', n_t), ('un ke messages', n_m);
  else
    update public.mail_threads set folder = 'trash' where id = any(v_threads);
    get diagnostics n_t = row_count;
    insert into e37_moved values ('system threads -> trash (resolved@ ki org nahi mili)', n_t);
  end if;
end $$;

-- 7) natija
select 'mail_ingest' as cheez, case when pg_get_functiondef('public.mail_ingest(jsonb)'::regprocedure) like '%E37 gate%' then 'E37 darwaza laga' else 'GALAT' end as haal
union all select 'mail_ingest_core', case when to_regprocedure('public.mail_ingest_core(jsonb)') is not null then 'purana raasta andar maujood' else 'GALAT' end
union all select 'resolved@ (ops inbox)', case when public.mail_recipient_known('resolved@anexomail.com') then 'maujood — system mail yahan' else 'NAHI — system mail quarantine mein' end
union all select 'self-test', 'PASSED (sab rollback)'
union all select what, n::text from e37_moved
union all select 'quarantine (abhi)', count(*)::text from public.mail_quarantine
union all select 'purane threads jin ka pata ab kisi ka nahi (sirf ginti; hata hua address bhi ho sakta hai — chhede nahi)',
  count(*)::text from public.mail_threads t
   where t.mailbox_address is not null and not public.mail_system_local_part(t.mailbox_address)
     and not public.mail_recipient_known(t.mailbox_address);

commit;
