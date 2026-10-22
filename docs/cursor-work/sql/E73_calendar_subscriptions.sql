-- E73 — Calendar subscriptions (ICS feed, SIRF PADHNE ke liye) — calendar #4c — 23 Oct 2026
--
-- Kya: user bahar ka calendar (Google "secret iCal address", Outlook published calendar, cricket/holiday feeds) link karta hai.
-- Rust server-side fetch karta hai (browser CORS ki wajah se nahi kar sakta), parse karta hai, yahan events rakhta hai; web unhein
-- apne calendar par halke rang mein dikhata hai. Yeh events kabhi mail/invite/booking mein nahi jate (sirf dikhane ke liye).
--
-- Advance / safety
--   * URL ek SECRET hai (secret iCal address kisi ko bhi calendar de deta hai) -> RLS ON, anon/authenticated ko koi haq nahi, list sirf HOST deti hai.
--   * Har user ke 10 subscriptions tak; same URL dobara nahi (user_id + sha256(url)).
--   * cal_sub_due ek LEASE leta hai (next_fetch_at ko 5 minute aage) — do request ek hi feed ek saath fetch nahi karti.
--   * cal_sub_apply poora event-set EK transaction mein badalta hai (aadhi file kabhi nahi dikhti); 2000 events / feed se zyada nahi.
--   * Lagataar fail: backoff Rust nikalta hai, 30 fail ke baad feed apne aap disable (last_error = disabled_too_many_failures).
--   * Account mitne par rows saaf (calendar_sub_purge_deleted) — FK auth.users par nahi (purge orphans bhi saaf kare).
-- PEHLE: kuch nahi (auth.users ki zaroorat nahi). Dobara chalana safe. Kuch delete nahi karta.
set search_path = public, extensions;

create table if not exists public.calendar_subscriptions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null,
  name            text not null default '' check (char_length(name) <= 80),
  url             text not null check (url like 'https://%' and char_length(url) <= 2048),
  url_hash        text not null check (char_length(url_hash) = 64),
  color           text not null default '#64748b' check (color ~ '^#[0-9a-fA-F]{6}$'),
  enabled         boolean not null default true,
  refresh_minutes integer not null default 60 check (refresh_minutes between 15 and 1440),
  etag            text check (char_length(etag) <= 512),
  last_modified   text check (char_length(last_modified) <= 128),
  last_fetch_at   timestamptz,
  last_ok_at      timestamptz,
  next_fetch_at   timestamptz not null default now(),
  last_error      text check (char_length(last_error) <= 120),
  fail_count      integer not null default 0 check (fail_count >= 0),
  event_count     integer not null default 0 check (event_count between 0 and 2000),
  stats           jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  unique (user_id, url_hash)
);
create index if not exists calendar_subscriptions_user_idx on public.calendar_subscriptions (user_id, created_at);
create index if not exists calendar_subscriptions_due_idx on public.calendar_subscriptions (user_id, next_fetch_at) where enabled;

create table if not exists public.calendar_subscription_events (
  sub_id      uuid not null references public.calendar_subscriptions(id) on delete cascade,
  uid         text not null check (char_length(uid) between 1 and 200),
  rid         bigint not null default 0,
  title       text not null default '' check (char_length(title) <= 200),
  location    text not null default '' check (char_length(location) <= 200),
  description text not null default '' check (char_length(description) <= 1500),
  start_ts    bigint not null,
  duration_s  bigint not null default 0 check (duration_s between 0 and 31622400),
  all_day     boolean not null default false,
  tzid        text not null default 'UTC' check (char_length(tzid) <= 64),
  rrule       text not null default '' check (char_length(rrule) <= 500),
  exdates     bigint[] not null default '{}',
  cancelled   boolean not null default false,
  primary key (sub_id, uid, rid)
);
create index if not exists calendar_subscription_events_range_idx on public.calendar_subscription_events (sub_id, start_ts);

