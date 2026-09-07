-- ============================================================================
-- ANEXOCHAT · PHASE 16 + 17 + 18
--   16 — FILE TRUTH (evidence state machine)
--   17 — FILE SECURITY WITHOUT EXTERNAL API (self-hosted / deterministic)
--   18 — CONTENT SAFETY (classification → policy decision → enforcement)
--
--   Supabase #4 (PostgreSQL) = canonical truth. Idempotent + self-healing.
--   Har naya public table par GRANT + RLS.
--
-- LOCK (non-negotiable):
--   1. Chain: selected → uploading → uploaded → scanning → verified →
--      available → downloaded. Har step ka apna DB row + timestamp.
--      UI kabhi "Delivered" nahi likhta jab tak `available` row na ho.
--   2. Step aage nahi kood sakta: file_evidence_mark order enforce karta hai.
--   3. Koi external API nahi (DeepInfra/OpenAI/moderation API sab mamnu).
--      Scan verdict sirf: deterministic policy (magic bytes, ext/mime mismatch,
--      archive bomb ratio, signature match) + self-hosted clamd (127.0.0.1:3310)
--      + local classifier — sab ANEXOMAIL infra ke andar.
--   4. Insaani guftagu kabhi AI ko nahi bheji jati: safety sirf FILE bytes par.
--   5. Blocked file: bytes available nahi hote, safety event + review + strike.
--   6. No duplicate: Phase 13/14/15 transfer/chunk truth waisi hi hai, yeh
--      layer uske OOPAR evidence + safety hai.
-- ============================================================================

-- 0) version columns (self-healing) ------------------------------------------
alter table public.chat_file_versions
  add column if not exists safety        text not null default 'pending',
  add column if not exists safety_reason text,
  add column if not exists scanned_at    timestamptz,
  add column if not exists available_at  timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'chat_file_versions_safety_chk') then
    alter table public.chat_file_versions
      add constraint chat_file_versions_safety_chk
      check (safety in ('pending','scanning','clean','flagged','blocked','error'));
  end if;
end $$;

-- 1) PHASE 16 — evidence ledger (append-only, ek state ek dafa) ---------------
create table if not exists public.file_evidence (
  id          bigserial primary key,
  version_id  uuid not null references public.chat_file_versions(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  state       text not null check (state in
                ('selected','uploading','uploaded','scanning','verified','available','downloaded','blocked')),
  actor       text not null default 'engine',   -- engine | rust | bun | user
  detail      jsonb not null default '{}'::jsonb,
  at          timestamptz not null default now()
);
create unique index if not exists file_evidence_once
  on public.file_evidence(version_id, state) where state <> 'downloaded';
create index if not exists file_evidence_version on public.file_evidence(version_id, id);

grant select on public.file_evidence to authenticated;
grant all on public.file_evidence to service_role;
grant usage, select on sequence public.file_evidence_id_seq to service_role;
alter table public.file_evidence enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'file_evidence' and policyname = 'own evidence read') then
    create policy "own evidence read" on public.file_evidence
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

-- 2) PHASE 17 — deterministic file type policy (no AI, no API) ---------------
create table if not exists public.file_type_policy (
  id           bigserial primary key,
  label        text not null,
  extensions   text[] not null default '{}',
  mime_prefix  text,
  magic_hex    text,            -- expected leading bytes (hex, lowercase)
  decision     text not null check (decision in ('allow','quarantine','block')),
  reason       text not null,
  unique (label)
);

insert into public.file_type_policy (label, extensions, mime_prefix, magic_hex, decision, reason) values
  ('windows-executable', '{exe,dll,scr,msi,cpl}', 'application/', '4d5a',     'block',      'Executable binaries are never accepted'),
  ('linux-executable',   '{elf,bin,so}',          'application/', '7f454c46', 'block',      'Native ELF binaries are never accepted'),
  ('script-macro',       '{js,vbs,ps1,bat,cmd,sh,jar,hta,lnk,iso,img}', null, null, 'block', 'Script and macro carriers are blocked by policy'),
  ('office-macro',       '{docm,xlsm,pptm,xlsb}', null, null,                 'quarantine', 'Macro-enabled documents need review'),
  ('archive',            '{zip,rar,7z,gz,tar,bz2}', null, '504b0304',         'quarantine', 'Archives are expanded-ratio checked before release'),
  ('pdf',                '{pdf}',   'application/pdf', '25504446',            'allow',      'Standard document'),
  ('image',              '{png,jpg,jpeg,webp,gif,avif,heic}', 'image/', null, 'allow',      'Standard image'),
  ('video',              '{mp4,mov,webm,mkv,m4v}', 'video/', null,            'allow',      'Standard video'),
  ('audio',              '{mp3,wav,m4a,aac,flac,ogg}', 'audio/', null,        'allow',      'Standard audio'),
  ('document',           '{docx,xlsx,pptx,csv,txt,md,rtf,odt,ods}', null, null,'allow',      'Standard document')
