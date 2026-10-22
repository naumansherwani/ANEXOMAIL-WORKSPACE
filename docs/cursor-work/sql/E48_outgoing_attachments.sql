
-- E48 — G38: bheji jane wali mail mein ASLI attachments (upload -> org-ke-andar SHA-256 dedup -> quota -> send -> Sent mein download) — 20 Oct 2026
--
-- Sach jo audit mein mila: Compose ka Attach button file chhor deta tha, server par attachment ka koi raasta nahi tha (blueprint 8p).
-- Yeh file DB ka hissa deti hai. Bytes ka kaam Rust ka hai (`server/rust/attach_core.rs` + `attach_glue.rs`, route `/file/attach`),
-- MIME assemble Bun ka (`server/mail/attachments.ts`, mojooda sender ke andar).
--
-- Policy (founder 19 Oct 06:06/06:16, LOCKED): dedup SIRF organisation ke andar (cross-org kabhi nahi), bytes `/mnt/anexomail-box/attachments`
-- par, DB mein sirf metadata. Is liye: blob ki pehchan (org_id, sha256); file ka path us row mein likha hota hai.
--
-- Tables
--   mail_attach_limits            server ka sach: kitni bari mail Postfix le sakta hai (check script yahi milata hai)
--   org_attachment_blobs          (org_id, sha256) -> rel_path (har "generation" ka apna naya path => GC aur dobara-upload kabhi takrate nahi)
--   mail_outbound_attachments     upload ho chuki, abhi bheji nahi gayi ("staged") — 24 ghante baad GC (jab tak schedule mein na ho)
--   mail_attachments (+sha256, +scan)   bheji gayi mail ke saath asli row (Sent mein dikhti hai, download hoti hai)
--   mail_scheduled.attachment_ids       hold/schedule ke saath file ids
-- Functions (sab sirf service_role): mail_attach_ctx, _register, _remove, _stage_check, _commit, _resolve, _gc
-- Dobara chalana safe. Kuch delete/badalta nahi (sirf naye table/function/column).
set search_path = public, extensions;

create table if not exists public.mail_attach_limits (
  key        text primary key,
  value      bigint not null,
  note       text,
  updated_at timestamptz not null default now()
);
alter table public.mail_attach_limits enable row level security;
revoke all on public.mail_attach_limits from public, anon, authenticated;
grant all on public.mail_attach_limits to service_role;

-- 7_000_000 raw bytes: base64 (x4/3) + headers < Postfix ka default message_size_limit (10_240_000). Postfix badalne par (founder "haan")
-- yeh qeemat `attach-check.sh` ke batae hisaab se barhayi jati hai — Rust aur Bun dono isi ek jagah se padhte hain.
insert into public.mail_attach_limits (key, value, note) values
  ('server_ceiling_bytes', 7000000, 'raw bytes per message; value*4/3 + 200000 must stay under Postfix message_size_limit'),
  ('max_files',            10,      'files per message'),
  ('staged_ttl_hours',     24,      'unsent uploads are removed after this many hours (unless scheduled)'),
  ('max_staged_per_user',  50,      'unsent uploads one user may hold at once'),
  ('blob_grace_days',      2,       'unreferenced file stays this many days before the cleaner may remove it')
on conflict (key) do nothing;

