
-- E74 — Calendar #5: meeting par FILES (agenda, slides, contract) — 23 Oct 2026
--
-- Kya: organiser meeting par file jodta hai; organiser aur andar ke guests (jo isi workspace ke member hain) usay meeting kholte hi dekhte aur utarte hain.
-- NAYA STORAGE NAHI: wohi mail wala pipeline — bytes Storage Box par, `org_attachment_blobs` mein (org_id, sha256) se SIRF organisation ke andar dedup,
-- upload route `/file/attach` (type policy + clamd + quota pehle se), download route `/file/attach/get`. Yahan sirf "kis meeting par kaun si file" ka rishta.
--
-- Advance / safety (Rule 38)
--   * Aik hi file aik meeting par ek baar (unique event_id+sha256); aik meeting par max 10 files (mail ki max_files wali limit, ek hi jagah se).
--   * Jodna/hatana: sirf organiser (hatana: jisne joda woh bhi). Dekhna/utarna: organiser + attendee (workspace member, revoked nahi). Cancelled meeting par naya jodna band.
--   * blob GC KHATRA: mail_attach_gc sirf mail ke references dekhta tha — event ki file ko "yateem" samajh kar mita deta. Isi file mein mail_attach_gc dobara
--     (create or replace) is tarah ke ab calendar_event_files bhi dekhe. Ye E48 ki GC ka wahi body hai, sirf ek shart zyada.
--   * mail_attach_resolve (download) ko teesri shaakh: event ki file, sirf un ko jo meeting dekh sakte hain.
--   * Meeting delete => rows apne-aap (FK cascade); blob 2 din ki grace ke baad GC.
--   * RLS ON, anon/authenticated ko koi haq nahi, sab functions service_role only, search_path pinned. Naya table account-export mein to_jsonb se aa sakta hai (alag kaam nahi).
-- PEHLE: E48 (mail attach) aur E63 tak ki calendar. Dobara chalana safe. Kuch DROP nahi.
set lock_timeout = '5s';
set statement_timeout = '60s';
set search_path = public, extensions;

-- ---- 0. PREFLIGHT ---------------------------------------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.calendar_events') is null or to_regclass('public.calendar_attendees') is null then
    raise exception 'E74 PREFLIGHT: calendar tables maujood nahi' using errcode = 'AX074';
  end if;
  if to_regclass('public.org_attachment_blobs') is null or to_regclass('public.mail_outbound_attachments') is null
     or to_regprocedure('public.mail_attach_resolve(uuid,uuid)') is null or to_regprocedure('public.mail_attach_gc()') is null then
    raise exception 'E74 PREFLIGHT: pehle E48 (mail attachments) chalayen' using errcode = 'AX074';
  end if;
  if (select data_type from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'id') is distinct from 'uuid' then
    raise exception 'E74 PREFLIGHT: calendar_events.id uuid nahi' using errcode = 'AX074';
  end if;
end $$;

-- ---- 1. table -------------------------------------------------------------------------------------------------------------
create table if not exists public.calendar_event_files (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid   not null,
  event_id   uuid   not null references public.calendar_events(id) on delete cascade,
  sha256     text   not null check (sha256 ~ '^[0-9a-f]{64}$'),
  filename   text   not null check (char_length(filename) between 1 and 255),
  mime_type  text   check (char_length(mime_type) <= 120),
  size_bytes bigint not null check (size_bytes >= 0),
  added_by   uuid   not null,
  created_at timestamptz not null default now(),
  unique (event_id, sha256),
  foreign key (org_id, sha256) references public.org_attachment_blobs(org_id, sha256) on delete restrict
);
create index if not exists calendar_event_files_event_idx on public.calendar_event_files (event_id, created_at);
create index if not exists calendar_event_files_blob_idx  on public.calendar_event_files (org_id, sha256);
alter table public.calendar_event_files enable row level security;
revoke all on public.calendar_event_files from public, anon, authenticated;
grant all on public.calendar_event_files to service_role;
comment on table public.calendar_event_files is 'Meeting par lagi files. Bytes org_attachment_blobs / Storage Box mein; yahan sirf rishta (E74).';

-- ---- 2. kaun kya kar sakta hai (ek jagah) ----------------------------------------------------------------------------------
-- _write=true: organiser. _write=false: organiser ya attendee. Dono: active org member, account blocked nahi, meeting isi org ki.
-- Wapsi: NULL = ijazat; warna error code.
create or replace function public._cal_file_gate(_user uuid, _org uuid, _event uuid, _write boolean)
returns text language plpgsql stable security definer set search_path = public, extensions as $$
declare
  st text := null;
  em text;
  ev record;
begin
  if _user is null or _event is null then return 'bad_input'; end if;
  select lower(u.email) into em from auth.users u where u.id = _user;
  if em is null then return 'unauthorized'; end if;
  if to_regclass('public.account_integrity') is not null then
    select i.state into st from public.account_integrity i where i.user_id = _user;
    if st in ('blocked', 'purged') then return 'account_blocked'; end if;
  end if;
  if not exists (select 1 from public.org_members m
                  where m.user_id = _user and m.org_id = _org and coalesce(m.status::text, 'active') <> 'revoked') then
    return 'no_workspace';
  end if;
  select e.organiser, e.cancelled_at into ev from public.calendar_events e where e.id = _event and e.org_id = _org;
  if not found then return 'not_found'; end if;
  if lower(coalesce(ev.organiser, '')) = em then
    if _write and ev.cancelled_at is not null then return 'event_cancelled'; end if;
    return null;
  end if;
  if _write then return 'organiser_only'; end if;
  if exists (select 1 from public.calendar_attendees a where a.event_id = _event and lower(a.address) = em) then return null; end if;
  return 'not_found';