on conflict (label) do update set
  extensions = excluded.extensions, mime_prefix = excluded.mime_prefix,
  magic_hex = excluded.magic_hex, decision = excluded.decision, reason = excluded.reason;

grant select on public.file_type_policy to authenticated;
grant all on public.file_type_policy to service_role;

-- 3) scan queue (self-hosted worker isay chalata hai) ------------------------
create table if not exists public.file_scan_jobs (
  version_id   uuid primary key references public.chat_file_versions(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid,
  name         text not null,
  bytes        bigint not null default 0,
  content_type text,
  storage_prefix text not null,
  chunk_count  int not null default 0,
  state        text not null default 'pending'
               check (state in ('pending','scanning','done','error')),
  attempts     int not null default 0,
  engines      jsonb not null default '[]'::jsonb,   -- kaun kaun engine chali
  findings     jsonb not null default '[]'::jsonb,
  verdict      text,
  claimed_at   timestamptz,
  finished_at  timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists file_scan_jobs_pending
  on public.file_scan_jobs(state, created_at) where state in ('pending','scanning');

grant select on public.file_scan_jobs to authenticated;
grant all on public.file_scan_jobs to service_role;
alter table public.file_scan_jobs enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'file_scan_jobs' and policyname = 'own scan read') then
    create policy "own scan read" on public.file_scan_jobs
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

-- 4) PHASE 18 — safety events + enforcement ----------------------------------
create table if not exists public.file_safety_events (
  id           bigserial primary key,
  version_id   uuid references public.chat_file_versions(id) on delete set null,
  user_id      uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid,
  name         text,
  classification text not null,        -- prohibited | dangerous | suspicious | clean
  decision     text not null check (decision in ('allow','quarantine','block')),
  reasons      jsonb not null default '[]'::jsonb,
  engines      jsonb not null default '[]'::jsonb,
  review_state text not null default 'open'
               check (review_state in ('open','reviewing','upheld','overturned')),
  reviewer_id  uuid,
  reviewed_at  timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists file_safety_events_user on public.file_safety_events(user_id, created_at desc);
create index if not exists file_safety_events_open on public.file_safety_events(review_state, created_at desc);

create table if not exists public.file_enforcement (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  strikes      int not null default 0,
  action       text not null default 'none'
               check (action in ('none','warned','uploads_paused','account_review')),
  last_event   timestamptz,
  note         text
);

grant select on public.file_safety_events to authenticated;
grant all on public.file_safety_events to service_role;
grant usage, select on sequence public.file_safety_events_id_seq to service_role;
grant select on public.file_enforcement to authenticated;
grant all on public.file_enforcement to service_role;
alter table public.file_safety_events enable row level security;
alter table public.file_enforcement enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'file_safety_events' and policyname = 'own safety read') then
    create policy "own safety read" on public.file_safety_events
      for select to authenticated using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies
                 where tablename = 'file_enforcement' and policyname = 'own enforcement read') then
    create policy "own enforcement read" on public.file_enforcement
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

-- 5) downloads (chain ka aakhri step — sirf asli download par) ---------------
create table if not exists public.file_downloads (
  id          bigserial primary key,
  version_id  uuid not null references public.chat_file_versions(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  bytes       bigint not null default 0,
  device      text,
  at          timestamptz not null default now()
);
create index if not exists file_downloads_version on public.file_downloads(version_id, at desc);
grant select on public.file_downloads to authenticated;
grant all on public.file_downloads to service_role;
grant usage, select on sequence public.file_downloads_id_seq to service_role;
alter table public.file_downloads enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies
                 where tablename = 'file_downloads' and policyname = 'own downloads read') then
    create policy "own downloads read" on public.file_downloads
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

