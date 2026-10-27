
-- =============================================================================
-- E97 — COMMITMENT LEDGER + THREAD ECONOMICS (compose "Business Outcomes", 27 Oct 2026)
-- Founder idea: email likhte waqt WASM kernel (intent@1) wada + deadline pakadta hai; send par wada ek HMAC-SEALED ledger mein
-- jaata hai aur ATOMICALLY ek task (+ optional calendar hold) banta hai. Saath mein "yeh email kitna waqt/paisa khayegi" ka hisaab.
--
-- Banata hai:
--   commitment_keys        org ki HMAC-SHA256 key (sirf service_role; app kabhi nahi dekhta)
--   commitment_ledger      APPEND-ONLY, hash-chained, HMAC-SHA256 seal (tamper-evident: kisi row ko badlo to chain toot jaati hai)
--   commitment_*()         seal, append, record (atomic task+event), set_status, verify (poori chain dobara hisaab)
--   org_attention_rates    org ka hourly rate/currency/wpm (default £60/ghanta = 6000 pence)
--   attention_cost()       WASM intent_cost() se BIT-BA-BIT same integer formula (parity self-test is file ke aakhir mein)
--   thread_economics_log   send par: words, recipients, cost, call-suggestion, kya user ne maana
--   views                  open / due soon / kept-rate / monthly economics
-- Mojooda work_promises + work_tasks + calendar_events REUSE hote hain (naye duplicate table nahi).
-- Rule 38/42/43/44: pehli line khali, psql meta nahi, search_path pinned, RLS on, anon/authenticated revoke, idempotent.
-- Polar :3400 NO-TOUCH. Dobara chalana safe.
-- =============================================================================
set lock_timeout = '5s';
set statement_timeout = '120s';

do $$ begin
  if to_regclass('public.work_tasks') is null then raise exception 'E97 PREFLIGHT: work_tasks nahi (phase61)'; end if;
  if to_regclass('public.work_promises') is null then raise exception 'E97 PREFLIGHT: work_promises nahi (phase61)'; end if;
  if to_regclass('public.calendar_events') is null then raise exception 'E97 PREFLIGHT: calendar_events nahi (phase61)'; end if;
  if not exists (select 1 from pg_extension where extname = 'pgcrypto') then
    create extension if not exists pgcrypto with schema extensions;
  end if;
  if to_regprocedure('extensions.hmac(bytea,bytea,text)') is null then raise exception 'E97 PREFLIGHT: pgcrypto hmac() nahi'; end if;
end $$;

set search_path = public, extensions;

-- -----------------------------------------------------------------------------
-- 1) work_promises ko ledger ke liye taiyar karna (sirf columns ADD, kuch drop nahi)
-- -----------------------------------------------------------------------------
alter table public.work_promises add column if not exists ledger_id    uuid;
alter table public.work_promises add column if not exists promised_to  text[] not null default '{}'::text[];
alter table public.work_promises add column if not exists due_exact    boolean not null default false;
alter table public.work_promises add column if not exists lang         text not null default 'en';
alter table public.work_promises add column if not exists dedupe_key   text;
alter table public.work_promises add column if not exists event_id     uuid;
alter table public.work_promises add column if not exists settled_at   timestamptz;
alter table public.work_promises add column if not exists source       text not null default 'compose';

create unique index if not exists work_promises_dedupe_uq
  on public.work_promises (org_id, dedupe_key) where dedupe_key is not null;
create index if not exists work_promises_org_status_idx
  on public.work_promises (org_id, status, suggested_due_at);

alter table public.work_tasks add column if not exists promise_id uuid;
create index if not exists work_tasks_promise_idx on public.work_tasks (promise_id) where promise_id is not null;

-- -----------------------------------------------------------------------------
-- 2) HMAC key store (har org ki apni 32-byte random key)
-- -----------------------------------------------------------------------------
create table if not exists public.commitment_keys (
  org_id     uuid primary key,
  key        bytea not null check (octet_length(key) = 32),
  created_at timestamptz not null default now(),
  rotated_at timestamptz
);
alter table public.commitment_keys enable row level security;
revoke all on public.commitment_keys from public, anon, authenticated;
grant select, insert, update on public.commitment_keys to service_role;

