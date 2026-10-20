-- E44 — ASLI data export ("export anytime" / blocked account ke 72 ghante) — Blueprint G36 — 20 Oct 2026
--
-- Sach jo audit mein mila: `integration_exports` sirf queue thi, koi worker nahi — export kabhi bana hi nahi.
-- Yeh file DB ka hissa deti hai (scope + pages + ek-bar ka download ticket). Zip banana + stream karna Rust ka kaam hai
-- (`server/rust/export_core.rs` + `export_glue.rs`, route `/file/account-export`).
--
--   account_export_ticket_issue(_user)      -> text (plain ticket, ek baar; DB mein sirf sha256)
--   account_export_ticket_use(_token)       -> jsonb {ok,user_id}  (single use, 10 minute)
--   account_export_scope(_user)             -> jsonb {email, orgs, owner_orgs, mailboxes}
--   account_export_page(_user,_kind,_after,_limit) -> jsonb {rows:[...], next}
--        kind: threads | messages | attachments | contacts | events | attendees
--        Rows `to_jsonb(row)` hain: schema badle to export nahi tootta, nayi column khud aa jati hai.
-- Scope (sirf us user ka): apna mailbox (mail_accounts.address = user ka email) ki threads/messages/attachments;
-- jin organisations ka woh OWNER hai unke contacts + calendar; baqi orgs mein sirf wohi events jo usne banaye.
-- Blocked account: ticket tabhi milta hai jab 72 ghante ki export window khuli ho (account_integrity.export_until).
-- Dobara chalana safe. Kuch delete/badalta nahi (sirf naye table/function).
set search_path = public, extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.account_export_tickets (
  token_hash text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at    timestamptz
);
alter table public.account_export_tickets enable row level security;
revoke all on public.account_export_tickets from public, anon, authenticated;
grant all on public.account_export_tickets to service_role;

create or replace function public._ae_has_col(_tbl text, _col text)
returns boolean language sql stable set search_path = public as $$
  select exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = _tbl and column_name = _col)
$$;