/** PHASE 16: evidence row. Order enforce hota hai — step kabhi kood nahi sakta. */
create or replace function public.file_evidence_mark(
  _user uuid, _version uuid, _state text, _actor text default 'engine',
  _detail jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_order  text[] := array['selected','uploading','uploaded','scanning','verified','available','downloaded'];
  v_want   int;
  v_have   int;
begin
  if _state = 'blocked' then
    insert into public.file_evidence(version_id, user_id, state, actor, detail)
    values (_version, _user, 'blocked', _actor, _detail)
    on conflict do nothing;
    return jsonb_build_object('ok', true, 'state', 'blocked');
  end if;

  v_want := array_position(v_order, _state);
  if v_want is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown_state');
  end if;

  select coalesce(max(array_position(v_order, state)), 0) into v_have
    from public.file_evidence where version_id = _version and state <> 'blocked';

  if v_want > v_have + 1 then
    return jsonb_build_object('ok', false, 'reason', 'step_skipped',
                              'have', v_order[greatest(v_have,1)], 'want', _state);
  end if;

  insert into public.file_evidence(version_id, user_id, state, actor, detail)
  values (_version, _user, _state, _actor, _detail)
  on conflict do nothing;

  return jsonb_build_object('ok', true, 'state', _state);
end $$;

/** PHASE 16: poori chain — sirf woh steps jo DB mein sabit hain. */
create or replace function public.file_truth(_user uuid, _version uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_v      public.chat_file_versions;
  v_owner  boolean;
  v_rows   jsonb;
  v_job    public.file_scan_jobs;
begin
  select * into v_v from public.chat_file_versions where id = _version;
  if not found then return jsonb_build_object('found', false); end if;

  select exists (
    select 1 from public.chat_files f
     where f.id = v_v.file_id
       and (f.owner_id = _user
            or exists (select 1 from public.chat_participants p
                        where p.conversation_id = f.conversation_id and p.user_id = _user))
  ) into v_owner;
  if not v_owner then return jsonb_build_object('found', false); end if;

  select coalesce(jsonb_agg(jsonb_build_object('state', e.state, 'at', e.at,
                                               'actor', e.actor, 'detail', e.detail)
                            order by e.id), '[]'::jsonb) into v_rows
    from public.file_evidence e where e.version_id = _version;

  select * into v_job from public.file_scan_jobs where version_id = _version;

  return jsonb_build_object(
    'found', true,
    'version_id', _version,
    'bytes', v_v.bytes,
    'version', v_v.version,
    'safety', v_v.safety,
    'safety_reason', v_v.safety_reason,
    'available', v_v.available_at is not null,
    'blocked', v_v.safety = 'blocked',
    'chain', v_rows,
    'scan', case when v_job.version_id is null then null else jsonb_build_object(
      'state', v_job.state, 'engines', v_job.engines,
      'findings', v_job.findings, 'verdict', v_job.verdict,
      'attempts', v_job.attempts, 'finished_at', v_job.finished_at) end,
    'downloads', (select count(*) from public.file_downloads d where d.version_id = _version)
  );
end $$;

/** PHASE 17: deterministic type verdict — DB policy, koi model nahi. */
create or replace function public.file_type_verdict(
  _name text, _content_type text, _magic_hex text default null
) returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
declare
  v_ext   text := lower(coalesce(nullif(regexp_replace(_name, '^.*\.', ''), _name), ''));
  v_p     public.file_type_policy;
  v_magic text := lower(coalesce(_magic_hex, ''));
  v_reasons jsonb := '[]'::jsonb;
  v_decision text := 'allow';
  v_label text := 'unclassified';
begin
  -- 1) extension policy
  select * into v_p from public.file_type_policy
   where v_ext <> '' and v_ext = any(extensions)
   order by case decision when 'block' then 0 when 'quarantine' then 1 else 2 end
   limit 1;
  if found then
    v_label := v_p.label;
    v_decision := v_p.decision;
    if v_p.decision <> 'allow' then
      v_reasons := v_reasons || jsonb_build_object('code', 'extension_policy', 'detail', v_p.reason);
    end if;
  end if;

  -- 2) magic bytes: executable signature chahe naam kuch bhi ho
  if v_magic like '4d5a%' or v_magic like '7f454c46%' then
    v_decision := 'block';
    v_label := 'executable-magic';
    v_reasons := v_reasons || jsonb_build_object('code', 'executable_magic',
                   'detail', 'Leading bytes identify an executable binary');
  end if;

  -- 3) ext/mime mismatch (masquerading)
  if v_p.label is not null and v_p.mime_prefix is not null
     and coalesce(_content_type,'') not like v_p.mime_prefix || '%' then
    if v_decision = 'allow' then v_decision := 'quarantine'; end if;
    v_reasons := v_reasons || jsonb_build_object('code', 'mime_mismatch',
                   'detail', 'Declared type does not match the file extension');
  end if;

  -- 4) double extension trick
  if _name ~* '\.(pdf|jpg|png|docx|mp4)\.(exe|js|scr|bat|cmd|vbs)$' then
    v_decision := 'block';
    v_reasons := v_reasons || jsonb_build_object('code', 'double_extension',
                   'detail', 'Disguised double extension');
  end if;

  return jsonb_build_object('label', v_label, 'decision', v_decision, 'reasons', v_reasons);