create or replace function public.commitment_key(p_org uuid) returns bytea
language plpgsql security definer set search_path = public, extensions as $$
declare v bytea;
begin
  if p_org is null then raise exception 'commitment_key: org_id required'; end if;
  select key into v from public.commitment_keys where org_id = p_org;
  if v is null then
    insert into public.commitment_keys (org_id, key) values (p_org, extensions.gen_random_bytes(32))
      on conflict (org_id) do nothing;
    select key into v from public.commitment_keys where org_id = p_org;
  end if;
  return v;
end $$;
revoke all on function public.commitment_key(uuid) from public, anon, authenticated;
grant execute on function public.commitment_key(uuid) to service_role;

-- -----------------------------------------------------------------------------
-- 3) Ledger: append-only + hash-chain + HMAC-SHA256 seal
-- -----------------------------------------------------------------------------
create table if not exists public.commitment_ledger (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null,
  seq         bigint not null,
  action      text not null check (action in ('recorded','linked','fulfilled','broken','snoozed','cancelled')),
  promise_id  uuid,
  task_id     uuid,
  event_id    uuid,
  thread_id   uuid,
  actor       uuid,
  payload     jsonb not null default '{}'::jsonb,
  prev_seal   text not null default '',
  seal        text not null,
  created_at  timestamptz not null default now(),
  unique (org_id, seq)
);
create index if not exists commitment_ledger_promise_idx on public.commitment_ledger (promise_id, seq);
create index if not exists commitment_ledger_thread_idx  on public.commitment_ledger (org_id, thread_id) where thread_id is not null;

alter table public.commitment_ledger enable row level security;
revoke all on public.commitment_ledger from public, anon, authenticated;
grant select, insert on public.commitment_ledger to service_role;

-- Append-only: update/delete par seedha error (service_role bhi nahi badal sakta; sirf superuser trigger hata ke)
create or replace function public.commitment_ledger_immutable() returns trigger
language plpgsql set search_path = public as $$
begin
  raise exception 'commitment_ledger append-only hai (% blocked)', tg_op using errcode = '42501';
end $$;

drop trigger if exists commitment_ledger_no_change on public.commitment_ledger;
create trigger commitment_ledger_no_change before update or delete on public.commitment_ledger
  for each row execute function public.commitment_ledger_immutable();

drop trigger if exists commitment_ledger_no_truncate on public.commitment_ledger;
create trigger commitment_ledger_no_truncate before truncate on public.commitment_ledger
  for each statement execute function public.commitment_ledger_immutable();