create or replace function public.account_export_scope(_user uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  em   text;
  orgs uuid[] := '{}';
  own  uuid[] := '{}';
  mbx  text[] := '{}';
begin
  select lower(u.email) into em from auth.users u where u.id = _user;
  if em is null then return jsonb_build_object('ok', false, 'error', 'user_not_found'); end if;

  if to_regclass('public.org_members') is not null then
    select coalesce(array_agg(distinct m.org_id), '{}') into orgs
      from public.org_members m
     where m.user_id = _user and coalesce(m.status::text, 'active') <> 'revoked';
    select coalesce(array_agg(distinct m.org_id), '{}') into own
      from public.org_members m
     where m.user_id = _user and m.role::text = 'owner' and coalesce(m.status::text, 'active') <> 'revoked';
  end if;

  mbx := array[em];
  if to_regclass('public.mail_accounts') is not null then
    select coalesce(array_agg(distinct lower(a.address)), '{}') || mbx into mbx
      from public.mail_accounts a where lower(a.address) = em;
  end if;
  select coalesce(array_agg(distinct x), '{}') into mbx from unnest(mbx) x;

  return jsonb_build_object('ok', true, 'email', em, 'orgs', to_jsonb(orgs),
                            'owner_orgs', to_jsonb(own), 'mailboxes', to_jsonb(mbx));
end $$;

create or replace function public.account_export_page(_user uuid, _kind text, _after text default null, _limit int default 500)
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  sc     jsonb := public.account_export_scope(_user);
  mbx    text[];
  own    uuid[];
  orgs   uuid[];
  lim    int := least(greatest(coalesce(_limit, 500), 1), 2000);
  sqlt   text;
  rows_j jsonb;
  nxt    text;
  after_ text := coalesce(_after, '');
  tid_col text;
begin
  if (sc->>'ok') is distinct from 'true' then return jsonb_build_object('rows', '[]'::jsonb, 'next', null); end if;
  select coalesce(array_agg(x), '{}') into mbx from jsonb_array_elements_text(sc->'mailboxes') x;
  select coalesce(array_agg(x::uuid), '{}') into own from jsonb_array_elements_text(sc->'owner_orgs') x;
  select coalesce(array_agg(x::uuid), '{}') into orgs from jsonb_array_elements_text(sc->'orgs') x;

  if _kind = 'threads' then
    if to_regclass('public.mail_threads') is null then return jsonb_build_object('rows','[]'::jsonb,'next',null); end if;
    sqlt := 'select t.id::text as k, to_jsonb(t) as j from public.mail_threads t where (lower(t.mailbox_address) = any($1)';
    if public._ae_has_col('mail_threads', 'account_id') and to_regclass('public.mail_accounts') is not null then
      sqlt := sqlt || ' or t.account_id in (select a.id from public.mail_accounts a where lower(a.address) = any($1))';
    end if;
    sqlt := sqlt || ') and t.id::text > $2 order by t.id::text limit $3';
    execute format('select coalesce(jsonb_agg(j order by k), ''[]''::jsonb), max(k) from (%s) q', sqlt)
      into rows_j, nxt using mbx, after_, lim;

  elsif _kind = 'messages' then
    if to_regclass('public.mail_messages') is null or to_regclass('public.mail_threads') is null then
      return jsonb_build_object('rows','[]'::jsonb,'next',null); end if;
    sqlt := 'select m.id::text as k, to_jsonb(m) as j from public.mail_messages m where m.thread_id in (select t.id from public.mail_threads t where (lower(t.mailbox_address) = any($1)';
    if public._ae_has_col('mail_threads', 'account_id') and to_regclass('public.mail_accounts') is not null then
      sqlt := sqlt || ' or t.account_id in (select a.id from public.mail_accounts a where lower(a.address) = any($1))';
    end if;
    sqlt := sqlt || ')) and m.id::text > $2 order by m.id::text limit $3';
    execute format('select coalesce(jsonb_agg(j order by k), ''[]''::jsonb), max(k) from (%s) q', sqlt)
      into rows_j, nxt using mbx, after_, lim;

  elsif _kind = 'attachments' then
    if to_regclass('public.mail_attachments') is null or to_regclass('public.mail_messages') is null or to_regclass('public.mail_threads') is null then
      return jsonb_build_object('rows','[]'::jsonb,'next',null); end if;
    sqlt := 'select a.id::text as k, to_jsonb(a) as j from public.mail_attachments a where a.message_id in (select m.id from public.mail_messages m where m.thread_id in (select t.id from public.mail_threads t where (lower(t.mailbox_address) = any($1)';
    if public._ae_has_col('mail_threads', 'account_id') and to_regclass('public.mail_accounts') is not null then
      sqlt := sqlt || ' or t.account_id in (select x.id from public.mail_accounts x where lower(x.address) = any($1))';
    end if;
    sqlt := sqlt || '))) and a.id::text > $2 order by a.id::text limit $3';
    execute format('select coalesce(jsonb_agg(j order by k), ''[]''::jsonb), max(k) from (%s) q', sqlt)
      into rows_j, nxt using mbx, after_, lim;

  elsif _kind = 'contacts' then
    if to_regclass('public.contacts') is null then return jsonb_build_object('rows','[]'::jsonb,'next',null); end if;
    execute 'select coalesce(jsonb_agg(j order by k), ''[]''::jsonb), max(k) from (select c.id::text as k, to_jsonb(c) as j from public.contacts c where c.org_id = any($1) and c.id::text > $2 order by c.id::text limit $3) q'
      into rows_j, nxt using own, after_, lim;

  elsif _kind = 'events' then
    if to_regclass('public.calendar_events') is null then return jsonb_build_object('rows','[]'::jsonb,'next',null); end if;
    execute 'select coalesce(jsonb_agg(j order by k), ''[]''::jsonb), max(k) from (select e.id::text as k, to_jsonb(e) as j from public.calendar_events e where (e.org_id = any($1) or (e.org_id = any($4) and e.created_by = $5)) and e.id::text > $2 order by e.id::text limit $3) q'
      into rows_j, nxt using own, after_, lim, orgs, _user;

  elsif _kind = 'attendees' then
    if to_regclass('public.calendar_attendees') is null or to_regclass('public.calendar_events') is null then
      return jsonb_build_object('rows','[]'::jsonb,'next',null); end if;
    execute 'select coalesce(jsonb_agg(j order by k), ''[]''::jsonb), max(k) from (select a.id::text as k, to_jsonb(a) as j from public.calendar_attendees a where a.event_id in (select e.id from public.calendar_events e where (e.org_id = any($1) or (e.org_id = any($4) and e.created_by = $5))) and a.id::text > $2 order by a.id::text limit $3) q'
      into rows_j, nxt using own, after_, lim, orgs, _user;

  else
    return jsonb_build_object('rows','[]'::jsonb,'next',null,'error','bad_kind');
  end if;

  -- next sirf tab jab poora page aaya (aur rows hain)
  if jsonb_array_length(rows_j) < lim then nxt := null; end if;
  return jsonb_build_object('rows', rows_j, 'next', nxt);
end $$;

-- ticket: ek baar, 10 minute. Blocked account ko sirf export window ke andar.
create or replace function public.account_export_ticket_issue(_user uuid)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare
  tok text;
  st  text := null;
  eu  timestamptz := null;
begin
  if not exists (select 1 from auth.users where id = _user) then
    return jsonb_build_object('ok', false, 'error', 'user_not_found');
  end if;
  if to_regclass('public.account_integrity') is not null then
    select i.state, i.export_until into st, eu from public.account_integrity i where i.user_id = _user;
    if st = 'purged' then return jsonb_build_object('ok', false, 'error', 'purged'); end if;
    if st = 'blocked' and eu is not null and eu < now() then
      return jsonb_build_object('ok', false, 'error', 'export_window_closed', 'export_until', eu);
    end if;
  end if;
  delete from public.account_export_tickets where expires_at < now() - interval '1 day';
  tok := encode(gen_random_bytes(24), 'hex');
  insert into public.account_export_tickets (token_hash, user_id, expires_at)
  values (encode(digest(tok, 'sha256'), 'hex'), _user, now() + interval '10 minutes');
  if to_regclass('public.account_integrity_log') is not null and st = 'blocked' then
    begin
      insert into public.account_integrity_log (user_id, event, actor, detail)
      values (_user, 'exported', 'user', jsonb_build_object('at', now(), 'via', 'account-export'));
    exception when others then null;
    end;
  end if;
  return jsonb_build_object('ok', true, 'ticket', tok, 'expires_in', 600);
end $$;

create or replace function public.account_export_ticket_use(_token text)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare r public.account_export_tickets;
begin
  update public.account_export_tickets
     set used_at = now()
   where token_hash = encode(digest(coalesce(_token, ''), 'sha256'), 'hex')
     and used_at is null and expires_at > now()
  returning * into r;
  if r.user_id is null then return jsonb_build_object('ok', false, 'error', 'invalid_or_used'); end if;
  return jsonb_build_object('ok', true, 'user_id', r.user_id);
end $$;

revoke all on function public.account_export_scope(uuid) from public, anon, authenticated;
revoke all on function public.account_export_page(uuid, text, text, int) from public, anon, authenticated;
revoke all on function public.account_export_ticket_issue(uuid) from public, anon, authenticated;
revoke all on function public.account_export_ticket_use(text) from public, anon, authenticated;
grant execute on function public.account_export_scope(uuid) to service_role;
grant execute on function public.account_export_page(uuid, text, text, int) to service_role;
grant execute on function public.account_export_ticket_issue(uuid) to service_role;
grant execute on function public.account_export_ticket_use(text) to service_role;
