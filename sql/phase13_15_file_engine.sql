-- ============================================================================
-- ANEXOCHAT · PHASE 13 + 14 + 15 — FILE ENGINE / LARGE-FILE / RESUMABLE 5GB
--   Supabase #4 (PostgreSQL = canonical truth)
--   Idempotent + self-healing. Har naya table par GRANT + RLS.
--
-- LOCK:
--   1. TRANSFER (bytes moved) aur STORAGE (bytes kept) do alag cheezein hain.
--      Business Pro: transfer unlimited · single file max 5 GB · pooled 1 TB store.
--   2. Version chain: same naam dobara aane par purani version zinda rehti hai.
--   3. Chunk integrity: har chunk ka sha256 DB mein; mismatch = chunk corrupt,
--      sirf woh chunk dobara (poori file kabhi nahi).
--   4. Resume identity = (workspace, conversation, name, bytes, file sha256).
--      Wahi identity dobara aayi to same version + missing chunk list milti hai.
--   5. Koi jhooti progress nahi: bytes_done sirf verified chunks ka jama hai.
--   6. Phase 48 mailbox quota se koi duplication nahi — yeh workspace file pool hai.
-- ============================================================================

-- 0) plan limits table (transfer vs storage, separate on purpose) -------------
create table if not exists public.file_plan_limits (
  plan              text primary key,
  max_file_bytes    bigint not null,
  pool_bytes        bigint not null,
  transfer_unlimited boolean not null default false,
  monthly_transfer_bytes bigint,          -- null = unlimited
  max_concurrent    int not null default 3,
  versions_kept     int not null default 10
);

insert into public.file_plan_limits
  (plan, max_file_bytes, pool_bytes, transfer_unlimited, monthly_transfer_bytes, max_concurrent, versions_kept)
values
  ('basic',        0,                       0,                        false, 0,                 0, 0),
  ('pro',          0,                       0,                        false, 0,                 0, 0),
  ('business',     2147483648,              274877906944,             false, 5497558138880,     3, 10),
  ('business_pro', 5368709120,              1099511627776,            true,  null,              6, 30),
  ('founder',      5368709120,              1099511627776,            true,  null,              8, 50)
on conflict (plan) do update set
  max_file_bytes = excluded.max_file_bytes,
  pool_bytes = excluded.pool_bytes,
  transfer_unlimited = excluded.transfer_unlimited,
  monthly_transfer_bytes = excluded.monthly_transfer_bytes,
  max_concurrent = excluded.max_concurrent,
  versions_kept = excluded.versions_kept;

grant select on public.file_plan_limits to authenticated;
grant all on public.file_plan_limits to service_role;
alter table public.file_plan_limits enable row level security;
drop policy if exists file_plan_limits_read on public.file_plan_limits;
create policy file_plan_limits_read on public.file_plan_limits
  for select to authenticated using (true);

-- 1) private bucket for large files (signed URLs only) ------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-files', 'chat-files', false, 5368709120)
on conflict (id) do update set public = false, file_size_limit = 5368709120;

-- 2) SELF-HEAL: purane/adhoore table jinme is phase ka koi bhi lazmi column nahi,
--    unko `_legacy_<timestamp>` naam de kar side par rakh dete hain (data delete nahi).
do $$
declare
  stamp text := to_char(now(), 'YYYYMMDDHH24MISS');
  need  jsonb := jsonb_build_object(
    'chat_files',           jsonb_build_array('id','workspace_id','conversation_id','owner_id','name','current_version','latest_bytes','content_type','created_at','updated_at','deleted_at'),
    'chat_file_versions',   jsonb_build_array('id','file_id','version','bytes','content_type','file_sha256','chunk_size','chunk_count','storage_prefix','state','created_by','created_at','ready_at'),
    'chat_file_chunks',     jsonb_build_array('version_id','idx','bytes','sha256','state','attempts','updated_at'),
    'chat_transfers',       jsonb_build_array('id','version_id','workspace_id','user_id','device_id','direction','state','bytes_total','transport','concurrency','started_at','last_seen_at','finished_at','error'),
    'chat_transfer_ledger', jsonb_build_array('id','workspace_id','user_id','transfer_id','direction','bytes','day','created_at')
  );
  tname text;
  cname text;
  bad   boolean;