-- Seal = HMAC-SHA256(org_key, "<org>|<seq>|<action>|<promise>|<prev_seal>|<sha256(payload::text)>")  -> hex
create or replace function public.commitment_seal(
  p_org uuid, p_seq bigint, p_action text, p_promise uuid, p_prev text, p_payload jsonb
) returns text language sql stable security definer set search_path = public, extensions as $$
  select encode(
    extensions.hmac(
      convert_to(
        p_org::text || '|' || p_seq::text || '|' || p_action || '|' || coalesce(p_promise::text, '') || '|' ||
        coalesce(p_prev, '') || '|' || encode(extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256'), 'hex'),
        'UTF8'),
      public.commitment_key(p_org),
      'sha256'),
    'hex')
$$;
revoke all on function public.commitment_seal(uuid, bigint, text, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.commitment_seal(uuid, bigint, text, uuid, text, jsonb) to service_role;

-- Append: org ke liye serialize (advisory lock) taake seq/prev_seal kabhi na toote
create or replace function public.commitment_append(
  p_org uuid, p_action text, p_promise uuid, p_task uuid, p_event uuid, p_thread uuid, p_actor uuid, p_payload jsonb
) returns public.commitment_ledger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prev   text := '';
  v_seq    bigint;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_row    public.commitment_ledger;
begin
  if p_org is null then raise exception 'commitment_append: org_id required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('commitment_ledger:' || p_org::text, 0));
  select seq, seal into v_seq, v_prev
    from public.commitment_ledger where org_id = p_org order by seq desc limit 1;
  v_seq := coalesce(v_seq, 0) + 1;
  v_prev := coalesce(v_prev, '');
  insert into public.commitment_ledger
    (org_id, seq, action, promise_id, task_id, event_id, thread_id, actor, payload, prev_seal, seal)
  values
    (p_org, v_seq, p_action, p_promise, p_task, p_event, p_thread, p_actor, v_payload, v_prev,
     public.commitment_seal(p_org, v_seq, p_action, p_promise, v_prev, v_payload))
  returning * into v_row;
  return v_row;
end $$;
revoke all on function public.commitment_append(uuid, text, uuid, uuid, uuid, uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.commitment_append(uuid, text, uuid, uuid, uuid, uuid, uuid, jsonb) to service_role;

-- Poori chain dobara hisaab: koi row badli ho/hataayi ho to pehli kharab seq wapas
create or replace function public.commitment_verify(p_org uuid) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  r record;
  v_prev text := '';
  v_n bigint := 0;
  v_expect bigint := 1;
begin
  for r in select * from public.commitment_ledger where org_id = p_org order by seq loop
    if r.seq <> v_expect then
      return jsonb_build_object('ok', false, 'rows', v_n, 'bad_seq', v_expect, 'why', 'seq_gap');
    end if;
    if r.prev_seal <> v_prev then
      return jsonb_build_object('ok', false, 'rows', v_n, 'bad_seq', r.seq, 'why', 'prev_seal_mismatch');
    end if;
    if r.seal <> public.commitment_seal(r.org_id, r.seq, r.action, r.promise_id, r.prev_seal, r.payload) then
      return jsonb_build_object('ok', false, 'rows', v_n, 'bad_seq', r.seq, 'why', 'seal_mismatch');
    end if;
    v_prev := r.seal;
    v_n := v_n + 1;
    v_expect := v_expect + 1;
  end loop;
  return jsonb_build_object('ok', true, 'rows', v_n, 'head', nullif(v_prev, ''));
end $$;
revoke all on function public.commitment_verify(uuid) from public, anon, authenticated;
grant execute on function public.commitment_verify(uuid) to service_role;

-- -----------------------------------------------------------------------------
-- 4) commitment_record: EK atomic call = promise + task + (optional) calendar hold + ledger
--    Dobara bhejo (same org+thread+phrase+due) to naya kuch nahi banta, purani row wapas (idempotent send/retry).
-- -----------------------------------------------------------------------------
create or replace function public.commitment_record(
  p_org        uuid,
  p_user       uuid,
  p_phrase     text,
  p_action     text,
  p_due        date,
  p_thread     uuid default null,
  p_subject    text default null,
  p_exact      boolean default false,
  p_confidence numeric default 0,
  p_lang       text default 'en',
  p_to         text[] default '{}'::text[],
  p_with_event boolean default false,
  p_client_tag text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_key     text;
  v_prom    public.work_promises;
  v_task    uuid;
  v_event   uuid;
  v_title   text := left(coalesce(nullif(btrim(p_action), ''), 'Follow up'), 140);
  v_due_at  timestamptz;
  v_led     public.commitment_ledger;
begin
  if p_org is null or p_user is null then raise exception 'commitment_record: org/user required'; end if;
  if p_phrase is null or length(btrim(p_phrase)) < 4 then raise exception 'commitment_record: phrase required'; end if;
  if p_due is not null and (p_due < current_date - 1 or p_due > current_date + 3650) then
    raise exception 'commitment_record: due out of range';
  end if;

  v_key := encode(extensions.digest(convert_to(
             p_org::text || '|' || coalesce(p_thread::text, '') || '|' || lower(btrim(p_phrase)) || '|' || coalesce(p_due::text, ''),
             'UTF8'), 'sha256'), 'hex');

  select * into v_prom from public.work_promises where org_id = p_org and dedupe_key = v_key;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'promise_id', v_prom.id, 'task_id', v_prom.task_id,
                              'event_id', v_prom.event_id, 'ledger_id', v_prom.ledger_id);
  end if;

  -- deadline: din ka 17:00 UTC (kaam ka din khatam hone ka andaza); koi tareekh na ho to task bina due ke
  v_due_at := case when p_due is null then null else (p_due::timestamp + interval '17 hours') at time zone 'UTC' end;

  insert into public.work_tasks (org_id, title, status, owner, due_at, thread_id, thread_subject, source, created_by)
  values (p_org, v_title, 'todo', p_user::text, v_due_at, p_thread, p_subject, 'promise', p_user)
  returning id into v_task;

  if p_with_event and p_due is not null then
    insert into public.calendar_events (org_id, title, agenda, starts_at, ends_at, all_day, thread_id, thread_subject,
                                        kind, status, created_by)
    values (p_org, 'Due: ' || v_title, left(p_phrase, 500), p_due::timestamp at time zone 'UTC',
            (p_due + 1)::timestamp at time zone 'UTC', true, p_thread, p_subject, 'deadline', 'confirmed', p_user)
    returning id into v_event;
  end if;

  insert into public.work_promises (org_id, quote, suggested_title, suggested_due_at, thread_id, thread_subject, owner,
                                    confidence, status, task_id, promised_to, due_exact, lang, dedupe_key, event_id, source)
  values (p_org, left(p_phrase, 1000), v_title, v_due_at, p_thread, p_subject, p_user::text,
          greatest(0, least(100, coalesce(p_confidence, 0))), 'linked', v_task, coalesce(p_to, '{}'::text[]),
          coalesce(p_exact, false), coalesce(nullif(p_lang, ''), 'en'), v_key, v_event, 'compose')
  returning * into v_prom;

  update public.work_tasks set promise_id = v_prom.id, event_id = v_event where id = v_task;

  v_led := public.commitment_append(p_org, 'recorded', v_prom.id, v_task, v_event, p_thread, p_user,
             jsonb_build_object('phrase', left(p_phrase, 1000), 'action', v_title, 'due', p_due, 'exact', coalesce(p_exact, false),
                                'confidence', p_confidence, 'to', coalesce(p_to, '{}'::text[]), 'event', v_event is not null,
                                'client_tag', left(coalesce(p_client_tag, ''), 128)));
  update public.work_promises set ledger_id = v_led.id where id = v_prom.id;

  return jsonb_build_object('ok', true, 'duplicate', false, 'promise_id', v_prom.id, 'task_id', v_task,
                            'event_id', v_event, 'ledger_id', v_led.id, 'seq', v_led.seq, 'seal', v_led.seal);
end $$;
revoke all on function public.commitment_record(uuid, uuid, text, text, date, uuid, text, boolean, numeric, text, text[], boolean, text) from public, anon, authenticated;
grant execute on function public.commitment_record(uuid, uuid, text, text, date, uuid, text, boolean, numeric, text, text[], boolean, text) to service_role;

-- Status badalna (fulfilled / broken / snoozed / cancelled): task bhi saath, ledger mein nayi sealed row
create or replace function public.commitment_set_status(
  p_org uuid, p_user uuid, p_promise uuid, p_status text, p_new_due date default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prom public.work_promises;
  v_led  public.commitment_ledger;
  v_due_at timestamptz;
begin
  if p_status not in ('fulfilled','broken','snoozed','cancelled') then
    raise exception 'commitment_set_status: bad status %', p_status;
  end if;
  select * into v_prom from public.work_promises where id = p_promise and org_id = p_org for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_prom.status in ('fulfilled','cancelled') then
    return jsonb_build_object('ok', false, 'error', 'already_settled', 'status', v_prom.status);
  end if;
  if p_status = 'snoozed' and p_new_due is null then
    return jsonb_build_object('ok', false, 'error', 'new_due_required');
  end if;

  if p_status = 'snoozed' then
    v_due_at := (p_new_due::timestamp + interval '17 hours') at time zone 'UTC';
    update public.work_promises set suggested_due_at = v_due_at, status = 'linked' where id = p_promise;
    update public.work_tasks set due_at = v_due_at where id = v_prom.task_id;
    if v_prom.event_id is not null then
      update public.calendar_events set starts_at = p_new_due::timestamp at time zone 'UTC',
             ends_at = (p_new_due + 1)::timestamp at time zone 'UTC', updated_at = now() where id = v_prom.event_id;
    end if;
  else
    update public.work_promises set status = p_status, settled_at = now() where id = p_promise;
    update public.work_tasks set status = case p_status when 'fulfilled' then 'done' else 'cancelled' end,
           completed_at = case p_status when 'fulfilled' then now() else completed_at end
     where id = v_prom.task_id;
  end if;

  v_led := public.commitment_append(p_org, p_status, p_promise, v_prom.task_id, v_prom.event_id, v_prom.thread_id, p_user,
             jsonb_build_object('from', v_prom.status, 'new_due', p_new_due));
  return jsonb_build_object('ok', true, 'status', p_status, 'seq', v_led.seq, 'seal', v_led.seal);
end $$;
revoke all on function public.commitment_set_status(uuid, uuid, uuid, text, date) from public, anon, authenticated;
grant execute on function public.commitment_set_status(uuid, uuid, uuid, text, date) to service_role;

-- Ek hi call mein poora hisaab: pending wade jo due guzar chuke hain "broken" mark (nightly / on-demand)
create or replace function public.commitment_sweep_overdue(p_org uuid, p_grace_days int default 1) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare r record; n int := 0; v_led public.commitment_ledger;
begin
  for r in
    select p.id, p.task_id, p.event_id, p.thread_id, p.status
      from public.work_promises p
     where p.org_id = p_org and p.status = 'linked' and p.suggested_due_at is not null
       and p.suggested_due_at < now() - make_interval(days => greatest(p_grace_days, 0))
       and not exists (select 1 from public.work_tasks t where t.id = p.task_id and t.status = 'done')
     for update of p skip locked
  loop
    update public.work_promises set status = 'broken', settled_at = now() where id = r.id;
    v_led := public.commitment_append(p_org, 'broken', r.id, r.task_id, r.event_id, r.thread_id, null,
               jsonb_build_object('from', r.status, 'reason', 'overdue_sweep', 'grace_days', p_grace_days));
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'marked_broken', n);
end $$;
revoke all on function public.commitment_sweep_overdue(uuid, int) from public, anon, authenticated;
grant execute on function public.commitment_sweep_overdue(uuid, int) to service_role;

-- -----------------------------------------------------------------------------
-- 5) Attention cost (THREAD ECONOMICS) — WASM intent::cost_values() ka SQL jumla, sab integer
--    each  = ceil(words*60 / wpm) + 8            (8 = har recipient par context-switch seconds)
--    total = each * recipients
--    cost  = round(total * rate_minor_per_hour / 3600)      (minor = pence/cents)
--    call  = (recipients + 1) * 2 min ; suggest agar recipients>=3, words>=180 aur call sasti
-- -----------------------------------------------------------------------------
create table if not exists public.org_attention_rates (
  org_id               uuid primary key,
  currency             text not null default 'GBP' check (currency ~ '^[A-Z]{3}$'),
  rate_minor_per_hour  integer not null default 6000 check (rate_minor_per_hour between 100 and 1000000),
  wpm                  integer not null default 220 check (wpm between 60 and 600),
  updated_by           uuid,
  updated_at           timestamptz not null default now()
);
alter table public.org_attention_rates enable row level security;
revoke all on public.org_attention_rates from public, anon, authenticated;
grant select, insert, update on public.org_attention_rates to service_role;

create or replace function public.attention_cost(
  p_words int, p_recipients int, p_rate_minor_per_hour int, p_wpm int default 220
) returns table (seconds_each bigint, seconds_total bigint, cost_minor bigint)
language sql immutable parallel safe set search_path = public as $$
  with v as (
    select greatest(coalesce(p_words, 0), 0)::bigint as w,
           greatest(coalesce(p_recipients, 0), 0)::bigint as r,
           greatest(coalesce(p_rate_minor_per_hour, 0), 0)::bigint as rate,
           (case when coalesce(p_wpm, 0) <= 0 then 220 else p_wpm end)::bigint as wpm
  ), e as (
    select v.*, (((v.w * 60) + v.wpm - 1) / v.wpm) + 8 as each from v
  )
  select each, each * r, (each * r * rate + 1800) / 3600 from e
$$;
revoke all on function public.attention_cost(int, int, int, int) from public, anon, authenticated;
grant execute on function public.attention_cost(int, int, int, int) to service_role;

create or replace function public.attention_estimate(p_org uuid, p_words int, p_recipients int) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_rate int := 6000; v_wpm int := 220; v_cur text := 'GBP';
  c record; v_call_s bigint; v_call_cost bigint; v_suggest boolean;
begin
  select rate_minor_per_hour, wpm, currency into v_rate, v_wpm, v_cur
    from public.org_attention_rates where org_id = p_org;
  v_rate := coalesce(v_rate, 6000); v_wpm := coalesce(v_wpm, 220); v_cur := coalesce(v_cur, 'GBP');
  select * into c from public.attention_cost(p_words, p_recipients, v_rate, v_wpm);
  v_call_s := (greatest(p_recipients, 0) + 1) * 2 * 60;
  v_call_cost := (v_call_s * v_rate + 1800) / 3600;
  v_suggest := p_recipients >= 3 and p_words >= 180 and v_call_cost < c.cost_minor;
  return jsonb_build_object('currency', v_cur, 'rate_minor_per_hour', v_rate, 'wpm', v_wpm,
    'seconds_each', c.seconds_each, 'seconds_total', c.seconds_total, 'cost_minor', c.cost_minor,
    'call_minutes', 2, 'call_cost_minor', v_call_cost, 'suggest_call', v_suggest,
    'saving_minor', case when v_suggest then c.cost_minor - v_call_cost else 0 end);
end $$;
revoke all on function public.attention_estimate(uuid, int, int) from public, anon, authenticated;
grant execute on function public.attention_estimate(uuid, int, int) to service_role;

-- Send par log (suggestion maani gayi ya nahi => asli bachat ka saboot, jhoota claim nahi)
create table if not exists public.thread_economics_log (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null,
  user_id          uuid not null,
  thread_id        uuid,
  words            integer not null check (words >= 0),
  recipients       integer not null check (recipients >= 0),
  seconds_total    bigint not null,
  cost_minor       bigint not null,
  currency         text not null default 'GBP',
  call_suggested   boolean not null default false,
  call_accepted    boolean not null default false,
  saving_minor     bigint not null default 0,
  created_at       timestamptz not null default now()
);
create index if not exists thread_economics_org_time_idx on public.thread_economics_log (org_id, created_at desc);
alter table public.thread_economics_log enable row level security;
revoke all on public.thread_economics_log from public, anon, authenticated;
grant select, insert on public.thread_economics_log to service_role;

create or replace function public.thread_economics_record(
  p_org uuid, p_user uuid, p_thread uuid, p_words int, p_recipients int, p_call_accepted boolean default false
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare e jsonb; v_id uuid;
begin
  if p_org is null or p_user is null then raise exception 'thread_economics_record: org/user required'; end if;
  e := public.attention_estimate(p_org, p_words, p_recipients);
  insert into public.thread_economics_log
    (org_id, user_id, thread_id, words, recipients, seconds_total, cost_minor, currency, call_suggested, call_accepted, saving_minor)
  values (p_org, p_user, p_thread, greatest(p_words, 0), greatest(p_recipients, 0),
          (e->>'seconds_total')::bigint, (e->>'cost_minor')::bigint, e->>'currency',
          (e->>'suggest_call')::boolean, coalesce(p_call_accepted, false) and (e->>'suggest_call')::boolean,
          case when coalesce(p_call_accepted, false) and (e->>'suggest_call')::boolean then (e->>'saving_minor')::bigint else 0 end)
  returning id into v_id;
  return e || jsonb_build_object('id', v_id);
end $$;
revoke all on function public.thread_economics_record(uuid, uuid, uuid, int, int, boolean) from public, anon, authenticated;
grant execute on function public.thread_economics_record(uuid, uuid, uuid, int, int, boolean) to service_role;

-- -----------------------------------------------------------------------------
-- 6) Views (service_role se; app Rust ke through padhti hai)
-- -----------------------------------------------------------------------------
create or replace view public.v_commitments_open with (security_invoker = true) as
select p.org_id, p.id as promise_id, p.task_id, p.event_id, p.thread_id, p.thread_subject, p.owner,
       p.suggested_title as title, p.quote, p.suggested_due_at as due_at, p.due_exact, p.confidence, p.promised_to,
       case when p.suggested_due_at is null then null
            else (p.suggested_due_at::date - current_date) end as days_left,
       p.suggested_due_at is not null and p.suggested_due_at < now() as overdue,
       p.created_at
  from public.work_promises p
 where p.status = 'linked';

create or replace view public.v_commitments_due_soon with (security_invoker = true) as
select * from public.v_commitments_open
 where due_at is not null and due_at < now() + interval '3 days';

create or replace view public.v_commitment_kept_rate with (security_invoker = true) as
select p.org_id, p.owner,
       count(*) filter (where p.status = 'fulfilled')                      as kept,
       count(*) filter (where p.status = 'broken')                         as broken,
       count(*) filter (where p.status = 'linked')                         as open,
       count(*) filter (where p.status in ('fulfilled','broken'))          as settled,
       case when count(*) filter (where p.status in ('fulfilled','broken')) = 0 then null
            else round(100.0 * count(*) filter (where p.status = 'fulfilled')
                       / count(*) filter (where p.status in ('fulfilled','broken')), 1) end as kept_pct
  from public.work_promises p
 where p.source = 'compose'
 group by p.org_id, p.owner;

create or replace view public.v_thread_economics_monthly with (security_invoker = true) as
select l.org_id, date_trunc('month', l.created_at)::date as month, l.currency,
       count(*)                                  as emails,
       sum(l.words)                              as words,
       sum(l.seconds_total)                      as seconds_spent,
       sum(l.cost_minor)                         as cost_minor,
       count(*) filter (where l.call_suggested)  as calls_suggested,
       count(*) filter (where l.call_accepted)   as calls_accepted,
       sum(l.saving_minor)                       as saved_minor
  from public.thread_economics_log l
 group by l.org_id, date_trunc('month', l.created_at)::date, l.currency;

revoke all on public.v_commitments_open, public.v_commitments_due_soon, public.v_commitment_kept_rate,
              public.v_thread_economics_monthly from public, anon, authenticated;
grant select on public.v_commitments_open, public.v_commitments_due_soon, public.v_commitment_kept_rate,
              public.v_thread_economics_monthly to service_role;

-- -----------------------------------------------------------------------------
-- 7) SELF-TEST (SQL Editor mein hi): parity + chain. Kuch bhi galat => poori file fail, kuch half-apply nahi.
--    Test org ek random uuid hai; test rows ledger mein append-only hone ki wajah se rehti hain, is liye dummy org ka
--    chhota nishaan (kuch KB) — isko "E97 selftest" payload se pehchaana ja sakta hai.
-- -----------------------------------------------------------------------------
do $$
declare
  a record; v_org uuid := '00000000-0000-4000-8000-0000000e9700'; v_user uuid := '00000000-0000-4000-8000-0000000e9701';
  r1 jsonb; r2 jsonb; r3 jsonb; v jsonb; v_t0 bigint;