end $$;

-- ---- 3. attach: upload ho chuki (staged) file ko meeting se jodna -------------------------------------------------------------
create or replace function public.cal_file_attach(_user uuid, _org uuid, _event uuid, _staged uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  g    text := public._cal_file_gate(_user, _org, _event, true);
  s    record;
  n    int;
  newid uuid;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  perform pg_advisory_xact_lock(hashtext('cal_files:' || _event::text));
  select a.id, a.sha256, a.filename, a.mime_type, a.size_bytes into s
    from public.mail_outbound_attachments a
   where a.id = _staged and a.user_id = _user and a.org_id = _org;
  if not found then return jsonb_build_object('ok', false, 'error', 'attachment_not_found'); end if;
  if exists (select 1 from public.calendar_event_files f where f.event_id = _event and f.sha256 = s.sha256) then
    delete from public.mail_outbound_attachments where id = s.id;
    return jsonb_build_object('ok', false, 'error', 'already_attached');
  end if;
  select count(*) into n from public.calendar_event_files f where f.event_id = _event;
  if n >= public._ma_limit('max_files', 10) then
    return jsonb_build_object('ok', false, 'error', 'too_many_files', 'limit', public._ma_limit('max_files', 10));
  end if;
  insert into public.calendar_event_files (org_id, event_id, sha256, filename, mime_type, size_bytes, added_by)
  values (_org, _event, s.sha256, s.filename, s.mime_type, s.size_bytes, _user)
  returning id into newid;
  delete from public.mail_outbound_attachments where id = s.id;
  update public.org_attachment_blobs b set touched_at = now() where b.org_id = _org and b.sha256 = s.sha256;
  return jsonb_build_object('ok', true, 'id', newid, 'filename', s.filename, 'size_bytes', s.size_bytes);
end $$;

-- ---- 4. list ----------------------------------------------------------------------------------------------------------------
create or replace function public.cal_file_list(_user uuid, _org uuid, _event uuid)
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare
  g text := public._cal_file_gate(_user, _org, _event, false);
  can boolean;
  rows_j jsonb;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  can := public._cal_file_gate(_user, _org, _event, true) is null;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', f.id, 'filename', f.filename, 'mime_type', f.mime_type, 'size_bytes', f.size_bytes,
           'created_at', f.created_at, 'can_remove', can or f.added_by = _user,
           'scanned', coalesce((b.scan ->> 'scanned')::boolean, false)) order by f.created_at), '[]'::jsonb)
    into rows_j
    from public.calendar_event_files f
    join public.org_attachment_blobs b on b.org_id = f.org_id and b.sha256 = f.sha256
   where f.event_id = _event;
  return jsonb_build_object('ok', true, 'files', rows_j, 'can_add', can, 'max_files', public._ma_limit('max_files', 10));
end $$;

-- ---- 5. remove ----------------------------------------------------------------------------------------------------------------
create or replace function public.cal_file_remove(_user uuid, _org uuid, _event uuid, _id uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  g text := public._cal_file_gate(_user, _org, _event, false);
  can boolean;
  n int;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  can := public._cal_file_gate(_user, _org, _event, true) is null;
  delete from public.calendar_event_files f
   where f.id = _id and f.event_id = _event and f.org_id = _org and (can or f.added_by = _user);
  get diagnostics n = row_count;
  if n = 0 then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  return jsonb_build_object('ok', true, 'removed', n);
end $$;

-- ---- 6. download: mail_attach_resolve ko teesri shaakh (E48 ka baqi body jyon ka tyon) ------------------------------------------
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

  -- E74: meeting ki file — sirf wohi jo us meeting ko dekh sakta hai (organiser / attendee)
  select f.filename, f.mime_type, f.size_bytes, f.sha256, b.rel_path, f.org_id, f.event_id into r
    from public.calendar_event_files f
    join public.org_attachment_blobs b on b.org_id = f.org_id and b.sha256 = f.sha256
   where f.id = _id;
  if found and public._cal_file_gate(_user, r.org_id, r.event_id, false) is null then
    return jsonb_build_object('ok', true, 'rel_path', r.rel_path, 'filename', r.filename, 'mime_type', r.mime_type,
                              'size_bytes', r.size_bytes, 'sha256', r.sha256);
  end if;
  return jsonb_build_object('ok', false, 'error', 'not_found');
end $$;

-- ---- 7. GC: E48 ka body + "meeting ki file" ka reference ------------------------------------------------------------------------
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
       and not exists (select 1 from public.calendar_event_files f where f.org_id = b.org_id and f.sha256 = b.sha256)
       and (to_regclass('public.mail_attachments') is null
            or not exists (select 1 from public.mail_attachments m where m.org_id = b.org_id and m.sha256 = b.sha256))
    returning b.rel_path
  )
  select coalesce(array_agg(rel_path), '{}') into paths from gone;

  return jsonb_build_object('ok', true, 'staged_removed', ns, 'paths', to_jsonb(paths));
end $$;

-- ---- 8. grants ----------------------------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  for f in select unnest(array[
    'public._cal_file_gate(uuid,uuid,uuid,boolean)',
    'public.cal_file_attach(uuid,uuid,uuid,uuid)',
    'public.cal_file_list(uuid,uuid,uuid)',
    'public.cal_file_remove(uuid,uuid,uuid,uuid)',
    'public.mail_attach_resolve(uuid,uuid)',
    'public.mail_attach_gc()'])
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