end $$;

/** Worker (Rust primary) apna kaam uthata hai. Service role only. */
create or replace function public.file_scan_claim(_limit int default 2)
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
begin
  -- 10 min se atki scanning jobs wapas pending (self-heal)
  update public.file_scan_jobs
     set state = 'pending', claimed_at = null
   where state = 'scanning' and claimed_at < now() - interval '10 minutes';

  with picked as (
    select version_id from public.file_scan_jobs
     where state = 'pending' and attempts < 5
     order by created_at
     limit greatest(1, least(coalesce(_limit,2), 8))
     for update skip locked
  )
  update public.file_scan_jobs j
     set state = 'scanning', claimed_at = now(), attempts = j.attempts + 1
   where j.version_id in (select version_id from picked);

  return jsonb_build_object('jobs', coalesce((
    select jsonb_agg(jsonb_build_object(
      'version_id', j.version_id, 'user_id', j.user_id, 'name', j.name,
      'bytes', j.bytes, 'content_type', j.content_type,
      'storage_prefix', j.storage_prefix, 'chunk_count', j.chunk_count,
      'attempts', j.attempts))
    from public.file_scan_jobs j
    where j.state = 'scanning' and j.claimed_at >= now() - interval '30 seconds'
  ), '[]'::jsonb));
end $$;

/**
 * PHASE 17 + 18: verdict apply. `_engines` = kaun kaun local engine chali
 * (type-policy, clamd, entropy, archive-ratio, local-classifier). External API
 * ka naam yahan aana MAMNU hai — function usay reject karta hai.
 */
create or replace function public.file_scan_report(
  _version uuid, _engines jsonb, _classification text,
  _decision text, _findings jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_job  public.file_scan_jobs;
  v_v    public.chat_file_versions;
  v_bad  text;
  v_safety text;
  v_strikes int;
  v_action text;
begin
  select * into v_job from public.file_scan_jobs where version_id = _version;
  if not found then return jsonb_build_object('ok', false, 'reason', 'job_not_found'); end if;
  select * into v_v from public.chat_file_versions where id = _version;

  -- API-FREE LOCK: koi external engine naam aaya to verdict reject.
  select e into v_bad from jsonb_array_elements_text(coalesce(_engines,'[]'::jsonb)) e
   where e ~* '(deepinfra|openrouter|openai|anthropic|google|azure|http)';
  if v_bad is not null then
    return jsonb_build_object('ok', false, 'reason', 'external_engine_forbidden', 'engine', v_bad);
  end if;

  if _decision not in ('allow','quarantine','block') then
    return jsonb_build_object('ok', false, 'reason', 'bad_decision');
  end if;

  v_safety := case _decision when 'allow' then 'clean'
                             when 'quarantine' then 'flagged'
                             else 'blocked' end;

  update public.file_scan_jobs
     set state = 'done', finished_at = now(), engines = coalesce(_engines,'[]'::jsonb),
         findings = coalesce(_findings,'[]'::jsonb), verdict = _decision
   where version_id = _version;

  update public.chat_file_versions
     set safety = v_safety,
         safety_reason = case when _decision = 'allow' then null
                              else coalesce(_findings->0->>'detail', _classification) end,
         scanned_at = now(),
         available_at = case when _decision = 'allow' then now() else null end
   where id = _version;

  perform public.file_evidence_mark(v_job.user_id, _version, 'verified', 'rust',
            jsonb_build_object('engines', _engines, 'classification', _classification));

  if _decision = 'allow' then
    perform public.file_evidence_mark(v_job.user_id, _version, 'available', 'rust',
              jsonb_build_object('bytes', v_job.bytes));
  else
    perform public.file_evidence_mark(v_job.user_id, _version, 'blocked', 'rust',
              jsonb_build_object('classification', _classification, 'findings', _findings));

    insert into public.file_safety_events
      (version_id, user_id, workspace_id, name, classification, decision, reasons, engines)
    values (_version, v_job.user_id, v_job.workspace_id, v_job.name,
            _classification, _decision, coalesce(_findings,'[]'::jsonb), coalesce(_engines,'[]'::jsonb));

    if _decision = 'block' then
      insert into public.file_enforcement(user_id, strikes, action, last_event)
      values (v_job.user_id, 1, 'warned', now())
      on conflict (user_id) do update
        set strikes = file_enforcement.strikes + 1, last_event = now();
      select strikes into v_strikes from public.file_enforcement where user_id = v_job.user_id;
      v_action := case when v_strikes >= 5 then 'account_review'
                       when v_strikes >= 3 then 'uploads_paused'
                       else 'warned' end;
      update public.file_enforcement set action = v_action where user_id = v_job.user_id;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'safety', v_safety, 'decision', _decision);