create table if not exists public.org_attachment_blobs (
  org_id     uuid   not null,
  sha256     text   not null check (sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes bigint not null check (size_bytes >= 0),
  rel_path   text   not null,
  scan       jsonb  not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  touched_at timestamptz not null default now(),
  primary key (org_id, sha256)
);
alter table public.org_attachment_blobs enable row level security;
revoke all on public.org_attachment_blobs from public, anon, authenticated;
grant all on public.org_attachment_blobs to service_role;

create table if not exists public.mail_outbound_attachments (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null,
  user_id    uuid not null references auth.users(id) on delete cascade,
  sha256     text not null,
  filename   text not null,
  mime_type  text,
  size_bytes bigint not null,
  created_at timestamptz not null default now(),
  foreign key (org_id, sha256) references public.org_attachment_blobs(org_id, sha256) on delete restrict
);
create index if not exists mail_outbound_attachments_user_idx on public.mail_outbound_attachments(user_id, created_at);
create index if not exists mail_outbound_attachments_blob_idx on public.mail_outbound_attachments(org_id, sha256);
alter table public.mail_outbound_attachments enable row level security;
revoke all on public.mail_outbound_attachments from public, anon, authenticated;
grant all on public.mail_outbound_attachments to service_role;

do $$
begin
  if to_regclass('public.mail_attachments') is not null then
    alter table public.mail_attachments add column if not exists org_id uuid;
    alter table public.mail_attachments add column if not exists sha256 text;
    alter table public.mail_attachments add column if not exists scan jsonb;
    create index if not exists mail_attachments_blob_idx on public.mail_attachments(org_id, sha256) where sha256 is not null;
  end if;
  if to_regclass('public.mail_scheduled') is not null then
    alter table public.mail_scheduled add column if not exists attachment_ids uuid[];
  end if;
end $$;

create or replace function public._ma_limit(_key text, _default bigint)
returns bigint language sql stable security definer set search_path = public as $$
  select coalesce((select value from public.mail_attach_limits where key = _key), _default)
$$;

-- ── ctx: kaun, kis org, kitni limit ────────────────────────────────────────────────────────────────────────────────
create or replace function public.mail_attach_ctx(_user uuid, _org uuid default null)
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  org    uuid;
  plan   text := 'basic';
  sp     record;
  st     text := null;
  maxsend bigint := 26214400;
  ceil_  bigint := public._ma_limit('server_ceiling_bytes', 7000000);
  lim    bigint := 5368709120;
  used   bigint := 0;
  isf    boolean := false;
begin
  if _user is null or not exists (select 1 from auth.users where id = _user) then
    return jsonb_build_object('ok', false, 'error', 'unauthorized');
  end if;

  if to_regclass('public.account_integrity') is not null then
    select i.state into st from public.account_integrity i where i.user_id = _user;
    if st in ('blocked', 'purged') then return jsonb_build_object('ok', false, 'error', 'account_blocked'); end if;
  end if;

  if to_regclass('public.org_members') is null then
    return jsonb_build_object('ok', false, 'error', 'no_workspace');
  end if;
  if _org is not null and exists (select 1 from public.org_members m
                                   where m.user_id = _user and m.org_id = _org
                                     and coalesce(m.status::text, 'active') <> 'revoked') then
    org := _org;
  else
    select m.org_id into org from public.org_members m
     where m.user_id = _user and coalesce(m.status::text, 'active') <> 'revoked'
     order by m.org_id limit 1;
  end if;
  if org is null then return jsonb_build_object('ok', false, 'error', 'no_workspace'); end if;

  if to_regprocedure('public.org_plan_of(uuid)') is not null then
    plan := coalesce(public.org_plan_of(org), 'basic');
  end if;
  if to_regclass('public.founder_accounts') is not null then
    select exists (select 1 from public.org_members m join public.founder_accounts f on f.user_id = m.user_id
                    where m.org_id = org) into isf;
    if isf then plan := 'business_pro'; end if;
  end if;

  if to_regclass('public.storage_plans') is not null then
    select * into sp from public.storage_plans where plan_id = plan;
    if sp.plan_id is null then select * into sp from public.storage_plans where plan_id = 'basic'; end if;
    if sp.plan_id is not null then
      maxsend := sp.max_send_bytes;
      lim := coalesce(sp.pooled_bytes, sp.per_mailbox_bytes * greatest(coalesce(sp.mailbox_limit, 1), 1), lim);
    end if;
  end if;

  select coalesce(sum(b.size_bytes), 0) into used from public.org_attachment_blobs b where b.org_id = org;

  return jsonb_build_object(
    'ok', true, 'org_id', org, 'plan', plan,
    'message_cap_bytes', least(maxsend, ceil_),
    'plan_max_send_bytes', maxsend,
    'server_ceiling_bytes', ceil_,
    'max_files', public._ma_limit('max_files', 10),
    'org_limit_bytes', lim,
    'org_used_bytes', used);
end $$;

-- ── register: upload poori ho gayi, Rust ne sha256 nikala. Quota yahin atomically ──────────────────────────────────
-- Dedup: (org_id, sha256) pehle se ho to koi nayi byte nahi gini jati, mojooda rel_path wapas aata hai (deduped=true).
create or replace function public.mail_attach_register(
  _user uuid, _org uuid, _sha256 text, _size bigint, _filename text, _mime text, _rel_path text, _scan jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare
  c        jsonb := public.mail_attach_ctx(_user, _org);
  org      uuid;
  blob     public.org_attachment_blobs;
  inserted boolean := false;
  newid    uuid;
  nstaged  bigint;
  fname    text := left(coalesce(nullif(btrim(_filename), ''), 'file'), 255);
begin
  if (c->>'ok') is distinct from 'true' then return c; end if;
  org := (c->>'org_id')::uuid;
  if org is distinct from _org then
    return jsonb_build_object('ok', false, 'error', 'wrong_org');
  end if;
  if _sha256 is null or _sha256 !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok', false, 'error', 'bad_hash'); end if;
  if _size is null or _size < 0 then return jsonb_build_object('ok', false, 'error', 'bad_size'); end if;
  if _size > (c->>'message_cap_bytes')::bigint then
    return jsonb_build_object('ok', false, 'error', 'file_too_large', 'limit_bytes', (c->>'message_cap_bytes')::bigint);
  end if;
  if _rel_path is null or _rel_path !~ '^[0-9a-f-]{36}/[0-9a-f]{2}/[0-9a-f]{64}-[0-9a-f]{8}$' then
    return jsonb_build_object('ok', false, 'error', 'bad_path');
  end if;

  perform pg_advisory_xact_lock(hashtext('mail_attach:' || org::text));

  select count(*) into nstaged from public.mail_outbound_attachments where user_id = _user;
  if nstaged >= public._ma_limit('max_staged_per_user', 50) then
    return jsonb_build_object('ok', false, 'error', 'too_many_staged');
  end if;

  select * into blob from public.org_attachment_blobs where org_id = org and sha256 = _sha256;
  if blob.sha256 is null then
    if (c->>'org_used_bytes')::bigint + _size > (c->>'org_limit_bytes')::bigint then
      return jsonb_build_object('ok', false, 'error', 'org_quota_full',
        'used_bytes', (c->>'org_used_bytes')::bigint, 'limit_bytes', (c->>'org_limit_bytes')::bigint);
    end if;
    insert into public.org_attachment_blobs (org_id, sha256, size_bytes, rel_path, scan)
    values (org, _sha256, _size, _rel_path, coalesce(_scan, '{}'::jsonb))
    returning * into blob;
    inserted := true;
  else
    update public.org_attachment_blobs set touched_at = now() where org_id = org and sha256 = _sha256;
  end if;

  insert into public.mail_outbound_attachments (org_id, user_id, sha256, filename, mime_type, size_bytes)
  values (org, _user, _sha256, fname, left(coalesce(_mime, 'application/octet-stream'), 120), blob.size_bytes)
  returning id into newid;

  return jsonb_build_object('ok', true, 'id', newid, 'deduped', not inserted, 'rel_path', blob.rel_path,
                            'size_bytes', blob.size_bytes, 'filename', fname, 'scan', blob.scan);
end $$;

create or replace function public.mail_attach_remove(_user uuid, _id uuid)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare n int;
begin
  delete from public.mail_outbound_attachments where id = _id and user_id = _user;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'removed', n);
end $$;

-- ── stage_check: bhejne se pehle (Bun) — sab ids is user ki, is org ki, abhi tak "staged", limit ke andar ─────────────
create or replace function public.mail_attach_stage_check(_user uuid, _org uuid, _ids uuid[])
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  c    jsonb := public.mail_attach_ctx(_user, _org);
  ids  uuid[] := coalesce((select array_agg(distinct x) from unnest(_ids) x), '{}');
  rows_j jsonb;
  total  bigint;
  n      int;
begin
  if (c->>'ok') is distinct from 'true' then return c; end if;
  if cardinality(ids) = 0 then return jsonb_build_object('ok', true, 'files', '[]'::jsonb, 'total_bytes', 0); end if;
  if cardinality(ids) > (c->>'max_files')::int then
    return jsonb_build_object('ok', false, 'error', 'too_many_attachments', 'limit', (c->>'max_files')::int);
  end if;
  select count(*), coalesce(sum(a.size_bytes), 0),
         coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'filename', a.filename, 'mime_type', a.mime_type,
                  'size_bytes', a.size_bytes, 'sha256', a.sha256, 'rel_path', b.rel_path) order by a.created_at), '[]'::jsonb)
    into n, total, rows_j
    from public.mail_outbound_attachments a
    join public.org_attachment_blobs b on b.org_id = a.org_id and b.sha256 = a.sha256
   where a.id = any(ids) and a.user_id = _user and a.org_id = (c->>'org_id')::uuid;
  if n <> cardinality(ids) then return jsonb_build_object('ok', false, 'error', 'attachment_not_found'); end if;
  if total > (c->>'message_cap_bytes')::bigint then
    return jsonb_build_object('ok', false, 'error', 'attachments_too_large', 'limit_bytes', (c->>'message_cap_bytes')::bigint, 'total_bytes', total);
  end if;
  return jsonb_build_object('ok', true, 'files', rows_j, 'total_bytes', total, 'org_id', (c->>'org_id')::uuid);