begin
  for tname in select jsonb_object_keys(need) loop
    if to_regclass('public.' || tname) is null then
      continue;
    end if;
    bad := false;
    for cname in select jsonb_array_elements_text(need -> tname) loop
      if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = tname and column_name = cname
      ) then
        bad := true;
        exit;
      end if;
    end loop;
    if bad then
      execute format('alter table public.%I rename to %I', tname, tname || '_legacy_' || stamp);
      raise notice 'renamed conflicting table public.% -> %_legacy_%', tname, tname, stamp;
    end if;
  end loop;
end $$;


-- 2b) files + versions --------------------------------------------------------
create table if not exists public.chat_files (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null,
  conversation_id uuid references public.chat_conversations(id) on delete cascade,
  owner_id        uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  current_version int  not null default 0,
  latest_bytes    bigint not null default 0,
  content_type    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists chat_files_ws_idx on public.chat_files (workspace_id, updated_at desc);
create unique index if not exists chat_files_identity_idx
  on public.chat_files (workspace_id, coalesce(conversation_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name))
  where deleted_at is null;

create table if not exists public.chat_file_versions (
  id            uuid primary key default gen_random_uuid(),
  file_id       uuid not null references public.chat_files(id) on delete cascade,
  version       int  not null,
  bytes         bigint not null,
  content_type  text,
  file_sha256   text,
  chunk_size    bigint not null,
  chunk_count   int not null,
  storage_prefix text not null,
  state         text not null default 'transferring'
                check (state in ('transferring','ready','corrupt','abandoned')),
  created_by    uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  ready_at      timestamptz,
  unique (file_id, version)
);
create index if not exists chat_file_versions_file_idx
  on public.chat_file_versions (file_id, version desc);

create table if not exists public.chat_file_chunks (
  version_id  uuid not null references public.chat_file_versions(id) on delete cascade,
  idx         int  not null,
  bytes       bigint not null default 0,
  sha256      text,
  state       text not null default 'pending'
              check (state in ('pending','stored','verified','corrupt')),
  attempts    int not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (version_id, idx)
);
create index if not exists chat_file_chunks_missing_idx
  on public.chat_file_chunks (version_id, state);

-- 3) transfers (identity + resume + backpressure state) ----------------------
create table if not exists public.chat_transfers (
  id           uuid primary key default gen_random_uuid(),
  version_id   uuid not null references public.chat_file_versions(id) on delete cascade,
  workspace_id uuid not null,
  user_id      uuid not null references auth.users(id) on delete cascade,
  device_id    text,
  direction    text not null default 'upload' check (direction in ('upload','download')),
  state        text not null default 'active'
               check (state in ('active','paused','complete','failed')),
  bytes_total  bigint not null,
  transport    text not null default 'webtransport',
  concurrency  int not null default 3,
  started_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  finished_at  timestamptz,
  error        text
);
create index if not exists chat_transfers_user_idx
  on public.chat_transfers (user_id, state, last_seen_at desc);

-- 4) transfer ledger — append only (volume ≠ storage) ------------------------
create table if not exists public.chat_transfer_ledger (
  id           bigserial primary key,
  workspace_id uuid not null,
  user_id      uuid not null,
  transfer_id  uuid,
  direction    text not null,
  bytes        bigint not null,
  day          date not null default (now() at time zone 'utc')::date,
  created_at   timestamptz not null default now()
);
create index if not exists chat_transfer_ledger_ws_day_idx
  on public.chat_transfer_ledger (workspace_id, day desc);

-- grants + RLS ---------------------------------------------------------------
grant select on public.chat_files, public.chat_file_versions,
               public.chat_file_chunks, public.chat_transfers,
               public.chat_transfer_ledger to authenticated;
grant all on public.chat_files, public.chat_file_versions,
             public.chat_file_chunks, public.chat_transfers to service_role;
grant all on public.chat_transfer_ledger to service_role;
grant usage, select on sequence public.chat_transfer_ledger_id_seq to service_role;

alter table public.chat_files enable row level security;
alter table public.chat_file_versions enable row level security;
alter table public.chat_file_chunks enable row level security;
alter table public.chat_transfers enable row level security;
alter table public.chat_transfer_ledger enable row level security;

drop policy if exists chat_files_read on public.chat_files;
create policy chat_files_read on public.chat_files
for select to authenticated
using (
  owner_id = auth.uid()
  or exists (
    select 1 from public.chat_participants p
    where p.conversation_id = chat_files.conversation_id and p.user_id = auth.uid()
  )
);