end $$;

/** Blocked file kabhi download nahi hoti; Downloaded step sirf asli download par. */
create or replace function public.file_download_ack(
  _user uuid, _version uuid, _bytes bigint default 0, _device text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare v_v public.chat_file_versions;
begin
  select * into v_v from public.chat_file_versions where id = _version;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if v_v.available_at is null or v_v.safety <> 'clean' then
    return jsonb_build_object('ok', false, 'reason', 'not_available', 'safety', v_v.safety);
  end if;
  insert into public.file_downloads(version_id, user_id, bytes, device)
  values (_version, _user, greatest(coalesce(_bytes,0), 0), _device);
  perform public.file_evidence_mark(_user, _version, 'downloaded', 'user',
            jsonb_build_object('device', _device));
  return jsonb_build_object('ok', true);
end $$;

/** Safety dashboard truth (user apna, founder ko aggregate DB se milta hai). */
create or replace function public.file_safety_state(_user uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, extensions
as $$
begin
  return jsonb_build_object(
    'enforcement', coalesce((
      select jsonb_build_object('strikes', strikes, 'action', action, 'last_event', last_event)
      from public.file_enforcement where user_id = _user),
      jsonb_build_object('strikes', 0, 'action', 'none', 'last_event', null)),
    'queue', jsonb_build_object(
      'pending', (select count(*) from public.file_scan_jobs where state = 'pending'),
      'scanning', (select count(*) from public.file_scan_jobs where state = 'scanning')),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'classification', s.classification,
        'decision', s.decision, 'reasons', s.reasons, 'engines', s.engines,
        'review_state', s.review_state, 'created_at', s.created_at)
        order by s.created_at desc)
      from public.file_safety_events s where s.user_id = _user limit 25), '[]'::jsonb),
    'engines', jsonb_build_array('type-policy','clamd-local','entropy','archive-ratio','local-classifier'),
    'external_api', false
  );
end $$;

/**
 * PHASE 16: transfer begin/chunk ke evidence hooks. Rust/Bun in ko call karte
 * hain — chain ka pehla hissa insaan ke action se banta hai, guess se nahi.
 */