begin
  -- parity with WASM intent::cost_values (cargo test mein bhi yahi numbers)
  select * into a from public.attention_cost(400, 10, 10000, 220);
  if (a.seconds_each, a.seconds_total, a.cost_minor) is distinct from (118::bigint, 1180::bigint, 3278::bigint) then
    raise exception 'E97 SELFTEST: attention_cost parity 400w failed (% % %)', a.seconds_each, a.seconds_total, a.cost_minor;
  end if;
  select * into a from public.attention_cost(1500, 10, 10000, 220);
  if a.cost_minor <> 11611 then raise exception 'E97 SELFTEST: attention_cost parity 1500w failed (%)', a.cost_minor; end if;
  select * into a from public.attention_cost(220, 1, 3600, 0);
  if (a.seconds_each, a.cost_minor) is distinct from (68::bigint, 68::bigint) then raise exception 'E97 SELFTEST: wpm default failed'; end if;

  v := public.attention_estimate(v_org, 1500, 10);
  if (v->>'suggest_call')::boolean is not true or (v->>'saving_minor')::bigint <= 0 then
    raise exception 'E97 SELFTEST: estimate suggestion failed %', v;
  end if;
  v := public.attention_estimate(v_org, 40, 1);
  if (v->>'suggest_call')::boolean then raise exception 'E97 SELFTEST: chhoti email par jhoota call mashwara'; end if;

  -- record -> duplicate -> status -> verify
  r1 := public.commitment_record(v_org, v_user, 'E97 selftest: I will send details by Friday', 'Send details',
                                 current_date + 3, null, 'E97 selftest', true, 92, 'en', array['selftest@example.com'], true, 'tag');
  r2 := public.commitment_record(v_org, v_user, 'E97 selftest: I will send details by Friday', 'Send details',
                                 current_date + 3, null, 'E97 selftest', true, 92, 'en', array['selftest@example.com'], true, 'tag');
  if (r1->>'ok')::boolean is not true or (r1->>'duplicate')::boolean then raise exception 'E97 SELFTEST: record failed %', r1; end if;
  if (r2->>'duplicate')::boolean is not true or r2->>'promise_id' <> r1->>'promise_id' then
    raise exception 'E97 SELFTEST: dedupe failed %', r2;
  end if;
  if r1->>'task_id' is null or r1->>'event_id' is null then raise exception 'E97 SELFTEST: task/event missing %', r1; end if;

  r3 := public.commitment_set_status(v_org, v_user, (r1->>'promise_id')::uuid, 'snoozed', current_date + 5);
  if (r3->>'ok')::boolean is not true then raise exception 'E97 SELFTEST: snooze failed %', r3; end if;
  r3 := public.commitment_set_status(v_org, v_user, (r1->>'promise_id')::uuid, 'fulfilled');
  if (r3->>'ok')::boolean is not true then raise exception 'E97 SELFTEST: fulfil failed %', r3; end if;
  r3 := public.commitment_set_status(v_org, v_user, (r1->>'promise_id')::uuid, 'broken');
  if r3->>'error' is distinct from 'already_settled' then raise exception 'E97 SELFTEST: settled guard failed %', r3; end if;

  v := public.commitment_verify(v_org);
  if (v->>'ok')::boolean is not true or (v->>'rows')::int < 3 then raise exception 'E97 SELFTEST: chain verify failed %', v; end if;

  -- append-only: badalna mana hai
  begin
    update public.commitment_ledger set payload = '{}'::jsonb where org_id = v_org;
    raise exception 'E97 SELFTEST: ledger update ho gaya (nahi hona chahiye)';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.commitment_ledger where org_id = v_org;
    raise exception 'E97 SELFTEST: ledger delete ho gaya (nahi hona chahiye)';
  exception when insufficient_privilege then null; end;
end $$;

-- selftest ka task/event/promise saaf (ledger rows rehti hain — append-only)
delete from public.calendar_events where org_id = '00000000-0000-4000-8000-0000000e9700';
delete from public.work_tasks     where org_id = '00000000-0000-4000-8000-0000000e9700';
delete from public.work_promises  where org_id = '00000000-0000-4000-8000-0000000e9700';

notify pgrst, 'reload schema';