drop policy if exists chat_file_versions_read on public.chat_file_versions;
create policy chat_file_versions_read on public.chat_file_versions
for select to authenticated
using (
  exists (
    select 1 from public.chat_files f
    where f.id = chat_file_versions.file_id
      and (f.owner_id = auth.uid()
           or exists (select 1 from public.chat_participants p
                      where p.conversation_id = f.conversation_id and p.user_id = auth.uid()))
  )
);

drop policy if exists chat_file_chunks_read on public.chat_file_chunks;
create policy chat_file_chunks_read on public.chat_file_chunks
for select to authenticated
using (
  exists (
    select 1 from public.chat_file_versions v
    join public.chat_files f on f.id = v.file_id
    where v.id = chat_file_chunks.version_id and f.owner_id = auth.uid()
  )
);

drop policy if exists chat_transfers_read on public.chat_transfers;
create policy chat_transfers_read on public.chat_transfers
for select to authenticated using (user_id = auth.uid());

drop policy if exists chat_transfer_ledger_read on public.chat_transfer_ledger;
create policy chat_transfer_ledger_read on public.chat_transfer_ledger
for select to authenticated using (user_id = auth.uid());

-- ── helpers ────────────────────────────────────────────────────────────────
create or replace function public.file_plan_for(_user uuid)
returns public.file_plan_limits
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_plan text := 'basic';
  v_row public.file_plan_limits;
begin
  if to_regclass('public.founder_accounts') is not null then
    if exists (select 1 from public.founder_accounts fa where fa.user_id = _user) then
      v_plan := 'founder';
    end if;
  end if;

  if v_plan = 'basic' and to_regclass('public.account_state') is null then
    null;
  end if;

  if v_plan = 'basic' then
    begin
      select coalesce(nullif(lower((public.account_state(_user)->>'plan')), ''), 'basic')
        into v_plan;
    exception when others then v_plan := 'basic';
    end;
  end if;

  select * into v_row from public.file_plan_limits where plan = v_plan;
  if not found then
    select * into v_row from public.file_plan_limits where plan = 'basic';
  end if;
  return v_row;
end $$;

