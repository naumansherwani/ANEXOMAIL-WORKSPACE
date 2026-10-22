
-- =============================================================================
-- E35 — Purani mailbox ko ANEXOMAIL mein laana (G30, 19 Oct 2026, founder "haan"): "MIGRATION-ONLY WALLED GARDEN".
--
--  Kya banta hai
--   * mig_sessions  : ek migration = ek row. Token DB banata hai (random 32 byte), sirf SHA-256 hash rakhta hai; token sirf
--                     ek dafa Rust ko milta hai. App-password KAHIN nahi (na yahan, na kisi aur table mein).
--   * mig_items     : har e-mail (folder, uidvalidity, uid) ka natija: copied / duplicate / too_large / failed. Resume isi se.
--   * mig_chain     : har e-mail ke liye ek append-only SHA-256 chain entry (+ aakhir mein seal). Change/delete trigger se band.
--   * migration_ingest(token, items) : AKELA raasta jo migration ki mail likhta hai. Token valid + session verified/running +
--                     locked=false ho tabhi likhta hai. Dedupe (Message-ID / raw hash), threading, folder, unread, sab yahin.
--   * mail_messages.mig_session_id + trigger : "walled garden" ki asli deewar. Is column wali row sirf tab ban sakti hai jab
--                     migration_ingest usi session ke liye gate khole (transaction-local), session open ho. Complete/failed/
--                     cancelled hote hi session LOCK => koi bhi aur raasta band. Normal mail (mig_session_id NULL) par asar nahi:
--                     trigger pehli line mein wapas aa jata hai. `mail_ingest` (Postfix ka raasta) ko haath nahi lagaya.
--
--  Sach (taake koi galat ummeed na rahe)
--   * Chain "tamper-EVIDENT" hai, tamper-PROOF nahi: DB ka superuser/service key wala chain dobara bana sakta hai. Isliye seal ka hash
--     user ko receipt mein milta hai — us ke paas rakhne se baad ki koi tabdeeli pakri jaati hai.
--   * Attachments ki files copy NAHI hoti (live inbound raasta bhi unhe nahi rakhta); chain mein poori raw mail ka hash hota hai.
--   * Custom folders `archive` mein jaate hain; Gmail "All Mail"/Starred/Important aur (default) Trash/Spam chhode jaate hain.
--
-- Hifazat: additive + idempotent; lock_timeout 15s; advisory lock; naye functions security definer + fixed search_path, browser ke roles se
-- execute/table huqooq chheene hue (sirf service_role). Schema (Part 1) aur self-test (Part 2) alag transactions; self-test ka saara data wapas.
-- Fail ho to: usi file ko shuru se theek karo (naya naam banned). Aakhri jawab: ek row `e35_result`.
-- =============================================================================

-- ============================ PART 1 — schema + functions (ek transaction) ===============================
begin;
set local lock_timeout = '15s';
set local statement_timeout = '120s';
select pg_advisory_xact_lock(hashtext('anexomail.E35'));

do $$
declare
  missing text[] := '{}';
begin
  if to_regclass('public.mail_threads')  is null then missing := missing || 'mail_threads';  end if;
  if to_regclass('public.mail_messages') is null then missing := missing || 'mail_messages'; end if;
  if to_regclass('public.mail_accounts') is null then missing := missing || 'mail_accounts'; end if;
  if to_regclass('public.org_members')   is null then missing := missing || 'org_members';   end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_threads' and column_name='org_id')
    then missing := missing || 'mail_threads.org_id (phase58)'; end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_messages' and column_name='to_addrs')
    then missing := missing || 'mail_messages.to_addrs (phase58)'; end if;
  if coalesce(array_length(missing, 1), 0) > 0 then
    raise exception 'E35 PREFLIGHT: yeh maujood nahi: % — pehle sql/phase58_mail_contract_final.sql wali schema chahiye', array_to_string(missing, ', ')
      using errcode = 'AX051';
  end if;
end $$;

-- 1. tables ------------------------------------------------------------------------------------------------
create table if not exists public.mig_sessions (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null,
  user_id            uuid not null,
  mailbox            text not null,
  provider           text not null,
  source_host        text not null,
  source_login       text not null,
  status             text not null default 'created',
  locked             boolean not null default false,
  cancel_requested   boolean not null default false,
  token_hash         text,
  token_expires_at   timestamptz,
  include_trash_spam boolean not null default false,
  folders_total      integer not null default 0,
  folders_done       integer not null default 0,
  current_folder     text,
  skipped_folders    jsonb not null default '[]'::jsonb,
  found              bigint not null default 0,
  copied             bigint not null default 0,
  duplicate          bigint not null default 0,
  skipped            bigint not null default 0,
  failed             bigint not null default 0,
  bytes              bigint not null default 0,
  last_error         text,
  chain_len          bigint not null default 0,
  chain_head         text,
  seal_hash          text,
  created_at         timestamptz not null default now(),
  verified_at        timestamptz,
  started_at         timestamptz,
  heartbeat_at       timestamptz,
  finished_at        timestamptz
);
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'mig_sessions_status_chk' and conrelid = 'public.mig_sessions'::regclass) then
    alter table public.mig_sessions add constraint mig_sessions_status_chk
      check (status in ('created', 'verified', 'running', 'completed', 'failed', 'cancelled'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'mig_sessions_mailbox_chk' and conrelid = 'public.mig_sessions'::regclass) then
    alter table public.mig_sessions add constraint mig_sessions_mailbox_chk check (mailbox = lower(mailbox));
  end if;
end $$;
create unique index if not exists mig_sessions_one_active_per_mailbox
  on public.mig_sessions (mailbox) where status in ('created', 'verified', 'running');
create index if not exists mig_sessions_org_idx  on public.mig_sessions (org_id, created_at desc);
create index if not exists mig_sessions_user_idx on public.mig_sessions (user_id, created_at desc);
create unique index if not exists mig_sessions_token_idx on public.mig_sessions (token_hash) where token_hash is not null;

create table if not exists public.mig_items (
  session_id     uuid not null references public.mig_sessions(id) on delete cascade,
  org_id         uuid not null,
  mailbox        text not null,
  folder         text not null,
  uidvalidity    bigint not null,
  uid            bigint not null,
  outcome        text not null,
  reason         text,
  raw_sha256     text not null default '',
  raw_size       bigint not null default 0,
  message_row_id uuid,
  thread_id      uuid,
  attachments    jsonb,
  created_at     timestamptz not null default now(),
  primary key (session_id, folder, uidvalidity, uid)
);
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'mig_items_outcome_chk' and conrelid = 'public.mig_items'::regclass) then
    alter table public.mig_items add constraint mig_items_outcome_chk check (outcome in ('copied', 'duplicate', 'too_large', 'failed'));
  end if;
end $$;
create index if not exists mig_items_raw_idx on public.mig_items (mailbox, raw_sha256) where raw_sha256 <> '';

create table if not exists public.mig_chain (
  session_id  uuid not null references public.mig_sessions(id) on delete cascade,
  org_id      uuid not null,
  seq         bigint not null,
  outcome     text not null,
  folder      text,
  uidvalidity bigint,
  uid         bigint,
  raw_sha256  text not null default '',
  body_sha256 text not null default '',
  row_id      uuid,
  copied      bigint,
  duplicate   bigint,
  skipped     bigint,
  failed      bigint,
  ts          bigint not null,
  prev_hash   text not null,
  entry_hash  text not null,
  primary key (session_id, seq)
);

-- chain: kabhi update nahi; delete sirf tab jab uska session hi (account deletion ke cascade se) ja chuka ho
create or replace function public.mig_chain_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'mig_chain append-only hai: entry badal nahi sakti' using errcode = 'AX052';
  end if;
  if tg_op = 'DELETE' then
    if exists (select 1 from public.mig_sessions s where s.id = old.session_id) then
      raise exception 'mig_chain append-only hai: entry hata nahi sakti' using errcode = 'AX052';
    end if;
    return old;
  end if;
  return new;
end $$;
drop trigger if exists mig_chain_append_only on public.mig_chain;
create trigger mig_chain_append_only before update or delete on public.mig_chain
  for each row execute function public.mig_chain_guard();

alter table public.mig_sessions enable row level security;
alter table public.mig_items    enable row level security;
alter table public.mig_chain    enable row level security;
revoke all on public.mig_sessions, public.mig_items, public.mig_chain from public, anon, authenticated;
grant all on public.mig_sessions, public.mig_items, public.mig_chain to service_role;

-- 2. mail_messages par provenance + deewar --------------------------------------------------------------
alter table public.mail_messages add column if not exists mig_session_id uuid;

