-- =============================================================================
-- E30 — Dashboard ka sach (15 Oct 2026)
-- Ek jagah (Postgres) se dashboard ke numbers; Rust :3200 PRIMARY aur Bun
-- fallback dono yahi functions call karte hain (do alag hisaab nahi).
--
-- Pehle ke jhoote numbers aur unki wajah (live pro.buyer par dekha):
--   * Unread/Assigned/Waiting/Closed: is_unread, assignee_id, state, closed_at
--     columns mail_threads mein hain hi nahi -> har count 0.
--   * Received 0 / Sent 2: direction 'in'/'out' hai ('inbound' nahi).
--   * Delivered 100%: hard-coded tha.
--   * Storage 0 GB / 30 GB: organisations.storage_limit_bytes (flat 30 GB), aur
--     mail_messages.size_bytes hai hi nahi. Plan table se aana chahiye.
--   * "ANEXOMAIL hosted": org select organisations.domain_verified par fail
--     hota tha (column nahi) -> org null -> hosted dikha.
--
-- Plan -> storage: public.storage_plans (phase48). Basic/Pro ke liye
-- storage ledger (mailbox_storage) banti hi nahi (chat_ensure_workspace
-- chat_not_entitled deta hai), isliye "used" message content se nikalta hai.
--
-- Sirf service_role (Rust/Bun) call karta hai. Idempotent: dobara chalane se
-- kuch nahi bigadta.
-- =============================================================================

set search_path = public, extensions;

do $$
begin
  if not exists (select 1 from pg_proc where proname = 'resolve_plan' and pronamespace = 'public'::regnamespace) then
    raise exception 'E30: public.resolve_plan nahi mila - pehle plan resolver check karo';
  end if;
  if to_regclass('public.storage_plans') is null then
    raise exception 'E30: public.storage_plans nahi mila (phase48)';
  end if;
end $$;

create index if not exists mail_messages_org_created_idx
  on public.mail_messages (org_id, created_at desc);
create index if not exists mail_threads_org_folder_idx
  on public.mail_threads (org_id, folder);