end $$;

-- ── commit: mail sach-much chali gayi — ab Sent ki message ke saath asli rows, staged rows khatam ─────────────────
create or replace function public.mail_attach_commit(_user uuid, _org uuid, _ids uuid[], _message uuid)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare n int := 0;
begin
  if to_regclass('public.mail_attachments') is null or to_regclass('public.mail_messages') is null then
    return jsonb_build_object('ok', false, 'error', 'no_mail_tables');
  end if;
  if not exists (select 1 from public.mail_messages m where m.id = _message and m.org_id = _org) then
    return jsonb_build_object('ok', false, 'error', 'message_not_in_org');
  end if;
  insert into public.mail_attachments (message_id, org_id, filename, mime_type, size_bytes, disk_path, sha256, scan)
  select _message, a.org_id, a.filename, a.mime_type, a.size_bytes, b.rel_path, a.sha256, b.scan
    from public.mail_outbound_attachments a
    join public.org_attachment_blobs b on b.org_id = a.org_id and b.sha256 = a.sha256
   where a.id = any(coalesce(_ids, '{}')) and a.user_id = _user and a.org_id = _org
   order by a.created_at;
  get diagnostics n = row_count;
  delete from public.mail_outbound_attachments a
   where a.id = any(coalesce(_ids, '{}')) and a.user_id = _user and a.org_id = _org;
  update public.org_attachment_blobs b set touched_at = now()
   where b.org_id = _org and b.sha256 in (select x.sha256 from public.mail_attachments x where x.message_id = _message and x.sha256 is not null);
  return jsonb_build_object('ok', true, 'attached', n);