create or replace function public.mail_messages_mig_gate() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.mig_session_id is null then
    return new;                                   -- normal mail: kuch nahi badla
  end if;
  if coalesce(current_setting('anexomail.mig_gate', true), '') is distinct from new.mig_session_id::text
     or not exists (select 1 from public.mig_sessions s
                     where s.id = new.mig_session_id and s.locked = false and s.status in ('verified', 'running')) then
    raise exception 'migration walled garden band hai: yeh row is raaste se nahi likhi ja sakti' using errcode = 'AX050';
  end if;
  return new;
end $$;
drop trigger if exists mail_messages_mig_gate_trg on public.mail_messages;
create trigger mail_messages_mig_gate_trg before insert on public.mail_messages
  for each row execute function public.mail_messages_mig_gate();

-- 3. chain hisaab (Rust ke mig_core::canonical se ek-ek akshar milta hai; wahan test pinned hai) ---------------
create or replace function public._mig_sha(_t text) returns text
language sql immutable set search_path = public as $$
  select encode(sha256(convert_to(_t, 'UTF8')), 'hex')
$$;

create or replace function public._mig_genesis(_session uuid, _mailbox text) returns text
language sql immutable set search_path = public as $$
  select public._mig_sha('ANX-MIG-GENESIS|' || _session::text || '|' || encode(convert_to(lower(_mailbox), 'UTF8'), 'hex'))
$$;

create or replace function public._mig_entry_hash(
  _prev text, _seq bigint, _outcome text, _folder text, _uidv bigint, _uid bigint,
  _raw text, _body text, _row uuid, _ts bigint,
  _copied bigint default 0, _dup bigint default 0, _skipped bigint default 0, _failed bigint default 0
) returns text language sql immutable set search_path = public as $$
  select public._mig_sha(
    case when _outcome = 'seal'
      then 'ANX-MIG-1|' || _prev || '|' || _seq || '|seal|' || _copied || '|' || _dup || '|' || _skipped || '|' || _failed || '|' || _ts
      else 'ANX-MIG-1|' || _prev || '|' || _seq || '|' || _outcome || '|' || encode(convert_to(coalesce(_folder, ''), 'UTF8'), 'hex')
           || '|' || _uidv || '|' || _uid || '|' || coalesce(_raw, '') || '|' || coalesce(_body, '') || '|'
           || coalesce(_row, '00000000-0000-0000-0000-000000000000'::uuid)::text || '|' || _ts
    end)
$$;

-- ek chain entry jodna (session row pehle se locked honi chahiye)
create or replace function public._mig_chain_add(
  _s public.mig_sessions, _outcome text, _folder text, _uidv bigint, _uid bigint, _raw text, _body text, _row uuid
) returns text language plpgsql set search_path = public, extensions as $$
declare
  v_prev text := coalesce(_s.chain_head, public._mig_genesis(_s.id, _s.mailbox));
  v_seq  bigint := _s.chain_len + 1;
  v_ts   bigint := extract(epoch from clock_timestamp())::bigint;
  v_hash text;
begin
  v_hash := public._mig_entry_hash(v_prev, v_seq, _outcome, _folder, _uidv, _uid, _raw, _body, _row, v_ts);
  insert into public.mig_chain (session_id, org_id, seq, outcome, folder, uidvalidity, uid, raw_sha256, body_sha256, row_id, ts, prev_hash, entry_hash)
  values (_s.id, _s.org_id, v_seq, _outcome, _folder, _uidv, _uid, coalesce(_raw, ''), coalesce(_body, ''), _row, v_ts, v_prev, v_hash);
  update public.mig_sessions set chain_len = v_seq, chain_head = v_hash where id = _s.id;
  return v_hash;
end $$;

-- 4. kaun kya dekh sakta hai ----------------------------------------------------------------------------
create or replace function public._mig_is_manager(_user uuid, _org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.org_members m
                  where m.org_id = _org and m.user_id = _user
                    and coalesce(m.status::text, 'active') <> 'revoked' and m.role::text in ('owner', 'admin'))
$$;

create or replace function public._mig_can_use_mailbox(_user uuid, _org uuid, _mailbox text) returns boolean
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_role text;
  v_email text;
  v_own boolean := false;
begin
  select m.role::text into v_role from public.org_members m
   where m.org_id = _org and m.user_id = _user and coalesce(m.status::text, 'active') <> 'revoked' limit 1;
  if v_role is null then return false; end if;
  if v_role in ('owner', 'admin', 'manager') then return true; end if;
  select lower(u.email) into v_email from auth.users u where u.id = _user;
  if v_email = lower(_mailbox) then return true; end if;
  if to_regclass('public.org_addresses') is not null then
    execute 'select exists (select 1 from public.org_addresses where org_id = $1 and lower(address) = $2 and owner_user_id = $3)'
      into v_own using _org, lower(_mailbox), _user;
  end if;
  return coalesce(v_own, false);
end $$;

-- 5. token se session (gate) ----------------------------------------------------------------------------
-- `_need_open` = true: sirf verified/running, locked=false, token mein waqt baqi. false: finish ke liye (token ka hash mile to kaafi).
create or replace function public._mig_by_token(_token text, _need_open boolean) returns public.mig_sessions
language plpgsql security definer set search_path = public, extensions as $$
declare
  s public.mig_sessions;
begin
  if _token is null or _token !~ '^[0-9a-f]{64}$' then
    return null;
  end if;
  select * into s from public.mig_sessions where token_hash = public._mig_sha(_token) for update;
  if s.id is null then return null; end if;
  if _need_open and (s.locked or s.status not in ('verified', 'running') or s.token_expires_at is null or s.token_expires_at < now()) then
    return null;
  end if;
  if not _need_open and s.locked then
    return null;
  end if;
  return s;
end $$;