do $$
declare t text;
begin
  foreach t in array array['calendar_subscriptions', 'calendar_subscription_events'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to service_role', t);
    if not exists (select 1 from pg_policy where polrelid = ('public.' || t)::regclass and polname = 'ax_service_role_only') then
      execute format('create policy ax_service_role_only on public.%I for all to service_role using (true) with check (true)', t);
    end if;
  end loop;
end $$;

-- host nikalna (URL kabhi bahar nahi jata)
create or replace function public._cal_sub_host(_url text) returns text
language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select split_part(split_part(split_part(substr(_url, 9), '/', 1), '?', 1), ':', 1)
$$;

-- ---- add ------------------------------------------------------------------------------------------------------------------
create or replace function public.cal_sub_add(_user uuid, _url text, _hash text, _name text, _color text, _refresh integer)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_id uuid; v_n integer; v_max constant integer := 10;
begin
  if _user is null or _url is null or _url not like 'https://%' or char_length(_url) > 2048 or _hash is null or char_length(_hash) <> 64 then
    return jsonb_build_object('ok', false, 'error', 'bad_input');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('cal_sub:' || _user::text, 0));
  select count(*) into v_n from public.calendar_subscriptions where user_id = _user;
  if v_n >= v_max then return jsonb_build_object('ok', false, 'error', 'limit_reached', 'limit', v_max); end if;
  if exists (select 1 from public.calendar_subscriptions where user_id = _user and url_hash = _hash) then
    return jsonb_build_object('ok', false, 'error', 'already_added');
  end if;
  insert into public.calendar_subscriptions (user_id, name, url, url_hash, color, refresh_minutes)
  values (_user, left(coalesce(btrim(_name), ''), 80), _url, _hash,
          case when _color ~ '^#[0-9a-fA-F]{6}$' then lower(_color) else '#64748b' end,
          greatest(15, least(1440, coalesce(_refresh, 60))))
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- ---- list (URL nahi, sirf host) ------------------------------------------------------------------------------------------------
create or replace function public.cal_sub_list(_user uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', id, 'name', name, 'host', public._cal_sub_host(url), 'color', color, 'enabled', enabled,
           'refresh_minutes', refresh_minutes, 'last_ok_at', last_ok_at, 'last_fetch_at', last_fetch_at, 'last_error', last_error,
           'fail_count', fail_count, 'event_count', event_count, 'stats', stats) order by created_at), '[]'::jsonb)
    from public.calendar_subscriptions where user_id = _user
$$;

-- ---- update ----------------------------------------------------------------------------------------------------------------------
create or replace function public.cal_sub_update(_user uuid, _id uuid, _name text, _color text, _enabled boolean, _refresh integer)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare n integer;
begin
  update public.calendar_subscriptions s set
      name = case when _name is null then s.name else left(btrim(_name), 80) end,
      color = case when _color ~ '^#[0-9a-fA-F]{6}$' then lower(_color) else s.color end,
      refresh_minutes = case when _refresh is null then s.refresh_minutes else greatest(15, least(1440, _refresh)) end,
      enabled = coalesce(_enabled, s.enabled),
      -- dobara chalu karne par fail ginti saaf aur foran refresh
      fail_count = case when _enabled is true and not s.enabled then 0 else s.fail_count end,
      last_error = case when _enabled is true and not s.enabled then null else s.last_error end,
      next_fetch_at = case when _enabled is true and not s.enabled then now() else s.next_fetch_at end
    where s.id = _id and s.user_id = _user;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', n = 1, 'error', case when n = 1 then null else 'not_found' end);
end $$;