end $$;

-- ── resolve: download ke liye. Staged file sirf uploader ki; bheji hui file us org ke har (revoked nahi) member ki ─────
-- (wohi pahunch jo thread padhne ki hai: Rust thread read bhi org_id par hi chalta hai.)
create or replace function public.mail_attach_resolve(_user uuid, _id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  st text := null;
  r  record;
begin
  if to_regclass('public.account_integrity') is not null then
    select i.state into st from public.account_integrity i where i.user_id = _user;
    if st in ('blocked', 'purged') then return jsonb_build_object('ok', false, 'error', 'account_blocked'); end if;
  end if;

  select a.filename, a.mime_type, a.size_bytes, a.sha256, b.rel_path into r
    from public.mail_outbound_attachments a
    join public.org_attachment_blobs b on b.org_id = a.org_id and b.sha256 = a.sha256
   where a.id = _id and a.user_id = _user;
  if found then
    return jsonb_build_object('ok', true, 'rel_path', r.rel_path, 'filename', r.filename, 'mime_type', r.mime_type,
                              'size_bytes', r.size_bytes, 'sha256', r.sha256);
  end if;

  if to_regclass('public.mail_attachments') is not null and to_regclass('public.org_members') is not null then
    select x.filename, x.mime_type, x.size_bytes, x.sha256, b.rel_path into r
      from public.mail_attachments x
      join public.org_attachment_blobs b on b.org_id = x.org_id and b.sha256 = x.sha256
     where x.id = _id and x.sha256 is not null
       and exists (select 1 from public.org_members m
                    where m.user_id = _user and m.org_id = x.org_id and coalesce(m.status::text, 'active') <> 'revoked');
    if found then
      return jsonb_build_object('ok', true, 'rel_path', r.rel_path, 'filename', r.filename, 'mime_type', r.mime_type,
                                'size_bytes', r.size_bytes, 'sha256', r.sha256);
    end if;
  end if;
  return jsonb_build_object('ok', false, 'error', 'not_found');
end $$;

-- ── gc: roz ek baar (timer). Pehle purani staged rows, phir woh blobs jinhe koi nahi dekhta. Rows DB se hat'te hain, ─
-- phir hi script file hatati hai; har generation ka path alag hai, is liye dobara-upload purani file se kabhi nahi takrata.
create or replace function public.mail_attach_gc()
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare
  ttl   int := public._ma_limit('staged_ttl_hours', 24);
  grace int := public._ma_limit('blob_grace_days', 2);
  ns    int := 0;
  paths text[] := '{}';
begin
  if to_regclass('public.mail_scheduled') is not null
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'mail_scheduled' and column_name = 'attachment_ids') then
    delete from public.mail_outbound_attachments a
     where a.created_at < now() - make_interval(hours => ttl)
       and not exists (select 1 from public.mail_scheduled s
                        where s.attachment_ids @> array[a.id] and s.status in ('holding', 'queued'));
  else
    delete from public.mail_outbound_attachments a where a.created_at < now() - make_interval(hours => ttl);
  end if;
  get diagnostics ns = row_count;

  with gone as (
    delete from public.org_attachment_blobs b
     where b.touched_at < now() - make_interval(days => grace)
       and not exists (select 1 from public.mail_outbound_attachments a where a.org_id = b.org_id and a.sha256 = b.sha256)
       and (to_regclass('public.mail_attachments') is null
            or not exists (select 1 from public.mail_attachments m where m.org_id = b.org_id and m.sha256 = b.sha256))
    returning b.rel_path
  )
  select coalesce(array_agg(rel_path), '{}') into paths from gone;

  return jsonb_build_object('ok', true, 'staged_removed', ns, 'paths', to_jsonb(paths));
end $$;

do $$
declare f text;
begin
  for f in select unnest(array[
    'public._ma_limit(text,bigint)',
    'public.mail_attach_ctx(uuid,uuid)',
    'public.mail_attach_register(uuid,uuid,text,bigint,text,text,text,jsonb)',
    'public.mail_attach_remove(uuid,uuid)',
    'public.mail_attach_stage_check(uuid,uuid,uuid[])',
    'public.mail_attach_commit(uuid,uuid,uuid[],uuid)',
    'public.mail_attach_resolve(uuid,uuid)',
    'public.mail_attach_gc()'])
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