create or replace function public._mig_gate_why(_token text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare s public.mig_sessions;
begin
  if _token is null or _token !~ '^[0-9a-f]{64}$' then return 'invalid_token'; end if;
  select * into s from public.mig_sessions where token_hash = public._mig_sha(_token);
  if s.id is null then return 'invalid_token'; end if;
  if s.locked then return 'session_locked'; end if;
  if s.status = 'created' then return 'not_verified'; end if;
  if s.token_expires_at is null or s.token_expires_at < now() then return 'token_expired'; end if;
  return 'session_closed';
end $$;

-- 6. session banana (token sirf yahan, ek dafa) ------------------------------------------------------------
create or replace function public.migration_session_create(
  _user uuid, _org uuid, _mailbox text, _provider text, _host text, _login text, _include_trash_spam boolean default false
) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_mb   text := lower(btrim(coalesce(_mailbox, '')));
  v_tok  text;
  v_id   uuid;
  v_old  public.mig_sessions;
  v_n    integer;
begin
  if v_mb = '' or _host is null or btrim(_host) = '' or _login is null or btrim(_login) = '' then
    return jsonb_build_object('ok', false, 'error', 'bad_input');
  end if;
  if not exists (select 1 from public.mail_accounts a where a.org_id = _org and lower(a.address) = v_mb) then
    return jsonb_build_object('ok', false, 'error', 'mailbox_not_found');
  end if;
  if not public._mig_can_use_mailbox(_user, _org, v_mb) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select count(*) into v_n from public.mig_sessions where user_id = _user and created_at > now() - interval '24 hours';
  if v_n >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many_sessions');
  end if;

  -- shuru hi na hui purani koshish (login nahi hua / worker nahi chala) 15 minute baad khud band
  update public.mig_sessions set status = 'cancelled', locked = true, token_hash = null, finished_at = now(), last_error = 'abandoned'
   where mailbox = v_mb and status in ('created', 'verified') and started_at is null and created_at < now() - interval '15 minutes';

  select * into v_old from public.mig_sessions where mailbox = v_mb and status in ('created', 'verified', 'running') limit 1;
  if v_old.id is not null then
    return jsonb_build_object('ok', false, 'error', 'session_active', 'session_id', v_old.id, 'status', v_old.status);
  end if;

  v_tok := encode(gen_random_bytes(32), 'hex');
  insert into public.mig_sessions (org_id, user_id, mailbox, provider, source_host, source_login, token_hash, token_expires_at, include_trash_spam, heartbeat_at)
  values (_org, _user, v_mb, left(coalesce(_provider, 'custom'), 24), left(lower(btrim(_host)), 253), left(btrim(_login), 320),
          public._mig_sha(v_tok), now() + interval '6 hours', coalesce(_include_trash_spam, false), now())
  returning id into v_id;
  return jsonb_build_object('ok', true, 'session_id', v_id, 'token', v_tok, 'mailbox', v_mb);
end $$;

-- login kaam kar gaya => gate "verified"
create or replace function public.migration_verify(_token text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s public.mig_sessions;
begin
  select * into s from public.mig_sessions where token_hash = case when _token ~ '^[0-9a-f]{64}$' then public._mig_sha(_token) end for update;
  if s.id is null then return jsonb_build_object('ok', false, 'error', 'invalid_token'); end if;
  if s.locked then return jsonb_build_object('ok', false, 'error', 'session_locked'); end if;
  if s.status not in ('created', 'verified', 'running') then return jsonb_build_object('ok', false, 'error', 'session_closed'); end if;
  update public.mig_sessions
     set status = case when status = 'created' then 'verified' else status end,
         verified_at = coalesce(verified_at, now()), heartbeat_at = now(), token_expires_at = now() + interval '6 hours'
   where id = s.id;
  return jsonb_build_object('ok', true, 'session_id', s.id, 'mailbox', s.mailbox, 'include_trash_spam', s.include_trash_spam);
end $$;

-- resume ke liye: ABHI kya ho chuka (island-ranges "1:500,502:900") --------------------------------------------
create or replace function public.migration_done(_token text, _folder text, _uidv bigint) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  s public.mig_sessions;
  v_r text;
begin
  s := public._mig_by_token(_token, true);
  if s.id is null then return jsonb_build_object('ok', false, 'error', 'gate_closed', 'why', public._mig_gate_why(_token)); end if;
  select string_agg(case when lo = hi then lo::text else lo || ':' || hi end, ',' order by lo) into v_r
    from (select min(uid) as lo, max(uid) as hi
            from (select uid, uid - row_number() over (order by uid) as g
                    from public.mig_items where session_id = s.id and folder = _folder and uidvalidity = _uidv) t
           group by g) x;
  return jsonb_build_object('ok', true, 'ranges', coalesce(v_r, ''));
end $$;

-- heartbeat + ginti (+ cancel ka sawal) ------------------------------------------------------------------------
create or replace function public.migration_progress(_token text, _p jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s public.mig_sessions;
begin
  s := public._mig_by_token(_token, true);
  if s.id is null then return jsonb_build_object('ok', false, 'error', 'gate_closed', 'why', public._mig_gate_why(_token)); end if;
  update public.mig_sessions
     set status = 'running', started_at = coalesce(started_at, now()),
         heartbeat_at = now(), token_expires_at = now() + interval '6 hours',
         folders_total = coalesce((_p->>'folders_total')::integer, folders_total),
         folders_done  = coalesce((_p->>'folders_done')::integer, folders_done),
         current_folder = nullif(_p->>'folder', ''),
         last_error = coalesce(nullif(left(_p->>'last_error', 60), ''), last_error),
         found = greatest(public.mig_sessions.found, coalesce((_p->>'found')::bigint, 0)),
         skipped_folders = case when jsonb_typeof(_p->'skipped_folders') = 'array' then _p->'skipped_folders' else skipped_folders end
   where id = s.id;
  return jsonb_build_object('ok', true, 'stop', s.cancel_requested);
end $$;

-- 7. AKELA likhne wala raasta ------------------------------------------------------------------------------
create or replace function public.migration_ingest(_token text, _items jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  s        public.mig_sessions;
  it       jsonb;
  v_oc     text;
  v_folder text;
  v_uidv   bigint;
  v_uid    bigint;
  v_raw    text;
  v_size   bigint;
  v_msgid  text;
  v_reply  text;
  v_refs   text[];
  v_subj   text;
  v_norm   text;
  v_sent   timestamptz;
  v_dir    text;
  v_app    text;
  v_seen   boolean;
  v_to     text[];
  v_cc     text[];
  v_text   text;
  v_html   text;
  v_att    jsonb;
  v_thread uuid;
  v_msg    uuid;
  v_dup_id uuid;
  v_acct   uuid;
  v_c bigint := 0; v_d bigint := 0; v_k bigint := 0; v_f bigint := 0; v_b bigint := 0;
  v_body_sha text;
  v_from   text;
begin
  s := public._mig_by_token(_token, true);
  if s.id is null then
    return jsonb_build_object('ok', false, 'error', 'gate_closed', 'why', public._mig_gate_why(_token));
  end if;
  if jsonb_typeof(_items) is distinct from 'array' then
    return jsonb_build_object('ok', false, 'error', 'bad_input');
  end if;
  select a.id into v_acct from public.mail_accounts a where a.org_id = s.org_id and lower(a.address) = s.mailbox limit 1;
  if v_acct is null then
    return jsonb_build_object('ok', false, 'error', 'mailbox_not_found');
  end if;

  -- gate kholna: sirf is transaction mein, sirf is session ke liye
  perform set_config('anexomail.mig_gate', s.id::text, true);

  for it in select * from jsonb_array_elements(_items) loop
    v_oc     := coalesce(it->>'outcome', 'copy');
    v_folder := left(coalesce(it->>'folder', ''), 500);
    v_uidv   := (it->>'uidvalidity')::bigint;
    v_uid    := (it->>'uid')::bigint;
    v_raw    := coalesce(it->>'raw_sha256', '');
    v_size   := coalesce((it->>'raw_size')::bigint, 0);
    if v_folder = '' or v_uidv is null or v_uid is null or v_oc not in ('copy', 'too_large', 'failed') then
      continue;                                                     -- kharab item chain mein nahi aata, baqi chalte hain
    end if;
    if v_oc = 'copy' and v_raw !~ '^[0-9a-f]{64}$' then
      continue;
    end if;
    if exists (select 1 from public.mig_items i where i.session_id = s.id and i.folder = v_folder and i.uidvalidity = v_uidv and i.uid = v_uid) then
      continue;                                                     -- dobara aaya: kuch nahi (idempotent)
    end if;

    if v_oc = 'too_large' then
      insert into public.mig_items (session_id, org_id, mailbox, folder, uidvalidity, uid, outcome, reason, raw_size)
      values (s.id, s.org_id, s.mailbox, v_folder, v_uidv, v_uid, 'too_large', coalesce(it->>'reason', 'too_large'), v_size);
      s := (select t from public.mig_sessions t where t.id = s.id);
      perform public._mig_chain_add(s, 'too_large', v_folder, v_uidv, v_uid, '', '', null);
      v_k := v_k + 1;
      continue;
    elsif v_oc = 'failed' then
      insert into public.mig_items (session_id, org_id, mailbox, folder, uidvalidity, uid, outcome, reason)
      values (s.id, s.org_id, s.mailbox, v_folder, v_uidv, v_uid, 'failed', left(coalesce(it->>'reason', 'failed'), 60));
      s := (select t from public.mig_sessions t where t.id = s.id);
      perform public._mig_chain_add(s, 'failed', v_folder, v_uidv, v_uid, '', '', null);
      v_f := v_f + 1;
      continue;
    end if;

    -- ---- copy ----
    v_msgid := nullif(btrim(coalesce(it->>'message_id', '')), '');
    v_reply := nullif(btrim(coalesce(it->>'in_reply_to', '')), '');
    select coalesce(array_agg(x), '{}') into v_refs from jsonb_array_elements_text(
      case when jsonb_typeof(it->'references') = 'array' then it->'references' else '[]'::jsonb end) x;
    if v_reply is not null then v_refs := array_append(v_refs, v_reply); end if;
    v_subj := coalesce(nullif(btrim(coalesce(it->>'subject', '')), ''), '(no subject)');
    v_norm := regexp_replace(v_subj, '^((re|fwd|fw)\s*:\s*)+', '', 'i');
    v_app  := case when it->>'app_folder' in ('inbox', 'sent', 'drafts', 'archive', 'spam', 'trash') then it->>'app_folder' else 'archive' end;
    -- live mail_threads.folder enum (public.mail_folder) hai: jo label enum mein na ho uski jagah 'inbox'
    if not exists (select 1 from pg_enum en where en.enumtypid = 'public.mail_folder'::regtype and en.enumlabel = v_app) then v_app := 'inbox'; end if;
    v_dir  := case when it->>'direction' = 'out' then 'out' else 'in' end;
    v_seen := coalesce((it->>'seen')::boolean, false);
    begin
      v_sent := coalesce(nullif(it->>'sent_at', '')::timestamptz, now());
    exception when others then
      v_sent := now();
    end;
    if v_sent > now() + interval '1 day' then v_sent := now(); end if;
    v_text := left(coalesce(it->>'body_text', ''), 200000);
    v_html := left(it->>'body_html', 400000);
    v_att  := case when jsonb_typeof(it->'attachments') = 'array' then it->'attachments' else null end;
    v_from := lower(coalesce(nullif(btrim(it->>'from_address'), ''), 'unknown'));
    select coalesce(array_agg(lower(x)), '{}') into v_to from jsonb_array_elements_text(
      case when jsonb_typeof(it->'to') = 'array' then it->'to' else '[]'::jsonb end) x;
    select coalesce(array_agg(lower(x)), '{}') into v_cc from jsonb_array_elements_text(
      case when jsonb_typeof(it->'cc') = 'array' then it->'cc' else '[]'::jsonb end) x;
    if cardinality(v_to) = 0 then v_to := array[s.mailbox]; end if;
    v_body_sha := public._mig_sha(v_text);

    -- duplicate? (a) isi mailbox mein wohi Message-ID  (b) isi mailbox mein pehle copy hui wohi raw mail
    v_dup_id := null;
    if v_msgid is not null then
      select m.id into v_dup_id from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
       where m.message_id = v_msgid and lower(t.mailbox_address) = s.mailbox limit 1;
    end if;
    if v_dup_id is null then
      select i.message_row_id into v_dup_id from public.mig_items i
       where i.mailbox = s.mailbox and i.raw_sha256 = v_raw and i.outcome = 'copied' limit 1;
      if v_dup_id is null and exists (select 1 from public.mig_items i where i.mailbox = s.mailbox and i.raw_sha256 = v_raw and i.outcome = 'copied') then
        v_dup_id := '00000000-0000-0000-0000-000000000000';
      end if;
    end if;
    if v_dup_id is not null then
      insert into public.mig_items (session_id, org_id, mailbox, folder, uidvalidity, uid, outcome, reason, raw_sha256, raw_size, message_row_id)
      values (s.id, s.org_id, s.mailbox, v_folder, v_uidv, v_uid, 'duplicate', 'already_in_mailbox', v_raw, v_size,
              nullif(v_dup_id, '00000000-0000-0000-0000-000000000000'::uuid));
      s := (select t from public.mig_sessions t where t.id = s.id);
      perform public._mig_chain_add(s, 'duplicate', v_folder, v_uidv, v_uid, v_raw, v_body_sha, nullif(v_dup_id, '00000000-0000-0000-0000-000000000000'::uuid));
      v_d := v_d + 1;
      continue;
    end if;

    -- Message-ID kisi AUR mailbox mein pehle se hai (unique index): yahan NULL ke saath rakho, mail phir bhi milti hai
    if v_msgid is not null and exists (select 1 from public.mail_messages m where m.message_id = v_msgid) then
      v_msgid := null;
    end if;

    -- thread: (1) jis mail ka jawab hai (2) wohi subject isi folder mein 30 din ke andar (3) naya
    v_thread := null;
    if cardinality(v_refs) > 0 then
      select t.id into v_thread from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
       where m.message_id = any (v_refs) and lower(t.mailbox_address) = s.mailbox
       order by t.last_message_at desc limit 1;
    end if;
    if v_thread is null then
      select t.id into v_thread from public.mail_threads t
       where lower(t.mailbox_address) = s.mailbox and t.folder = v_app::public.mail_folder and t.subject = v_norm
         and abs(extract(epoch from (t.last_message_at - v_sent))) <= 30 * 86400
       order by t.last_message_at desc limit 1;
    end if;
    if v_thread is null then
      insert into public.mail_threads (org_id, account_id, mailbox_address, subject, snippet, from_name, from_address,
                                       message_count, unread, starred, has_attachments, folder, last_message_at)
      values (s.org_id, v_acct, s.mailbox, v_norm, left(v_text, 180), it->>'from_name', v_from, 0,
              (v_dir = 'in' and not v_seen), coalesce((it->>'flagged')::boolean, false),
              (v_att is not null and jsonb_array_length(v_att) > 0), v_app::public.mail_folder, v_sent)
      returning id into v_thread;
    end if;

    insert into public.mail_messages (org_id, thread_id, direction, message_id, in_reply_to, from_name, from_address,
                                      to_addresses, cc_addresses, to_addrs, cc_addrs, subject, body_text, body_html, sent_at, mig_session_id)
    values (s.org_id, v_thread, v_dir::public.mail_direction, v_msgid, v_reply, it->>'from_name', v_from, v_to, v_cc, v_to, v_cc, v_subj, v_text, v_html, v_sent, s.id)
    returning id into v_msg;

    update public.mail_threads
       set message_count = (select count(*) from public.mail_messages m2 where m2.thread_id = v_thread),  -- gina hua (live mein thread naya banne par ginti pehle se 1 thi => '+ 1' galat deta)
           unread = unread or (v_dir = 'in' and not v_seen),
           starred = starred or coalesce((it->>'flagged')::boolean, false),
           has_attachments = has_attachments or (v_att is not null and jsonb_array_length(v_att) > 0),
           snippet = case when v_sent >= last_message_at then left(v_text, 180) else snippet end,
           last_message_at = greatest(last_message_at, v_sent),
           org_id = coalesce(org_id, s.org_id), account_id = coalesce(account_id, v_acct)
     where id = v_thread;

    insert into public.mig_items (session_id, org_id, mailbox, folder, uidvalidity, uid, outcome, raw_sha256, raw_size, message_row_id, thread_id, attachments)
    values (s.id, s.org_id, s.mailbox, v_folder, v_uidv, v_uid, 'copied', v_raw, v_size, v_msg, v_thread, v_att);
    s := (select t from public.mig_sessions t where t.id = s.id);
    perform public._mig_chain_add(s, 'copied', v_folder, v_uidv, v_uid, v_raw, v_body_sha, v_msg);
    v_c := v_c + 1;
    v_b := v_b + v_size;
  end loop;

  update public.mig_sessions
     set status = 'running', started_at = coalesce(started_at, now()), heartbeat_at = now(), token_expires_at = now() + interval '6 hours',
         copied = copied + v_c, duplicate = duplicate + v_d, skipped = skipped + v_k, failed = failed + v_f, bytes = bytes + v_b
   where id = s.id;
  select cancel_requested into v_seen from public.mig_sessions where id = s.id;
  return jsonb_build_object('ok', true, 'stop', coalesce(v_seen, false), 'copied', v_c, 'duplicate', v_d, 'skipped', v_k, 'failed', v_f);
end $$;

-- 8. band karna (seal + LOCK) ------------------------------------------------------------------------------
create or replace function public._mig_finish(_s public.mig_sessions, _status text, _error text) returns jsonb
language plpgsql set search_path = public, extensions as $$
declare
  s public.mig_sessions := _s;
  v_h text;
begin
  select * into s from public.mig_sessions where id = _s.id for update;
  if s.locked then
    return jsonb_build_object('ok', true, 'already', true, 'status', s.status, 'seal_hash', s.seal_hash, 'chain_len', s.chain_len);
  end if;
  -- seal: poori chain ka khulasa, aakhri entry. Iske baad kuch nahi likha ja sakta.
  declare
    v_prev text := coalesce(s.chain_head, public._mig_genesis(s.id, s.mailbox));
    v_seq  bigint := s.chain_len + 1;
    v_ts   bigint := extract(epoch from clock_timestamp())::bigint;
  begin
    v_h := public._mig_entry_hash(v_prev, v_seq, 'seal', null, null, null, null, null, null, v_ts, s.copied, s.duplicate, s.skipped, s.failed);
    insert into public.mig_chain (session_id, org_id, seq, outcome, copied, duplicate, skipped, failed, ts, prev_hash, entry_hash)
    values (s.id, s.org_id, v_seq, 'seal', s.copied, s.duplicate, s.skipped, s.failed, v_ts, v_prev, v_h);
    update public.mig_sessions
       set status = _status, locked = true, token_hash = null, token_expires_at = null, finished_at = now(),
           chain_len = v_seq, chain_head = v_h, seal_hash = v_h, last_error = left(_error, 60), current_folder = null
     where id = s.id;
  end;
  return jsonb_build_object('ok', true, 'status', _status, 'seal_hash', v_h, 'chain_len', s.chain_len + 1,
                            'copied', s.copied, 'duplicate', s.duplicate, 'skipped', s.skipped, 'failed', s.failed);
end $$;

create or replace function public.migration_finish(_token text, _status text, _error text default null) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s public.mig_sessions;
begin
  if _status not in ('completed', 'failed', 'cancelled') then
    return jsonb_build_object('ok', false, 'error', 'bad_status');
  end if;
  s := public._mig_by_token(_token, false);
  if s.id is null then return jsonb_build_object('ok', false, 'error', 'gate_closed', 'why', public._mig_gate_why(_token)); end if;
  return public._mig_finish(s, _status, _error);
end $$;

-- worker ruka (network / provider / restart) lekin kaam adhoora hai: token mar jata hai, Resume foran chal sakta hai.
-- Session band (locked) NAHI hota — wahi session wahin se aage chalta hai.
create or replace function public.migration_release(_token text, _error text default null) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s public.mig_sessions;
begin
  s := public._mig_by_token(_token, true);
  if s.id is null then return jsonb_build_object('ok', false, 'error', 'gate_closed', 'why', public._mig_gate_why(_token)); end if;
  update public.mig_sessions
     set token_hash = null, token_expires_at = null, heartbeat_at = now() - interval '1 hour',
         last_error = coalesce(nullif(left(_error, 60), ''), last_error), current_folder = null
   where id = s.id;
  return jsonb_build_object('ok', true, 'session_id', s.id);
end $$;

-- 9. session ka haal / cancel / resume (user ke naam se) ---------------------------------------------------------
create or replace function public._mig_summary(_s public.mig_sessions) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object(
    'id', _s.id, 'mailbox', _s.mailbox, 'provider', _s.provider, 'source_login', _s.source_login, 'status', _s.status,
    'locked', _s.locked, 'stale', (_s.status in ('created', 'verified', 'running') and _s.heartbeat_at < now() - interval '3 minutes'),
    'cancel_requested', _s.cancel_requested, 'current_folder', _s.current_folder,
    'folders_total', _s.folders_total, 'folders_done', _s.folders_done, 'skipped_folders', _s.skipped_folders,
    'found', _s.found, 'copied', _s.copied, 'duplicate', _s.duplicate, 'skipped', _s.skipped, 'failed', _s.failed, 'bytes', _s.bytes,
    'last_error', _s.last_error, 'chain_len', _s.chain_len, 'seal_hash', _s.seal_hash,
    'created_at', _s.created_at, 'started_at', _s.started_at, 'heartbeat_at', _s.heartbeat_at, 'finished_at', _s.finished_at)
$$;

create or replace function public.migration_get(_user uuid, _session uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s public.mig_sessions;
begin
  select * into s from public.mig_sessions where id = _session;
  if s.id is null or not (s.user_id = _user or public._mig_is_manager(_user, s.org_id)) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'session', public._mig_summary(s), 'source_host', s.source_host);
end $$;

create or replace function public.migration_list(_user uuid, _org uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  return jsonb_build_object('ok', true, 'sessions', coalesce((
    select jsonb_agg(public._mig_summary(s) order by s.created_at desc)
      from (select * from public.mig_sessions x
             where x.org_id = _org and (x.user_id = _user or public._mig_is_manager(_user, _org))
             order by x.created_at desc limit 30) s), '[]'::jsonb));
end $$;

create or replace function public.migration_cancel(_user uuid, _session uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s public.mig_sessions;
begin
  select * into s from public.mig_sessions where id = _session for update;
  if s.id is null or not (s.user_id = _user or public._mig_is_manager(_user, s.org_id)) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if s.locked then return jsonb_build_object('ok', true, 'already', true, 'status', s.status); end if;
  if s.status = 'running' and s.heartbeat_at >= now() - interval '3 minutes' then
    update public.mig_sessions set cancel_requested = true where id = s.id;   -- worker zinda hai: agle batch par ruk kar khud band karega
    return jsonb_build_object('ok', true, 'requested', true);
  end if;
  return public._mig_finish(s, 'cancelled', 'cancelled_by_user');
end $$;

-- resume: naya token, wohi session (purana token mar jata hai). App-password dobara user se (kabhi store nahi hota).
create or replace function public.migration_reopen(_user uuid, _session uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  s public.mig_sessions;
  v_tok text;
begin
  select * into s from public.mig_sessions where id = _session for update;
  if s.id is null or not (s.user_id = _user or public._mig_is_manager(_user, s.org_id)) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if s.locked or s.status not in ('created', 'verified', 'running') then
    return jsonb_build_object('ok', false, 'error', 'session_locked');
  end if;
  if s.heartbeat_at >= now() - interval '3 minutes' then
    return jsonb_build_object('ok', false, 'error', 'still_running');
  end if;
  v_tok := encode(gen_random_bytes(32), 'hex');
  update public.mig_sessions
     set token_hash = public._mig_sha(v_tok), token_expires_at = now() + interval '6 hours', heartbeat_at = now(),
         cancel_requested = false, status = case when status = 'created' then 'created' else 'verified' end
   where id = s.id;
  return jsonb_build_object('ok', true, 'token', v_tok, 'session_id', s.id, 'mailbox', s.mailbox, 'source_login', s.source_login,
                            'source_host', s.source_host, 'provider', s.provider, 'include_trash_spam', s.include_trash_spam);
end $$;

-- 10. chain: DB ki apni jaanch + export (Rust apni alag jaanch isi export par karta hai) -------------------------
create or replace function public.migration_chain_verify(_session uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  s    public.mig_sessions;
  r    public.mig_chain;
  v_prev text;
  v_want bigint := 1;
  v_n  bigint := 0;
  v_seal boolean := false;
begin
  select * into s from public.mig_sessions where id = _session;
  if s.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  v_prev := public._mig_genesis(s.id, s.mailbox);
  for r in select * from public.mig_chain where session_id = _session order by seq loop
    if v_seal then return jsonb_build_object('ok', false, 'broken_at', r.seq, 'why', 'entries_after_seal'); end if;
    if r.seq <> v_want then return jsonb_build_object('ok', false, 'broken_at', r.seq, 'why', 'sequence_gap'); end if;
    if r.prev_hash <> v_prev then return jsonb_build_object('ok', false, 'broken_at', r.seq, 'why', 'prev_hash_mismatch'); end if;
    if r.entry_hash <> public._mig_entry_hash(v_prev, r.seq, r.outcome, r.folder, r.uidvalidity, r.uid, r.raw_sha256, r.body_sha256, r.row_id, r.ts,
                                              coalesce(r.copied, 0), coalesce(r.duplicate, 0), coalesce(r.skipped, 0), coalesce(r.failed, 0)) then
      return jsonb_build_object('ok', false, 'broken_at', r.seq, 'why', 'entry_hash_mismatch');
    end if;
    v_prev := r.entry_hash;
    v_want := v_want + 1;
    v_n := v_n + 1;
    v_seal := (r.outcome = 'seal');
  end loop;
  if v_n <> s.chain_len or coalesce(s.chain_head, public._mig_genesis(s.id, s.mailbox)) <> v_prev then
    return jsonb_build_object('ok', false, 'broken_at', v_n + 1, 'why', 'head_mismatch');
  end if;
  return jsonb_build_object('ok', true, 'entries', v_n, 'head', v_prev, 'sealed', v_seal);
end $$;

create or replace function public.migration_chain_export(_user uuid, _session uuid, _after bigint default 0, _limit integer default 2000) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s public.mig_sessions;
begin
  select * into s from public.mig_sessions where id = _session;
  if s.id is null or not (s.user_id = _user or public._mig_is_manager(_user, s.org_id)) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'session_id', s.id, 'mailbox', s.mailbox, 'chain_len', s.chain_len,
    'rows', coalesce((select jsonb_agg(jsonb_build_object(
        'seq', c.seq, 'outcome', c.outcome, 'folder', c.folder, 'uidvalidity', c.uidvalidity, 'uid', c.uid,
        'raw_sha256', c.raw_sha256, 'body_sha256', c.body_sha256, 'row_id', c.row_id, 'ts', c.ts,
        'copied', c.copied, 'duplicate', c.duplicate, 'skipped', c.skipped, 'failed', c.failed,
        'prev_hash', c.prev_hash, 'entry_hash', c.entry_hash) order by c.seq)
       from (select * from public.mig_chain where session_id = _session and seq > _after order by seq limit greatest(least(_limit, 5000), 1)) c), '[]'::jsonb));
end $$;

-- 11. huqooq: sirf service_role ---------------------------------------------------------------------------
do $$
declare f text;
begin
  for f in select p.oid::regprocedure::text from pg_proc p
            where p.pronamespace = 'public'::regnamespace and (p.proname like 'migration\_%' or p.proname like '\_mig\_%' or p.proname in ('mig_chain_guard', 'mail_messages_mig_gate'))
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
notify pgrst, 'reload schema';
commit;

-- ============================ PART 2 — self-test (alag transaction, sab rollback) ===============================
do $$
declare
  v_org    uuid;
  v_user   uuid;
  v_stranger uuid := gen_random_uuid();
  v_mb     text := 'e35.' || substr(md5(random()::text), 1, 8) || '@e35.test';
  v_mb2    text := 'e35b.' || substr(md5(random()::text), 1, 8) || '@e35.test';
  v_r      jsonb;
  v_tok    text;
  v_tok2   text;
  v_sid    uuid;
  v_sid2   uuid;
  v_n      bigint;
  v_chk    integer := 0;
  v_note   text := '';
  v_hit    boolean;
  v_sql    text;
  v_msg    uuid;
  v_exp    text;
  s        public.mig_sessions;
  v_raw1   text := public._mig_sha('raw-one');
  v_raw2   text := public._mig_sha('raw-two');
  v_raw3   text := public._mig_sha('raw-three');
  v_raw4   text := public._mig_sha('raw-four');
begin
  perform set_config('anexo.e35_selftest', 'not run', false);
  begin
    -- ---- A. chain ka hisaab: Rust (mig_core.rs, canonical_text_is_pinned + known_vector) se EK-EK AKSHAR ----
    v_exp := public._mig_entry_hash('PREV', 2, 'copied', 'Sent Items', 5, 9, repeat('a', 64), repeat('b', 64), '00000000-0000-0000-0000-000000000000'::uuid, 100);
    if v_exp is distinct from public._mig_sha('ANX-MIG-1|PREV|2|copied|53656e74204974656d73|5|9|' || repeat('a', 64) || '|' || repeat('b', 64) || '|00000000-0000-0000-0000-000000000000|100') then
      raise exception 'E35 FAILED: chain canonical text badal gaya (Rust se mel nahi)' using errcode = 'AX053';
    end if;
    if public._mig_entry_hash('PREV', 3, 'seal', null, null, null, null, null, null, 7, 10, 2, 1, 0)
       is distinct from public._mig_sha('ANX-MIG-1|PREV|3|seal|10|2|1|0|7') then
      raise exception 'E35 FAILED: seal canonical text ghalat' using errcode = 'AX053';
    end if;
    if public._mig_genesis('00000000-0000-0000-0000-0000000000a1', 'Me@Anexomail.com')
       is distinct from public._mig_sha('ANX-MIG-GENESIS|00000000-0000-0000-0000-0000000000a1|' || encode(convert_to('me@anexomail.com', 'UTF8'), 'hex')) then
      raise exception 'E35 FAILED: genesis ghalat' using errcode = 'AX053';
    end if;
    -- Rust (mig_core::tests::known_vector_for_sql) ka chhapa hua hash — dono zabaan ek hi jawab dein
    if public._mig_entry_hash(public._mig_genesis('00000000-0000-0000-0000-0000000000a1', 'me@anexomail.com'), 1, 'copied', 'INBOX', 1700000000, 42,
         public._mig_sha('raw'), public._mig_sha('body'), '11111111-1111-1111-1111-111111111111'::uuid, 1760000000)
       is distinct from '983fb03f3a7f3db65d5ec7782a9fc722553fa10b288b09bd12e7400774fb4fed' then
      raise exception 'E35 FAILED: SQL aur Rust ka chain hash alag hai' using errcode = 'AX053';
    end if;
    v_chk := v_chk + 4;

    -- ---- B. ek asli org + member dhoondo (kuch banate nahi) ----
    select m.org_id, m.user_id into v_org, v_user
      from public.org_members m
      join public.mail_accounts a on a.org_id = m.org_id
     where coalesce(m.status::text, 'active') <> 'revoked' and m.role::text = 'owner'
     limit 1;
    if v_org is null then
      v_note := 'koi org+owner+mail_account nahi mila — sirf chain-hisaab check hua;';
    else
      insert into public.mail_accounts (org_id, address) values (v_org, v_mb), (v_org, v_mb2);

      -- huqooq/shape
      v_r := public.migration_session_create(v_stranger, v_org, v_mb, 'gmail', 'imap.gmail.com', 'x@gmail.com');
      if v_r->>'error' is distinct from 'not_allowed' then raise exception 'E35 FAILED: ajnabi session bana sakta hai %', v_r using errcode = 'AX053'; end if;
      v_r := public.migration_session_create(v_user, v_org, 'nobody@e35.test', 'gmail', 'imap.gmail.com', 'x@gmail.com');
      if v_r->>'error' is distinct from 'mailbox_not_found' then raise exception 'E35 FAILED: gair mailbox par session %', v_r using errcode = 'AX053'; end if;
      v_chk := v_chk + 2;

      v_r := public.migration_session_create(v_user, v_org, v_mb, 'gmail', 'imap.gmail.com', 'X@Gmail.com');
      if (v_r->>'ok')::boolean is not true or (v_r->>'token') !~ '^[0-9a-f]{64}$' then raise exception 'E35 FAILED: session nahi bana %', v_r using errcode = 'AX053'; end if;
      v_tok := v_r->>'token'; v_sid := (v_r->>'session_id')::uuid;
      select * into s from public.mig_sessions where id = v_sid;
      if s.token_hash is distinct from public._mig_sha(v_tok) or s.token_hash = v_tok or s.status <> 'created' or s.source_login <> 'X@Gmail.com' then
        raise exception 'E35 FAILED: token sirf hash ke taur par rakha jana chahiye' using errcode = 'AX053';
      end if;
      if exists (select 1 from public.mig_sessions m where m::text like '%' || v_tok || '%') then
        raise exception 'E35 FAILED: token plain text mein kahin maujood' using errcode = 'AX053';
      end if;
      v_r := public.migration_session_create(v_user, v_org, v_mb, 'gmail', 'imap.gmail.com', 'x@gmail.com');
      if v_r->>'error' is distinct from 'session_active' or (v_r->>'session_id')::uuid <> v_sid then raise exception 'E35 FAILED: doosra active session ban gaya %', v_r using errcode = 'AX053'; end if;
      v_chk := v_chk + 3;

      -- gate: verify se pehle koi likhna nahi
      v_r := public.migration_ingest(v_tok, '[]'::jsonb);
      if v_r->>'why' is distinct from 'not_verified' then raise exception 'E35 FAILED: verify se pehle gate khula %', v_r using errcode = 'AX053'; end if;
      v_r := public.migration_ingest(repeat('0', 64), '[]'::jsonb);
      if v_r->>'why' is distinct from 'invalid_token' then raise exception 'E35 FAILED: ghalat token chal gaya %', v_r using errcode = 'AX053'; end if;
      v_r := public.migration_ingest('not a token', '[]'::jsonb);
      if (v_r->>'ok')::boolean then raise exception 'E35 FAILED: kharab token chal gaya' using errcode = 'AX053'; end if;
      v_chk := v_chk + 3;

      v_r := public.migration_verify(v_tok);
      if (v_r->>'ok')::boolean is not true then raise exception 'E35 FAILED: verify %', v_r using errcode = 'AX053'; end if;

      -- ---- C. 7 item: root, reply, wohi subject, sent, dup-by-id, dup-by-raw, too_large, failed, id-conflict ----
      v_r := public.migration_ingest(v_tok, jsonb_build_array(
        jsonb_build_object('outcome','copy','folder','INBOX','app_folder','inbox','direction','in','uidvalidity',7,'uid',1,'raw_sha256',v_raw1,'raw_size',100,
          'sent_at','2026-10-10T10:00:00Z','seen',false,'message_id','root1@e35','from_name','Sara','from_address','Sara@Acme.com','to',jsonb_build_array(v_mb),
          'subject','Quote please','body_text','hello','attachments', jsonb_build_array(jsonb_build_object('filename','a.pdf','mime','application/pdf','size',5))),
        jsonb_build_object('outcome','copy','folder','INBOX','app_folder','inbox','direction','in','uidvalidity',7,'uid',2,'raw_sha256',v_raw2,'raw_size',50,
          'sent_at','2026-10-11T10:00:00Z','seen',true,'message_id','reply1@e35','in_reply_to','root1@e35','from_address','sara@acme.com','subject','Re: Quote please','body_text','thanks'),
        jsonb_build_object('outcome','copy','folder','[Gmail]/Sent Mail','app_folder','sent','direction','out','uidvalidity',9,'uid',1,'raw_sha256',v_raw3,'raw_size',60,
          'sent_at','2026-10-12T10:00:00Z','seen',true,'message_id','sent1@e35','from_address',v_mb,'to',jsonb_build_array('sara@acme.com'),'subject','Fwd: Different','body_text','out'),
        jsonb_build_object('outcome','copy','folder','Clients/ACME','app_folder','archive','direction','in','uidvalidity',3,'uid',5,'raw_sha256',v_raw1,'raw_size',100,
          'message_id','root1@e35','subject','Quote please','body_text','hello'),
        jsonb_build_object('outcome','too_large','folder','INBOX','uidvalidity',7,'uid',3,'raw_size',99999999,'reason','too_large'),
        jsonb_build_object('outcome','failed','folder','INBOX','uidvalidity',7,'uid',4,'reason','gone_on_server'),
        jsonb_build_object('outcome','copy','folder','INBOX','app_folder','inbox','direction','in','uidvalidity',7,'uid',6,'raw_sha256',v_raw4,'raw_size',70,
          'sent_at','2999-01-01T00:00:00Z','seen',true,'subject','Future','body_text','x'),
        jsonb_build_object('outcome','copy','folder','INBOX','uidvalidity',7,'uid',8,'raw_sha256','bad'),
        jsonb_build_object('outcome','copy','folder','INBOX','app_folder','inbox','uidvalidity',7,'uid',1,'raw_sha256',v_raw1)
      ));
      if (v_r->>'ok')::boolean is not true or (v_r->>'copied')::int <> 4 or (v_r->>'duplicate')::int <> 1 or (v_r->>'skipped')::int <> 1 or (v_r->>'failed')::int <> 1 then
        raise exception 'E35 FAILED: ingest ginti ghalat %', v_r using errcode = 'AX053';
      end if;
      v_chk := v_chk + 1;

      -- threading: root + reply ek thread (2 msg), sent alag thread (subject alag), future clamp
      select count(*) into v_n from public.mail_threads where lower(mailbox_address) = v_mb;
      if v_n <> 3 then raise exception 'E35 FAILED: thread ginti % (3 honi chahiye)', v_n using errcode = 'AX053'; end if;
      select count(*) into v_n from public.mail_threads t where lower(t.mailbox_address) = v_mb and t.subject = 'Quote please' and t.message_count = 2 and t.unread and t.has_attachments and t.folder = 'inbox';
      if v_n <> 1 then
        raise exception 'E35 FAILED: root+reply ek thread/unread/attachments nahi — asli rows: %',
          (select coalesce(jsonb_agg(jsonb_build_object('subject', t.subject, 'message_count', t.message_count, 'unread', t.unread,
                                                         'has_attachments', t.has_attachments, 'folder', t.folder::text)), '[]'::jsonb)
             from public.mail_threads t where lower(t.mailbox_address) = v_mb) using errcode = 'AX053';
      end if;
      select count(*) into v_n from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
       where lower(t.mailbox_address) = v_mb and m.mig_session_id = v_sid and m.direction = 'out' and t.folder = 'sent' and t.unread = false;
      if v_n <> 1 then raise exception 'E35 FAILED: sent mail direction/folder' using errcode = 'AX053'; end if;
      select count(*) into v_n from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
       where lower(t.mailbox_address) = v_mb and m.sent_at > now() + interval '1 hour';
      if v_n <> 0 then raise exception 'E35 FAILED: bhavishya ki tareekh clamp nahi hui' using errcode = 'AX053'; end if;
      select count(*) into v_n from public.mail_messages m where m.mig_session_id = v_sid and m.from_address = 'sara@acme.com';
      if v_n <> 2 then raise exception 'E35 FAILED: from_address lowercase nahi' using errcode = 'AX053'; end if;
      v_chk := v_chk + 4;

      -- dobara bhejna = kuch nahi badalta
      v_r := public.migration_ingest(v_tok, jsonb_build_array(
        jsonb_build_object('outcome','copy','folder','INBOX','app_folder','inbox','uidvalidity',7,'uid',1,'raw_sha256',v_raw1,'message_id','root1@e35','subject','Quote please')));
      if (v_r->>'copied')::int <> 0 or (v_r->>'duplicate')::int <> 0 then raise exception 'E35 FAILED: dobara bhejne par kuch ginta gaya %', v_r using errcode = 'AX053'; end if;
      select count(*) into v_n from public.mail_messages where mig_session_id = v_sid;
      if v_n <> 4 then raise exception 'E35 FAILED: mail_messages ginti % (4)', v_n using errcode = 'AX053'; end if;
      v_chk := v_chk + 2;

      -- Message-ID kisi AUR mailbox mein ho: mail phir bhi aati hai (message_id NULL ke saath)
      insert into public.mail_threads (org_id, mailbox_address, subject, folder, last_message_at) values (v_org, 'someone.else@e35.test', 'other', 'inbox', now()) returning id into v_msg;
      insert into public.mail_messages (org_id, thread_id, direction, message_id, from_address, subject) values (v_org, v_msg, 'in', 'shared1@e35', 'z@z.com', 'other');
      v_r := public.migration_ingest(v_tok, jsonb_build_array(
        jsonb_build_object('outcome','copy','folder','INBOX','app_folder','inbox','uidvalidity',7,'uid',10,'raw_sha256',public._mig_sha('raw-shared'),'message_id','shared1@e35','subject','shared','body_text','s')));
      if (v_r->>'copied')::int <> 1 then raise exception 'E35 FAILED: dusre mailbox ki Message-ID par mail ruk gayi %', v_r using errcode = 'AX053'; end if;
      select count(*) into v_n from public.mail_messages m where m.mig_session_id = v_sid and m.message_id is null;
      if v_n <> 2 then raise exception 'E35 FAILED: conflict wali mail NULL id ke saath nahi' using errcode = 'AX053'; end if;
      v_chk := v_chk + 2;

      -- resume ranges
      v_r := public.migration_done(v_tok, 'INBOX', 7);
      if v_r->>'ranges' is distinct from '1:4,6,10' then raise exception 'E35 FAILED: done ranges % (1:4,6,10)', v_r using errcode = 'AX053'; end if;
      v_r := public.migration_done(v_tok, 'INBOX', 8);
      if v_r->>'ranges' is distinct from '' then raise exception 'E35 FAILED: doosre uidvalidity ki ranges khali nahi' using errcode = 'AX053'; end if;
      v_chk := v_chk + 2;

      -- ---- D. chain ----
      v_r := public.migration_chain_verify(v_sid);
      if (v_r->>'ok')::boolean is not true or (v_r->>'entries')::int <> 8 then raise exception 'E35 FAILED: chain verify % (8 entries)', v_r using errcode = 'AX053'; end if;
      v_chk := v_chk + 1;
      v_hit := false;
      begin update public.mig_chain set raw_sha256 = repeat('0', 64) where session_id = v_sid and seq = 2;
      exception when sqlstate 'AX052' then v_hit := true; end;
      if not v_hit then raise exception 'E35 FAILED: chain entry badli ja saki' using errcode = 'AX053'; end if;
      v_hit := false;
      begin delete from public.mig_chain where session_id = v_sid and seq = 2;
      exception when sqlstate 'AX052' then v_hit := true; end;
      if not v_hit then raise exception 'E35 FAILED: chain entry hat saki' using errcode = 'AX053'; end if;
      -- trigger hata kar (superuser ki taqat) chhed-chhad karein: verify pakad leta hai
      alter table public.mig_chain disable trigger mig_chain_append_only;
      update public.mig_chain set raw_sha256 = repeat('0', 64) where session_id = v_sid and seq = 2;
      v_r := public.migration_chain_verify(v_sid);
      if (v_r->>'ok')::boolean or (v_r->>'broken_at')::int <> 2 or v_r->>'why' <> 'entry_hash_mismatch' then raise exception 'E35 FAILED: badli hui entry pakri nahi %', v_r using errcode = 'AX053'; end if;
      update public.mig_chain set raw_sha256 = v_raw2 where session_id = v_sid and seq = 2;
      delete from public.mig_chain where session_id = v_sid and seq = 3;
      v_r := public.migration_chain_verify(v_sid);
      if (v_r->>'ok')::boolean or v_r->>'why' <> 'sequence_gap' then raise exception 'E35 FAILED: hati hui entry pakri nahi %', v_r using errcode = 'AX053'; end if;
      alter table public.mig_chain enable trigger mig_chain_append_only;
      v_chk := v_chk + 4;
      -- chain wapas theek karne ke liye is session ko aage nahi chalate; naya session niche
      -- seal se pehle is session ko cancel: bigdi hui chain par seal bhi lagta hai (session band hona zaroori hai)
      v_r := public.migration_progress(v_tok, jsonb_build_object('folders_total', 3, 'folders_done', 1, 'folder', 'INBOX', 'found', 12));
      if (v_r->>'ok')::boolean is not true or (v_r->>'stop')::boolean then raise exception 'E35 FAILED: progress %', v_r using errcode = 'AX053'; end if;

      -- ---- E. cancel (worker zinda) -> stop = true -> finish ----
      v_r := public.migration_cancel(v_user, v_sid);
      if (v_r->>'requested')::boolean is not true then raise exception 'E35 FAILED: cancel request %', v_r using errcode = 'AX053'; end if;
      v_r := public.migration_progress(v_tok, '{}'::jsonb);
      if (v_r->>'stop')::boolean is not true then raise exception 'E35 FAILED: worker ko stop nahi mila %', v_r using errcode = 'AX053'; end if;
      v_r := public.migration_finish(v_tok, 'cancelled', 'cancelled_by_user');
      if (v_r->>'ok')::boolean is not true or (v_r->>'seal_hash') !~ '^[0-9a-f]{64}$' then raise exception 'E35 FAILED: finish %', v_r using errcode = 'AX053'; end if;
      select * into s from public.mig_sessions where id = v_sid;
      if not s.locked or s.status <> 'cancelled' or s.token_hash is not null then raise exception 'E35 FAILED: finish ke baad session lock nahi' using errcode = 'AX053'; end if;
      v_chk := v_chk + 4;

      -- ---- F. deewar: lock ke baad koi raasta nahi ----
      v_r := public.migration_ingest(v_tok, jsonb_build_array(jsonb_build_object('outcome','too_large','folder','INBOX','uidvalidity',7,'uid',77,'raw_size',1)));
      if (v_r->>'ok')::boolean then raise exception 'E35 FAILED: lock ke baad ingest chala' using errcode = 'AX053'; end if;
      v_hit := false;
      begin
        insert into public.mail_messages (org_id, thread_id, direction, from_address, mig_session_id)
        select v_org, id, 'in', 'x@x.com', v_sid from public.mail_threads where lower(mailbox_address) = v_mb limit 1;
      exception when sqlstate 'AX050' then v_hit := true; end;
      if not v_hit then raise exception 'E35 FAILED: locked session ke naam se seedhi row likhi ja saki' using errcode = 'AX053'; end if;
      v_hit := false;
      begin
        insert into public.mail_messages (org_id, thread_id, direction, from_address, mig_session_id)
        select v_org, id, 'in', 'x@x.com', gen_random_uuid() from public.mail_threads where lower(mailbox_address) = v_mb limit 1;
      exception when sqlstate 'AX050' then v_hit := true; end;
      if not v_hit then raise exception 'E35 FAILED: ajnabi session id se row likhi ja saki' using errcode = 'AX053'; end if;
      v_chk := v_chk + 3;

      -- naya session: gate khula bhi ho to bina set_config ke seedha insert nahi
      v_r := public.migration_session_create(v_user, v_org, v_mb2, 'outlook', 'outlook.office365.com', 'y@outlook.com');
      v_tok2 := v_r->>'token'; v_sid2 := (v_r->>'session_id')::uuid;
      perform public.migration_verify(v_tok2);
      v_hit := false;
      begin
        insert into public.mail_messages (org_id, thread_id, direction, from_address, mig_session_id)
        select v_org, id, 'in', 'x@x.com', v_sid2 from public.mail_threads where lower(mailbox_address) = v_mb limit 1;
      exception when sqlstate 'AX050' then v_hit := true; end;
      if not v_hit then raise exception 'E35 FAILED: gate khole baghair seedhi row likhi ja saki' using errcode = 'AX053'; end if;
      v_chk := v_chk + 1;

      -- resume: taza heartbeat wale (zinda worker) session par resume nahi
      v_r := public.migration_reopen(v_user, v_sid2);
      if v_r->>'error' is distinct from 'still_running' then raise exception 'E35 FAILED: zinda session par resume ho gaya %', v_r using errcode = 'AX053'; end if;
      -- release: worker ruka (network/restart) => token mar jata hai, session band NAHI hota, resume foran
      v_r := public.migration_release(v_tok2, 'connection_lost');
      if (v_r->>'ok')::boolean is not true then raise exception 'E35 FAILED: release % ', v_r using errcode = 'AX053'; end if;
      if (public.migration_ingest(v_tok2, '[]'::jsonb)->>'why') is distinct from 'invalid_token' then raise exception 'E35 FAILED: release ke baad purana token zinda' using errcode = 'AX053'; end if;
      select * into s from public.mig_sessions where id = v_sid2;
      if s.locked or s.status not in ('created', 'verified', 'running') or s.last_error is distinct from 'connection_lost' then
        raise exception 'E35 FAILED: release ne session bigaad diya %', s.status using errcode = 'AX053';
      end if;
      if (public._mig_summary(s)->>'stale')::boolean is not true then raise exception 'E35 FAILED: ruka hua session stale nahi dikha' using errcode = 'AX053'; end if;
      v_r := public.migration_reopen(v_user, v_sid2);
      if (v_r->>'ok')::boolean is not true or (v_r->>'token') !~ '^[0-9a-f]{64}$' or (v_r->>'token') = v_tok2 then
        raise exception 'E35 FAILED: naya token nahi mila %', v_r using errcode = 'AX053';
      end if;
      v_tok2 := v_r->>'token';
      perform public.migration_progress(v_tok2, '{}'::jsonb);
      v_r := public.migration_reopen(v_user, v_sid2);
      if v_r->>'error' is distinct from 'still_running' then raise exception 'E35 FAILED: chalte session par resume ho gaya %', v_r using errcode = 'AX053'; end if;
      -- token expire
      update public.mig_sessions set token_expires_at = now() - interval '1 minute' where id = v_sid2;
      if (public.migration_ingest(v_tok2, '[]'::jsonb)->>'why') is distinct from 'token_expired' then raise exception 'E35 FAILED: expired token chala' using errcode = 'AX053'; end if;
      v_chk := v_chk + 8;

      -- baasi (heartbeat purani) running session: user cancel kare to seedha band
      update public.mig_sessions set heartbeat_at = now() - interval '10 minutes' where id = v_sid2;
      v_r := public.migration_cancel(v_user, v_sid2);
      if (v_r->>'ok')::boolean is not true or v_r->>'requested' is not null then raise exception 'E35 FAILED: baasi session cancel %', v_r using errcode = 'AX053'; end if;
      select * into s from public.mig_sessions where id = v_sid2;
      if not s.locked or s.status <> 'cancelled' then raise exception 'E35 FAILED: baasi session band nahi hua' using errcode = 'AX053'; end if;
      v_r := public.migration_chain_verify(v_sid2);
      if (v_r->>'ok')::boolean is not true or (v_r->>'sealed')::boolean is not true then raise exception 'E35 FAILED: khali session ki seal chain %', v_r using errcode = 'AX053'; end if;
      v_chk := v_chk + 3;

      -- list/get/export: sirf apni (ya manager ki) — ajnabi ko kuch nahi
      v_r := public.migration_list(v_stranger, v_org);
      if jsonb_array_length(v_r->'sessions') <> 0 then raise exception 'E35 FAILED: ajnabi ko sessions dikhe' using errcode = 'AX053'; end if;
      if (public.migration_get(v_stranger, v_sid)->>'ok')::boolean or (public.migration_chain_export(v_stranger, v_sid)->>'ok')::boolean then
        raise exception 'E35 FAILED: ajnabi ne session/chain padh li' using errcode = 'AX053';
      end if;
      v_r := public.migration_chain_export(v_user, v_sid, 0, 3);
      if (v_r->>'ok')::boolean is not true or jsonb_array_length(v_r->'rows') <> 3 then raise exception 'E35 FAILED: export %', v_r using errcode = 'AX053'; end if;
      if v_r::text like '%token%' then raise exception 'E35 FAILED: export mein token ka zikr' using errcode = 'AX053'; end if;
      v_chk := v_chk + 4;

      -- ---- G. normal inbound raasta (mail_ingest) trigger ke baad bhi chalta hai ----
      if to_regprocedure('public.mail_ingest(jsonb)') is not null then
        begin
          v_r := public.mail_ingest(jsonb_build_object('envelope_from', 'a@b.com', 'envelope_to', v_mb, 'message_id', 'live-path-' || v_mb,
                   'from_address', 'a@b.com', 'to', jsonb_build_array(v_mb), 'subject', 'live path', 'body_text', 'hi', 'sent_at', now()::text, 'raw_size', 2, 'raw_sha256', 'x'));
          if (v_r->>'ok')::boolean is not true then v_note := v_note || ' mail_ingest ne ok nahi diya: ' || left(v_r::text, 120) || ';'; end if;
          v_chk := v_chk + 1;
        exception when others then
          v_note := v_note || ' mail_ingest test mein chali nahi (' || sqlerrm || ') — yeh line mujhe bhej dein;';
        end;
      end if;
    end if;

    -- ---- H. huqooq ----
    if has_function_privilege('anon', 'public.migration_ingest(text,jsonb)', 'execute')
       or has_function_privilege('authenticated', 'public.migration_ingest(text,jsonb)', 'execute')
       or has_function_privilege('authenticated', 'public.migration_session_create(uuid,uuid,text,text,text,text,boolean)', 'execute')
       or has_function_privilege('authenticated', 'public.migration_finish(text,text,text)', 'execute')
       or has_function_privilege('authenticated', 'public.migration_release(text,text)', 'execute')
       or has_function_privilege('authenticated', 'public._mig_chain_add(public.mig_sessions,text,text,bigint,bigint,text,text,uuid)', 'execute')
       or has_table_privilege('authenticated', 'public.mig_sessions', 'select')
       or has_table_privilege('anon', 'public.mig_chain', 'select')
       or has_table_privilege('authenticated', 'public.mig_items', 'insert') then
      raise exception 'E35 FAILED: browser ke roles ko migration ke huqooq mile hue hain' using errcode = 'AX053';
    end if;
    if not has_function_privilege('service_role', 'public.migration_ingest(text,jsonb)', 'execute') then
      raise exception 'E35 FAILED: service_role ko huqooq nahi' using errcode = 'AX053';
    end if;
    v_chk := v_chk + 2;

    raise exception 'rollback marker' using errcode = 'AX099';
  exception when sqlstate 'AX099' then
    null;
  end;

  perform set_config('anexo.e35_selftest',
    case when v_note = '' then format('PASSED (%s checks, sab rollback)', v_chk)
         else format('PASSED with notes (%s checks, sab rollback) — %s', v_chk, btrim(v_note)) end, false);
end $$;

-- ============================ jawab: ek row ===============================
select
  'E35 OK — schema lag gaya' as e35_result,
  current_setting('anexo.e35_selftest', true) as selftest,
  (select count(*) from pg_trigger where tgname = 'mail_messages_mig_gate_trg' and not tgisinternal) as walled_garden_trigger,
  (select count(*) from pg_trigger where tgname = 'mig_chain_append_only' and not tgisinternal) as chain_append_only_trigger,
  (to_regprocedure('public.mail_ingest(jsonb)') is not null) as live_inbound_untouched_and_present,
  (select count(*) from public.mig_sessions) as sessions_now;