create or replace function public.cal_sub_remove(_user uuid, _id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare n integer;
begin
  delete from public.calendar_subscriptions where id = _id and user_id = _user;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', n = 1, 'error', case when n = 1 then null else 'not_found' end);
end $$;

-- ---- due: fetch ke liye feeds, LEASE ke saath (concurrent request dobara fetch nahi karti) ---------------------------------------
create or replace function public.cal_sub_due(_user uuid, _id uuid default null, _limit integer default 3)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_rows jsonb;
begin
  with pick as (
    select s.id from public.calendar_subscriptions s
     where s.user_id = _user and (s.id = _id or (_id is null and s.enabled and s.next_fetch_at <= now()))
       and (_id is null or s.next_fetch_at <= now() or s.last_fetch_at is null or s.last_fetch_at < now() - interval '1 minute')
     order by s.next_fetch_at
     limit greatest(1, least(coalesce(_limit, 3), 5))
     for update skip locked
  ), lease as (
    update public.calendar_subscriptions s set next_fetch_at = now() + interval '5 minutes', last_fetch_at = now()
      from pick where s.id = pick.id
    returning s.id, s.url, s.etag, s.last_modified, s.fail_count, s.refresh_minutes
  )
  select coalesce(jsonb_agg(to_jsonb(lease)), '[]'::jsonb) into v_rows from lease;
  return v_rows;
end $$;

-- ---- apply: poora event-set EK transaction mein badalta hai ----------------------------------------------------------------------
create or replace function public.cal_sub_apply(_user uuid, _id uuid, _etag text, _lm text, _name text, _events jsonb, _stats jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n integer; v_refresh integer;
begin
  if jsonb_typeof(_events) <> 'array' or jsonb_array_length(_events) > 2000 then
    return jsonb_build_object('ok', false, 'error', 'too_many_events');
  end if;
  select refresh_minutes into v_refresh from public.calendar_subscriptions where id = _id and user_id = _user for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  delete from public.calendar_subscription_events where sub_id = _id;
  insert into public.calendar_subscription_events (sub_id, uid, rid, title, location, description, start_ts, duration_s, all_day, tzid, rrule, exdates, cancelled)
  select _id, e.uid, coalesce(e.rid, 0), coalesce(e.title, ''), coalesce(e.location, ''), coalesce(e.description, ''), e.start_ts, greatest(0, coalesce(e.duration_s, 0)),
         coalesce(e.all_day, false), coalesce(e.tzid, 'UTC'), coalesce(e.rrule, ''),
         coalesce((select array_agg(x::bigint) from jsonb_array_elements_text(coalesce(e.exdates, '[]'::jsonb)) x), '{}'), coalesce(e.cancelled, false)
    from jsonb_to_recordset(_events) as e(uid text, rid bigint, title text, location text, description text, start_ts bigint, duration_s bigint,
                                         all_day boolean, tzid text, rrule text, exdates jsonb, cancelled boolean)
  on conflict (sub_id, uid, rid) do nothing;
  select count(*) into v_n from public.calendar_subscription_events where sub_id = _id;
  update public.calendar_subscriptions set
      etag = left(_etag, 512), last_modified = left(_lm, 128), last_ok_at = now(), last_fetch_at = now(),
      next_fetch_at = now() + make_interval(mins => v_refresh), last_error = null, fail_count = 0, event_count = v_n,
      stats = coalesce(_stats, '{}'::jsonb),
      name = case when name = '' and coalesce(btrim(_name), '') <> '' then left(btrim(_name), 80) else name end
    where id = _id;
  return jsonb_build_object('ok', true, 'event_count', v_n);
end $$;

create or replace function public.cal_sub_notmodified(_user uuid, _id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare n integer;
begin
  update public.calendar_subscriptions set last_ok_at = now(), last_fetch_at = now(), last_error = null, fail_count = 0,
         next_fetch_at = now() + make_interval(mins => refresh_minutes)
   where id = _id and user_id = _user;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', n = 1);
end $$;

create or replace function public.cal_sub_fail(_user uuid, _id uuid, _error text, _backoff_min integer)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_fc integer; v_off boolean := false;
begin
  update public.calendar_subscriptions set fail_count = fail_count + 1, last_fetch_at = now(), last_error = left(_error, 120),
         next_fetch_at = now() + make_interval(mins => greatest(5, least(coalesce(_backoff_min, 60), 1440)))
   where id = _id and user_id = _user returning fail_count into v_fc;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_fc >= 30 then
    update public.calendar_subscriptions set enabled = false, last_error = 'disabled_too_many_failures' where id = _id;
    v_off := true;
  end if;
  return jsonb_build_object('ok', true, 'fail_count', v_fc, 'disabled', v_off);
end $$;

-- ---- events: range ke ekdum kaam ke rows (recurring + overrides hamesha, ek-baar wale sirf range mein) -------------------------------
create or replace function public.cal_sub_events(_user uuid, _from bigint, _to bigint)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'subs', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'color', s.color) order by s.created_at), '[]'::jsonb)
               from public.calendar_subscriptions s where s.user_id = _user and s.enabled),
    'events', (select coalesce(jsonb_agg(jsonb_build_object(
                 'sub_id', e.sub_id, 'uid', e.uid, 'rid', e.rid, 'title', e.title, 'location', e.location, 'description', e.description,
                 'start_ts', e.start_ts, 'duration_s', e.duration_s, 'all_day', e.all_day, 'tzid', e.tzid, 'rrule', e.rrule,
                 'exdates', to_jsonb(e.exdates), 'cancelled', e.cancelled)), '[]'::jsonb)
                 from public.calendar_subscription_events e join public.calendar_subscriptions s on s.id = e.sub_id
                where s.user_id = _user and s.enabled
                  and (e.rrule <> '' or e.rid <> 0 or (e.start_ts < _to and e.start_ts + e.duration_s >= _from - 86400)))
  )
$$;

-- ---- safai: mite hue account ki rows ----------------------------------------------------------------------------------------------
create or replace function public.calendar_sub_purge_deleted(_limit integer default 200)
returns integer language plpgsql security definer set search_path = pg_catalog, public as $$
declare n integer := 0;
begin
  if to_regclass('auth.users') is null then return 0; end if;
  with gone as (
    select s.id from public.calendar_subscriptions s
     where not exists (select 1 from auth.users u where u.id = s.user_id) limit greatest(1, least(coalesce(_limit, 200), 1000))
  ), del as (delete from public.calendar_subscriptions s using gone where s.id = gone.id returning 1)
  select count(*) into n from del;
  return n;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public._cal_sub_host(text)', 'public.cal_sub_add(uuid,text,text,text,text,integer)', 'public.cal_sub_list(uuid)',
    'public.cal_sub_update(uuid,uuid,text,text,boolean,integer)', 'public.cal_sub_remove(uuid,uuid)', 'public.cal_sub_due(uuid,uuid,integer)',
    'public.cal_sub_apply(uuid,uuid,text,text,text,jsonb,jsonb)', 'public.cal_sub_notmodified(uuid,uuid)', 'public.cal_sub_fail(uuid,uuid,text,integer)',
    'public.cal_sub_events(uuid,bigint,bigint)', 'public.calendar_sub_purge_deleted(integer)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

do $$ begin
  if not (select bool_and(relrowsecurity) from pg_class where oid in ('public.calendar_subscriptions'::regclass, 'public.calendar_subscription_events'::regclass)) then
    raise exception 'E73: RLS band hai';
  end if;
end $$;