-- -----------------------------------------------------------------------------
-- dashboard_summary: KPI tiles + storage + domain
-- -----------------------------------------------------------------------------
create or replace function public.dashboard_summary(_org uuid, _user uuid, _email text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  _plan      text;
  _splan     text;
  _sp        record;
  _unread    bigint := 0;
  _waiting   bigint := 0;
  _assigned  bigint := 0;
  _sent_today bigint := 0;
  _today     timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  _msg_bytes bigint := 0;
  _att_bytes bigint := 0;
  _limit     bigint;
  _model     text;
  _org_domain text;
  _dr_domain text;
  _dr_status text;
  _custom    boolean := false;
  _dom_name  text;
  _dom_status text := 'none';
begin
  if _org is null then
    raise exception 'org_required';
  end if;

  -- Plan resolver Rust jaisa hi (named args _user_id/_email); literal se call taake arg types par na atke.
  execute format('select public.resolve_plan(_user_id => %L, _email => %L)', _user, _email) into _plan;
  _plan := coalesce(nullif(_plan, ''), 'basic');

  -- ---- KPI: folder badges ke wahi numbers (mail.counts se mel khate hain) ----
  select count(*) filter (where folder = 'inbox' and unread is true),
         count(*) filter (where folder = 'waiting'),
         count(*) filter (
           where assignee is not null
             and coalesce(folder, 'inbox') not in ('trash', 'spam', 'archive')
             and (assignee = _user::text or lower(assignee) = lower(coalesce(_email, '')))
         )
    into _unread, _waiting, _assigned
    from public.mail_threads
   where org_id = _org;

  select count(*) into _sent_today
    from public.mail_messages
   where org_id = _org and direction = 'out' and created_at >= _today;

  -- ---- storage: plan table se limit, message content se used ----
  _splan := case when _plan like 'ai\_%' then 'business_pro' else _plan end;
  select * into _sp from public.storage_plans where plan_id = _splan;
  if _sp.plan_id is null then
    select * into _sp from public.storage_plans where plan_id = 'trial';
  end if;

  select coalesce(sum(
           octet_length(coalesce(subject, '')) +
           octet_length(coalesce(body_text, '')) +
           octet_length(coalesce(body_html, ''))
         ), 0)
    into _msg_bytes
    from public.mail_messages
   where org_id = _org;

  begin
    select coalesce(sum(a.size_bytes), 0)
      into _att_bytes
      from public.mail_attachments a
      join public.mail_messages m on m.id = a.message_id
     where m.org_id = _org;
  exception when others then
    _att_bytes := 0;
  end;

  if _sp.pooled_bytes is not null then
    _model := 'pooled';
    _limit := _sp.pooled_bytes;
  else
    _model := 'per_mailbox';
    _limit := coalesce(_sp.per_mailbox_bytes, 0) * coalesce(_sp.mailbox_limit, 1);
  end if;

  -- ---- domain: org_domains (E15) + organisations.domain ----
  select domain into _org_domain from public.organisations where id = _org;
  if to_regclass('public.org_domains') is not null then
    select domain, status
      into _dr_domain, _dr_status
      from public.org_domains
     where org_id = _org and status <> 'removed'
     order by (status = 'verified') desc, created_at
     limit 1;
  end if;

  if _dr_domain is not null then
    _custom := true;
    _dom_name := _dr_domain;
    _dom_status := case when _dr_status = 'verified' then 'verified' else 'pending' end;
  elsif _org_domain is not null and lower(_org_domain) <> 'anexomail.com'
        and lower(_org_domain) not like '%.anexomail.com' then
    _custom := true;
    _dom_name := _org_domain;
    _dom_status := 'pending';
  end if;

  return jsonb_build_object(
    'plan', _plan,
    'unread', _unread,
    'assigned_to_me', _assigned,
    'waiting', _waiting,
    'sent_today', _sent_today,
    'done_today', _sent_today,            -- purana naam, wahi qeemat (purane client ke liye)
    'storage_used_bytes', _msg_bytes + _att_bytes,
    'storage_limit_bytes', _limit,
    'storage_model', _model,
    'storage_per_mailbox_bytes', _sp.per_mailbox_bytes,
    'storage_mailbox_limit', _sp.mailbox_limit,
    'domain', _dom_name,
    'domain_status', _dom_status,
    'domain_verified', (_dom_status = 'verified'),
    'domain_hosted', (not _custom)
  );
end
$$;

-- -----------------------------------------------------------------------------
-- dashboard_analytics: received/sent series, delivery, first-reply
-- -----------------------------------------------------------------------------
create or replace function public.dashboard_analytics(_org uuid, _days integer default 14)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  _d        integer := least(greatest(coalesce(_days, 14), 1), 90);
  _today    timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  _from     timestamptz;
  _series   jsonb;
  _recv     bigint := 0;
  _sent     bigint := 0;
  _ok       bigint := 0;
  _fail     bigint := 0;
  _reply    numeric;
begin
  if _org is null then
    raise exception 'org_required';
  end if;
  _from := _today - make_interval(days => _d - 1);

  with days as (
    select ((_from at time zone 'utc')::date + g) as d
      from generate_series(0, _d - 1) g
  ), m as (
    select (created_at at time zone 'utc')::date as d,
           count(*) filter (where direction = 'in')  as r,
           count(*) filter (where direction = 'out') as s
      from public.mail_messages
     where org_id = _org and created_at >= _from
     group by 1
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'date', to_char(days.d, 'YYYY-MM-DD'),
           'received', coalesce(m.r, 0),
           'sent', coalesce(m.s, 0)
         ) order by days.d), '[]'::jsonb),
         coalesce(sum(m.r), 0),
         coalesce(sum(m.s), 0)
    into _series, _recv, _sent
    from days left join m using (d);

  -- Delivered: sirf asli send-queue ke natije (mail_scheduled sent / failed).
  -- Koi row nahi -> NULL (UI "—" dikhata hai, jhoota 100% nahi).
  if to_regclass('public.mail_scheduled') is not null then
    select count(*) filter (where status = 'sent'),
           count(*) filter (where status = 'failed')
      into _ok, _fail
      from public.mail_scheduled
     where org_id = _org and send_at >= _from;
  end if;

  -- Pehla jawab: thread ki pehli aane wali mail -> uske baad pehli bheji hui mail.
  select avg(extract(epoch from (o.t - i.t)))
    into _reply
    from (
      select thread_id, min(created_at) as t
        from public.mail_messages
       where org_id = _org and direction = 'in' and created_at >= _from
       group by thread_id
    ) i
    join lateral (
      select min(m2.created_at) as t
        from public.mail_messages m2
       where m2.thread_id = i.thread_id
         and m2.direction = 'out'
         and m2.created_at > i.t
    ) o on o.t is not null;

  return jsonb_build_object(
    'range_days', _d,
    'received', _recv,
    'sent', _sent,
    'avg_first_reply_seconds', case when _reply is null then null else round(_reply)::bigint end,
    'delivery_rate', case when (_ok + _fail) = 0 then null else round(_ok::numeric / (_ok + _fail), 4) end,
    'series', _series
  );
end
$$;

revoke execute on function public.dashboard_summary(uuid, uuid, text) from public, anon, authenticated;
grant  execute on function public.dashboard_summary(uuid, uuid, text) to service_role;
revoke execute on function public.dashboard_analytics(uuid, integer) from public, anon, authenticated;
grant  execute on function public.dashboard_analytics(uuid, integer) to service_role;

notify pgrst, 'reload schema';