/** Pooled storage = ready versions ka jama. Transfer = ledger ka jama. */
create or replace function public.file_pool_state(_user uuid, _workspace uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_lim public.file_plan_limits;
  v_stored bigint;
  v_month bigint;
  v_active int;
begin
  v_lim := public.file_plan_for(_user);

  select coalesce(sum(v.bytes), 0) into v_stored
  from public.chat_file_versions v
  join public.chat_files f on f.id = v.file_id
  where f.workspace_id = _workspace and v.state = 'ready' and f.deleted_at is null;

  select coalesce(sum(bytes), 0) into v_month
  from public.chat_transfer_ledger
  where workspace_id = _workspace
    and day >= date_trunc('month', (now() at time zone 'utc'))::date;

  select count(*) into v_active
  from public.chat_transfers
  where workspace_id = _workspace and state = 'active';

  return jsonb_build_object(
    'plan', v_lim.plan,
    'entitled', v_lim.max_file_bytes > 0,
    'max_file_bytes', v_lim.max_file_bytes,
    'pool_bytes', v_lim.pool_bytes,
    'stored_bytes', v_stored,
    'remaining_bytes', greatest(v_lim.pool_bytes - v_stored, 0),
    'percent', case when v_lim.pool_bytes > 0
                    then round((v_stored::numeric / v_lim.pool_bytes) * 100, 1) else 0 end,
    'transfer_unlimited', v_lim.transfer_unlimited,
    'transfer_month_bytes', v_month,
    'transfer_month_limit', v_lim.monthly_transfer_bytes,
    'max_concurrent', v_lim.max_concurrent,
    'active_transfers', v_active,
    'versions_kept', v_lim.versions_kept
  );
end $$;

-- ── PHASE 13/15: begin (resume identity) ───────────────────────────────────
create or replace function public.file_transfer_begin(
  _user uuid,
  _workspace uuid,
  _conv uuid,
  _name text,
  _content_type text,
  _bytes bigint,
  _file_sha256 text,
  _chunk_size bigint,
  _device text
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_lim public.file_plan_limits;
  v_pool jsonb;
  v_file uuid;
  v_ver public.chat_file_versions;
  v_next int;
  v_count int;
  v_transfer uuid;
  v_chunk bigint := greatest(coalesce(_chunk_size, 8388608), 1048576);
begin
  v_lim := public.file_plan_for(_user);
  if v_lim.max_file_bytes <= 0 then
    return jsonb_build_object('allowed', false, 'reason', 'plan_not_entitled', 'plan', v_lim.plan);
  end if;
  if _bytes > v_lim.max_file_bytes then
    return jsonb_build_object('allowed', false, 'reason', 'file_too_large',
                              'max_file_bytes', v_lim.max_file_bytes);
  end if;

  v_pool := public.file_pool_state(_user, _workspace);
  if (v_pool->>'remaining_bytes')::bigint < _bytes then
    return jsonb_build_object('allowed', false, 'reason', 'pool_full', 'pool', v_pool);
  end if;
  if not (v_pool->>'transfer_unlimited')::boolean
     and v_lim.monthly_transfer_bytes is not null
     and (v_pool->>'transfer_month_bytes')::bigint + _bytes > v_lim.monthly_transfer_bytes then
    return jsonb_build_object('allowed', false, 'reason', 'transfer_quota', 'pool', v_pool);
  end if;

  -- file identity (naam per workspace/conversation)
  select id into v_file from public.chat_files
   where workspace_id = _workspace
     and coalesce(conversation_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(_conv, '00000000-0000-0000-0000-000000000000'::uuid)
     and lower(name) = lower(_name)
     and deleted_at is null;

  if v_file is null then
    insert into public.chat_files (workspace_id, conversation_id, owner_id, name, content_type)
    values (_workspace, _conv, _user, _name, _content_type)
    returning id into v_file;
  end if;

  -- PHASE 15: resume identity — same (file, bytes, sha) = same version wapis
  select * into v_ver from public.chat_file_versions
   where file_id = v_file
     and bytes = _bytes
     and coalesce(file_sha256, '') = coalesce(_file_sha256, '')
     and state in ('transferring','corrupt')
   order by version desc limit 1;

  if v_ver.id is null then
    select coalesce(max(version), 0) + 1 into v_next
      from public.chat_file_versions where file_id = v_file;
    v_count := greatest(ceil(_bytes::numeric / v_chunk)::int, 1);
    insert into public.chat_file_versions (
      file_id, version, bytes, content_type, file_sha256,
      chunk_size, chunk_count, storage_prefix, created_by
    ) values (
      v_file, v_next, _bytes, _content_type, _file_sha256,
      v_chunk, v_count, _workspace || '/' || v_file || '/v' || v_next, _user
    ) returning * into v_ver;

    insert into public.chat_file_chunks (version_id, idx, bytes)
    select v_ver.id, g - 1,
           least(v_chunk, _bytes - (g - 1) * v_chunk)
    from generate_series(1, v_count) g
    on conflict do nothing;
  else
    update public.chat_file_versions set state = 'transferring' where id = v_ver.id;
  end if;

  insert into public.chat_transfers (
    version_id, workspace_id, user_id, device_id, bytes_total, concurrency
  ) values (
    v_ver.id, _workspace, _user, _device, _bytes, v_lim.max_concurrent
  ) returning id into v_transfer;

  return jsonb_build_object(
    'allowed', true,
    'transfer_id', v_transfer,
    'file_id', v_file,
    'version_id', v_ver.id,
    'version', v_ver.version,
    'chunk_size', v_ver.chunk_size,
    'chunk_count', v_ver.chunk_count,
    'storage_prefix', v_ver.storage_prefix,
    'resumed', (select count(*) from public.chat_file_chunks
                 where version_id = v_ver.id and state = 'verified') > 0,
    'missing', coalesce((select jsonb_agg(idx order by idx) from public.chat_file_chunks
                          where version_id = v_ver.id and state <> 'verified'), '[]'::jsonb),
    'verified_bytes', coalesce((select sum(bytes) from public.chat_file_chunks
                                 where version_id = v_ver.id and state = 'verified'), 0),
    'max_concurrent', v_lim.max_concurrent,
    'pool', v_pool
  );
end $$;

-- ── PHASE 14: chunk integrity ──────────────────────────────────────────────
/** Chunk store hone ke baad: sha256 match hua to verified, warna corrupt. */
create or replace function public.file_chunk_ack(
  _user uuid,
  _transfer uuid,
  _idx int,
  _bytes bigint,
  _sha256 text,
  _server_sha256 text
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_t public.chat_transfers;
  v_state text;
  v_done bigint;
begin
  select * into v_t from public.chat_transfers where id = _transfer and user_id = _user;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'transfer_not_found');
  end if;

  v_state := case
    when _server_sha256 is null or _sha256 is null then 'stored'
    when lower(_server_sha256) = lower(_sha256) then 'verified'
    else 'corrupt'
  end;

  update public.chat_file_chunks
     set bytes = coalesce(nullif(_bytes, 0), bytes),
         sha256 = coalesce(_sha256, sha256),
         state = v_state,
         attempts = attempts + 1,
         updated_at = now()
   where version_id = v_t.version_id and idx = _idx;

  update public.chat_transfers
     set last_seen_at = now(), state = case when state = 'paused' then 'active' else state end
   where id = _transfer;

  if v_state = 'verified' then
    insert into public.chat_transfer_ledger (workspace_id, user_id, transfer_id, direction, bytes)
    values (v_t.workspace_id, _user, _transfer, 'upload', coalesce(_bytes, 0));
  end if;

  select coalesce(sum(bytes), 0) into v_done
    from public.chat_file_chunks where version_id = v_t.version_id and state = 'verified';

  return jsonb_build_object(
    'ok', v_state <> 'corrupt',
    'chunk_state', v_state,
    'bytes_done', v_done,
    'bytes_total', v_t.bytes_total,
    'percent', case when v_t.bytes_total > 0
                    then round((v_done::numeric / v_t.bytes_total) * 100, 2) else 0 end
  );
end $$;

/** Truthful progress + missing/corrupt chunk list (resume ka asli source). */
create or replace function public.file_transfer_state(_user uuid, _transfer uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_t public.chat_transfers;
  v_v public.chat_file_versions;
  v_done bigint;
begin
  select * into v_t from public.chat_transfers where id = _transfer and user_id = _user;
  if not found then return jsonb_build_object('found', false); end if;
  select * into v_v from public.chat_file_versions where id = v_t.version_id;
  select coalesce(sum(bytes), 0) into v_done
    from public.chat_file_chunks where version_id = v_t.version_id and state = 'verified';

  return jsonb_build_object(
    'found', true,
    'transfer_id', v_t.id,
    'state', v_t.state,
    'transport', v_t.transport,
    'version_id', v_v.id,
    'version', v_v.version,
    'chunk_size', v_v.chunk_size,
    'chunk_count', v_v.chunk_count,
    'storage_prefix', v_v.storage_prefix,
    'bytes_total', v_t.bytes_total,
    'bytes_done', v_done,
    'percent', case when v_t.bytes_total > 0
                    then round((v_done::numeric / v_t.bytes_total) * 100, 2) else 0 end,
    'missing', coalesce((select jsonb_agg(idx order by idx) from public.chat_file_chunks
                          where version_id = v_t.version_id and state in ('pending','stored')), '[]'::jsonb),
    'corrupt', coalesce((select jsonb_agg(idx order by idx) from public.chat_file_chunks
                          where version_id = v_t.version_id and state = 'corrupt'), '[]'::jsonb)
  );
end $$;

create or replace function public.file_transfer_mark(
  _user uuid, _transfer uuid, _state text, _transport text, _error text
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
begin
  if _state not in ('active','paused','failed') then
    return jsonb_build_object('ok', false, 'reason', 'bad_state');
  end if;
  update public.chat_transfers
     set state = _state,
         transport = coalesce(nullif(_transport, ''), transport),
         error = _error,
         last_seen_at = now()
   where id = _transfer and user_id = _user;
  return jsonb_build_object('ok', found, 'state', _state);
end $$;

-- ── PHASE 13: commit (version becomes ready) ───────────────────────────────
create or replace function public.file_commit(
  _user uuid, _transfer uuid, _file_sha256 text
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_t public.chat_transfers;
  v_v public.chat_file_versions;
  v_missing jsonb;
  v_corrupt jsonb;
  v_keep int;
begin
  select * into v_t from public.chat_transfers where id = _transfer and user_id = _user;
  if not found then return jsonb_build_object('ok', false, 'reason', 'transfer_not_found'); end if;
  select * into v_v from public.chat_file_versions where id = v_t.version_id;

  select coalesce(jsonb_agg(idx order by idx), '[]'::jsonb) into v_missing
    from public.chat_file_chunks
   where version_id = v_v.id and state in ('pending','stored');
  select coalesce(jsonb_agg(idx order by idx), '[]'::jsonb) into v_corrupt
    from public.chat_file_chunks where version_id = v_v.id and state = 'corrupt';

  if jsonb_array_length(v_missing) > 0 or jsonb_array_length(v_corrupt) > 0 then
    update public.chat_file_versions set state = 'corrupt' where id = v_v.id
      and jsonb_array_length(v_corrupt) > 0;
    return jsonb_build_object('ok', false, 'reason', 'incomplete',
                              'missing', v_missing, 'corrupt', v_corrupt);
  end if;

  update public.chat_file_versions
     set state = 'ready', ready_at = now(),
         file_sha256 = coalesce(_file_sha256, file_sha256)
   where id = v_v.id;

  update public.chat_files
     set current_version = v_v.version,
         latest_bytes = v_v.bytes,
         content_type = coalesce(v_v.content_type, content_type),
         updated_at = now()
   where id = v_v.file_id;

  update public.chat_transfers
     set state = 'complete', finished_at = now(), last_seen_at = now()
   where id = _transfer;

  -- version retention (plan ke mutabiq purani versions abandoned)
  select versions_kept into v_keep from public.file_plan_limits
   where plan = (public.file_plan_for(_user)).plan;
  update public.chat_file_versions v
     set state = 'abandoned'
   where v.file_id = v_v.file_id
     and v.state = 'ready'
     and v.version <= v_v.version - coalesce(v_keep, 10);

  return jsonb_build_object('ok', true, 'file_id', v_v.file_id,
                            'version', v_v.version, 'bytes', v_v.bytes,
                            'storage_prefix', v_v.storage_prefix);
end $$;

/** File ka version chain — purani version kabhi chupti nahi. */
create or replace function public.file_versions(_user uuid, _file uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare v_rows jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'version_id', v.id, 'version', v.version, 'bytes', v.bytes,
           'state', v.state, 'file_sha256', v.file_sha256,
           'chunk_count', v.chunk_count, 'storage_prefix', v.storage_prefix,
           'created_at', v.created_at, 'ready_at', v.ready_at
         ) order by v.version desc), '[]'::jsonb) into v_rows
    from public.chat_file_versions v
    join public.chat_files f on f.id = v.file_id
   where v.file_id = _file
     and (f.owner_id = _user
          or exists (select 1 from public.chat_participants p
                     where p.conversation_id = f.conversation_id and p.user_id = _user));
  return jsonb_build_object('file_id', _file, 'versions', v_rows);
end $$;

/** Workspace file list + live transfers (UI ka single truth call). */
create or replace function public.file_engine_state(_user uuid, _workspace uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
begin
  return jsonb_build_object(
    'pool', public.file_pool_state(_user, _workspace),
    'files', coalesce((
      select jsonb_agg(jsonb_build_object(
        'file_id', f.id, 'name', f.name, 'bytes', f.latest_bytes,
        'content_type', f.content_type, 'version', f.current_version,
        'updated_at', f.updated_at,
        'versions', (select count(*) from public.chat_file_versions v
                      where v.file_id = f.id and v.state = 'ready')
      ) order by f.updated_at desc)
      from public.chat_files f
      where f.workspace_id = _workspace and f.deleted_at is null
        and f.current_version > 0
      limit 100), '[]'::jsonb),
    'transfers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'transfer_id', t.id, 'state', t.state, 'transport', t.transport,
        'bytes_total', t.bytes_total,
        'bytes_done', (select coalesce(sum(c.bytes), 0) from public.chat_file_chunks c
                        where c.version_id = t.version_id and c.state = 'verified'),
        'name', (select f.name from public.chat_files f
                  join public.chat_file_versions v on v.file_id = f.id
                 where v.id = t.version_id),
        'started_at', t.started_at, 'last_seen_at', t.last_seen_at, 'error', t.error
      ) order by t.last_seen_at desc)
      from public.chat_transfers t
      where t.workspace_id = _workspace and t.user_id = _user
        and t.state in ('active','paused','failed')
      limit 20), '[]'::jsonb)
  );
end $$;

grant execute on function public.file_plan_for(uuid) to service_role;
grant execute on function public.file_pool_state(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_transfer_begin(uuid, uuid, uuid, text, text, bigint, text, bigint, text) to service_role;
grant execute on function public.file_chunk_ack(uuid, uuid, int, bigint, text, text) to service_role;
grant execute on function public.file_transfer_state(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_transfer_mark(uuid, uuid, text, text, text) to service_role;
grant execute on function public.file_commit(uuid, uuid, text) to service_role;
grant execute on function public.file_versions(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_engine_state(uuid, uuid) to authenticated, service_role;