create or replace function public.file_evidence_for_transfer(
  _user uuid, _transfer uuid, _state text, _actor text default 'engine',
  _detail jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare v_version uuid;
begin
  select version_id into v_version from public.chat_transfers
   where id = _transfer and user_id = _user;
  if v_version is null then return jsonb_build_object('ok', false, 'reason', 'transfer_not_found'); end if;
  return public.file_evidence_mark(_user, v_version, _state, _actor, _detail);
end $$;

/**
 * PHASE 16/17 — commit ka naya sach: chunks verified hone par version bytes
 * "uploaded" hoti hain, "available" NAHI. Scan job queue hoti hai; availability
 * sirf scan verdict `allow` par milti hai. (Phase 13/15 ka baqi logic waisa hi.)
 */
create or replace function public.file_commit(
  _user uuid, _transfer uuid, _file_sha256 text
) returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_t public.chat_transfers;
  v_v public.chat_file_versions;
  v_f public.chat_files;
  v_missing jsonb;
  v_corrupt jsonb;
  v_keep int;
  v_type jsonb;
begin
  select * into v_t from public.chat_transfers where id = _transfer and user_id = _user;
  if not found then return jsonb_build_object('ok', false, 'reason', 'transfer_not_found'); end if;
  select * into v_v from public.chat_file_versions where id = v_t.version_id;
  select * into v_f from public.chat_files where id = v_v.file_id;

  select coalesce(jsonb_agg(idx order by idx), '[]'::jsonb) into v_missing
    from public.chat_file_chunks
   where version_id = v_v.id and state in ('pending','stored');
  select coalesce(jsonb_agg(idx order by idx), '[]'::jsonb) into v_corrupt
    from public.chat_file_chunks where version_id = v_v.id and state = 'corrupt';

  if jsonb_array_length(v_missing) > 0 or jsonb_array_length(v_corrupt) > 0 then
    if jsonb_array_length(v_corrupt) > 0 then
      update public.chat_file_versions set state = 'corrupt' where id = v_v.id;
    end if;
    return jsonb_build_object('ok', false, 'reason', 'incomplete',
                              'missing', v_missing, 'corrupt', v_corrupt);
  end if;

  update public.chat_file_versions
     set state = 'ready', ready_at = now(),
         file_sha256 = coalesce(_file_sha256, file_sha256),
         safety = case when safety in ('clean','flagged','blocked') then safety else 'pending' end,
         available_at = case when safety = 'clean' then coalesce(available_at, now()) else null end
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

  select versions_kept into v_keep from public.file_plan_limits
   where plan = (public.file_plan_for(_user)).plan;
  update public.chat_file_versions v
     set state = 'abandoned'
   where v.file_id = v_v.file_id
     and v.state = 'ready'
     and v.version <= v_v.version - coalesce(v_keep, 10);

  -- PHASE 16 evidence: bytes pohonch gayi, magar available nahi.
  perform public.file_evidence_mark(_user, v_v.id, 'uploading', 'engine',
            jsonb_build_object('transfer_id', _transfer));
  perform public.file_evidence_mark(_user, v_v.id, 'uploaded', 'engine',
            jsonb_build_object('bytes', v_v.bytes, 'chunks', v_v.chunk_count));

  -- PHASE 17: deterministic pre-verdict (naam + declared type) queue se pehle.
  v_type := public.file_type_verdict(v_f.name, v_v.content_type, null);

  insert into public.file_scan_jobs
    (version_id, user_id, workspace_id, name, bytes, content_type,
     storage_prefix, chunk_count, state, findings)
  values (v_v.id, _user, v_f.workspace_id, v_f.name, v_v.bytes, v_v.content_type,
          v_v.storage_prefix, v_v.chunk_count, 'pending',
          coalesce(v_type->'reasons', '[]'::jsonb))
  on conflict (version_id) do update
    set state = 'pending', claimed_at = null, finished_at = null, verdict = null;

  perform public.file_evidence_mark(_user, v_v.id, 'scanning', 'engine',
            jsonb_build_object('pre_verdict', v_type));

  -- Saaf block: yahin fasla, worker ka intezaar nahi.
  if v_type->>'decision' = 'block' then
    perform public.file_scan_report(v_v.id,
      jsonb_build_array('type-policy'), 'dangerous', 'block', v_type->'reasons');
    return jsonb_build_object('ok', true, 'file_id', v_v.file_id, 'version', v_v.version,
                              'bytes', v_v.bytes, 'safety', 'blocked',
                              'available', false, 'reason', 'blocked_by_policy');
  end if;

  return jsonb_build_object('ok', true, 'file_id', v_v.file_id, 'version', v_v.version,
                            'bytes', v_v.bytes, 'storage_prefix', v_v.storage_prefix,
                            'version_id', v_v.id, 'safety', 'pending', 'available', false);
end $$;

grant execute on function public.file_evidence_mark(uuid, uuid, text, text, jsonb) to service_role;
grant execute on function public.file_evidence_for_transfer(uuid, uuid, text, text, jsonb) to service_role;
grant execute on function public.file_truth(uuid, uuid) to authenticated, service_role;
grant execute on function public.file_type_verdict(text, text, text) to authenticated, service_role;
grant execute on function public.file_scan_claim(int) to service_role;
grant execute on function public.file_scan_report(uuid, jsonb, text, text, jsonb) to service_role;
grant execute on function public.file_download_ack(uuid, uuid, bigint, text) to service_role;
grant execute on function public.file_safety_state(uuid) to authenticated, service_role;
grant execute on function public.file_commit(uuid, uuid, text) to service_role;
