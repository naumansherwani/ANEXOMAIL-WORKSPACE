-- E50 — G38b: AANE WALI mail ke attachments ke bytes bhi Storage Box par (E48 ke org-dedup blobs mein) — 20 Oct 2026
--
-- Pehle: aane wali mail ke attachments ka sirf naam/size (metadata) DB mein jata tha, bytes kahin nahi (thread mein chip khulta nahi tha).
-- Ab: Postfix pipe (Rust `anexomail-deliver`) mail DB mein daal kar usi mail ki copy local spool mein rakhta hai; ek timer (root) spool se
-- attachments nikal kar: SHA-256, clamd scan, Storage Box par file (`<org>/<sha[0..2]>/<sha>-<nonce8>`), aur yeh function DB mein jodta hai.
--   mail_attach_org_limit(org)          org ki storage hadd (plan se) — user ke bina
--   mail_attach_inbound_register(...)   ek attachment: quota + org-ke-andar dedup + mojooda `mail_attachments` row se jodna (ya nayi row)
-- Qaaida: dedup SIRF usi org ke andar (cross-org kabhi nahi, E48 jaisa). Virus mile to bytes rakhe NAHI jate, row par scan likha jata hai.
-- Quota bhar jaye to mail aati rehti hai, sirf attachment ke bytes nahi rakhe jate (row par sach likha jata hai: stored=false).
-- Function sirf service_role. Dobara chalana safe (E48 pehle chali honi chahiye).
set search_path = public, extensions;

do $$
begin
  if to_regprocedure('public.mail_attach_ctx(uuid,uuid)') is null or to_regclass('public.org_attachment_blobs') is null then
    raise exception 'E50: pehle E48 chalayen (org_attachment_blobs / mail_attach_ctx nahi mile)';
  end if;
end $$;

create or replace function public.mail_attach_org_limit(_org uuid)
returns bigint
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  plan text := 'basic';
  sp   record;
  lim  bigint := 5368709120;
  isf  boolean := false;
begin
  if to_regprocedure('public.org_plan_of(uuid)') is not null then
    plan := coalesce(public.org_plan_of(_org), 'basic');
  end if;
  if to_regclass('public.founder_accounts') is not null and to_regclass('public.org_members') is not null then
    select exists (select 1 from public.org_members m join public.founder_accounts f on f.user_id = m.user_id where m.org_id = _org) into isf;
    if isf then plan := 'business_pro'; end if;
  end if;
  if to_regclass('public.storage_plans') is not null then
    select * into sp from public.storage_plans where plan_id = plan;
    if sp.plan_id is null then select * into sp from public.storage_plans where plan_id = 'basic'; end if;
    if sp.plan_id is not null then
      lim := coalesce(sp.pooled_bytes, sp.per_mailbox_bytes * greatest(coalesce(sp.mailbox_limit, 1), 1), lim);
    end if;
  end if;
  return lim;
end $$;

-- _rel_path NULL = bytes nahi rakhne (virus / quota): sirf row par scan + sach likhna.
create or replace function public.mail_attach_inbound_register(
  _org uuid, _message uuid, _ordinal int, _filename text, _mime text, _size bigint, _sha256 text, _rel_path text, _scan jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare
  fname    text := left(coalesce(nullif(btrim(_filename), ''), 'file'), 255);
  mime     text := left(coalesce(nullif(btrim(_mime), ''), 'application/octet-stream'), 120);
  scan     jsonb := coalesce(_scan, '{}'::jsonb);
  blob     public.org_attachment_blobs;
  inserted boolean := false;
  used     bigint;
  rid      uuid;
  stored   boolean := false;
  why      text := null;
begin
  if _org is null or _message is null then return jsonb_build_object('ok', false, 'error', 'bad_args'); end if;
  if to_regclass('public.mail_attachments') is null or to_regclass('public.mail_messages') is null then
    return jsonb_build_object('ok', false, 'error', 'no_mail_tables');
  end if;
  if not exists (select 1 from public.mail_messages m where m.id = _message and m.org_id = _org) then
    return jsonb_build_object('ok', false, 'error', 'message_not_in_org');
  end if;
  if _size is null or _size < 0 then return jsonb_build_object('ok', false, 'error', 'bad_size'); end if;
  if _rel_path is not null then
    if _sha256 is null or _sha256 !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok', false, 'error', 'bad_hash'); end if;
    if _rel_path !~ '^[0-9a-f-]{36}/[0-9a-f]{2}/[0-9a-f]{64}-[0-9a-f]{8}$' or split_part(_rel_path, '/', 1) <> _org::text then
      return jsonb_build_object('ok', false, 'error', 'bad_path');
    end if;
  end if;

  perform pg_advisory_xact_lock(hashtext('mail_attach:' || _org::text));

  if _rel_path is null then
    why := coalesce(nullif(scan->>'reason', ''), case when scan->>'clamd' = 'found' then 'infected' else 'not_stored' end);
  else
    select * into blob from public.org_attachment_blobs where org_id = _org and sha256 = _sha256;
    if blob.sha256 is null then
      select coalesce(sum(b.size_bytes), 0) into used from public.org_attachment_blobs b where b.org_id = _org;
      if used + _size > public.mail_attach_org_limit(_org) then
        why := 'org_quota_full';
      else
        insert into public.org_attachment_blobs (org_id, sha256, size_bytes, rel_path, scan)
        values (_org, _sha256, _size, _rel_path, scan) returning * into blob;
        inserted := true;
        stored := true;
      end if;
    else
      update public.org_attachment_blobs set touched_at = now() where org_id = _org and sha256 = _sha256;
      stored := true;
    end if;
  end if;

  if not stored then scan := scan || jsonb_build_object('stored', false, 'reason', why); end if;

  -- mojooda row (ingest ne naam/size se banayi) — usi naam ki ordinal-wi row; na mile to nayi
  select x.id into rid from (
    select a.id, row_number() over (order by a.created_at, a.id) - 1 as rn
      from public.mail_attachments a where a.message_id = _message and a.filename = fname) x
   where x.rn = _ordinal;
  if rid is null then
    insert into public.mail_attachments (message_id, org_id, filename, mime_type, size_bytes, disk_path, sha256, scan)
    values (_message, _org, fname, mime, _size, case when stored then blob.rel_path end, case when stored then blob.sha256 end, scan);
  else
    update public.mail_attachments
       set org_id = _org, size_bytes = _size, mime_type = coalesce(mime_type, mime),
           disk_path = case when stored then blob.rel_path end,
           sha256 = case when stored then blob.sha256 end,
           scan = scan_new
      from (select scan as scan_new) s
     where id = rid;
  end if;

  return jsonb_build_object('ok', true, 'stored', stored, 'deduped', stored and not inserted,
                            'rel_path', case when stored then blob.rel_path end, 'reason', why);
end $$;

do $$
declare f text;
begin
  for f in select unnest(array['public.mail_attach_org_limit(uuid)',
                               'public.mail_attach_inbound_register(uuid,uuid,int,text,text,bigint,text,text,jsonb)'])
  loop
    execute format('revoke all on function %s from public', f);
    if exists (select 1 from pg_roles where rolname = 'anon') then execute format('revoke all on function %s from anon', f); end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then execute format('revoke all on function %s from authenticated', f); end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then execute format('grant execute on function %s to service_role', f); end if;
  end loop;
end $$;

select 'E50 inbound attachments' as item,
       to_regprocedure('public.mail_attach_inbound_register(uuid,uuid,int,text,text,bigint,text,text,jsonb)') is not null as ok;
