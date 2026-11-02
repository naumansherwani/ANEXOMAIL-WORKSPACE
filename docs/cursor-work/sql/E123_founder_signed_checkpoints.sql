-- E123 — G5b: SIGNED CHECKPOINTS (C2SP signed-note / tlog-checkpoint) for the founder audit ledger. Founder order 2 Nov 06:02 "advance codes aur new sql".
-- Why: a seal (E107) is a row in OUR database; whoever can write the database could rewrite it. A signed note puts the seal under an Ed25519 key that
--   lives OUTSIDE the database (a 0400 file on the server), in the format other tools already read (Go sumdb `note`, Sigsum, Trillian). The browser verifies it in the WASM kernel.
-- HONEST LIMIT: the key is on the same server. This proves "the audit-log key said so", not "an outside party saw it" — that is G5c (time anchors).
-- What this adds (all additive, idempotent; nothing is deleted or changed):
--   1) founder_audit_log_keys   : the audit-log PUBLIC keys. Exactly ONE active (partial unique index). Retired keys stay for ever (old notes must stay checkable). Only active->retired is allowed.
--   2) founder_audit_signed_checkpoints : append-only, one signed note per seal (seal checked by trigger (no FK: the E107 selftest truncates seals)). A trigger RECOMPUTES the body from the seal row
--      (origin, size = upto_seq, root as base64) and refuses a note whose body differs, whose key is retired/unknown, or whose key name is not the origin.
--      SQL cannot check Ed25519: the Rust door verifies the signature before it calls us, and the browser kernel verifies it again. SQL guarantees the BODY is the seal's.
--   3) doors (service_role only): founder_audit_log_key_register, founder_audit_signed_cp_add, founder_audit_signed_cp_pending, founder_audit_signed_cp_get, founder_audit_signed_pulse.
--   4) own selftest (rolls back).
--   ADVANCED (founder 06:24 "super advanced"): 5) ONE note judge (`_fm_signedcp_judge`) used by the insert trigger AND by the re-checker, so they can never disagree;
--   6) `founder_audit_signed_verify(n)` re-checks the last n signed notes against the LIVE ledger (re-derives the root from the audit rows, key window, shape);
--   7) signing-lag policy + level in the pulse (signer dead / key missing is a visible alarm, like the G4 sealer alarm); 8) key rotation chain (prev_id);
--   9) `founder_audit_log_vkey()` = the public key in the standard `name+hash+base64` verifier format (what Go's note.NewVerifier and Sigsum read), checked against the Go oracle;
--   10) `founder_audit_signed_cp_latest_note()` = the newest note as plain text, ready to publish as the log's checkpoint.
-- A signed note is NOT an audit entry (would create a new seal, which needs a new note, ...). The key registration IS audited ('audit.logkey').

-- 1) keys -----------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signedcp:ddl', 0));
  create table if not exists public.founder_audit_log_keys (
    id          bigint primary key check (id >= 1),
    name        text   not null check (name ~ '^[^[:space:]+[:cntrl:]]{3,200}$'),     -- C2SP: no spaces, no '+', no control characters; also the checkpoint ORIGIN
    pub_hex     text   not null unique check (pub_hex ~ '^[0-9a-f]{64}$'),
    key_id_hex  text   not null check (key_id_hex ~ '^[0-9a-f]{8}$'),                -- first 4 bytes of sha256(name 0x0A 0x01 pub), computed by Rust AND re-computed here
    status      text   not null default 'active' check (status in ('active', 'retired')),
    created_ms  bigint not null check (created_ms > 0),
    retired_ms  bigint,
    constraint founder_audit_log_keys_retired check ((status = 'retired') = (retired_ms is not null))
  );
  alter table public.founder_audit_log_keys add column if not exists prev_id bigint;   -- rotation chain: the key this one replaced (null for the first)
  create unique index if not exists founder_audit_log_keys_one_active on public.founder_audit_log_keys ((true)) where status = 'active';
  create unique index if not exists founder_audit_log_keys_name_id on public.founder_audit_log_keys (name, key_id_hex);
  alter table public.founder_audit_log_keys enable row level security;
  revoke all on public.founder_audit_log_keys from public, anon, authenticated;
  grant select, insert, update on public.founder_audit_log_keys to service_role;
  revoke delete, truncate, references, trigger on public.founder_audit_log_keys from service_role;
end $$;

create or replace function public._fm_logkey_guard() returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' or tg_op = 'TRUNCATE' then raise exception 'founder_audit_log_keys: keys are never deleted' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if not (old.status = 'active' and new.status = 'retired' and new.retired_ms is not null and new.retired_ms >= old.created_ms
            and new.id = old.id and new.prev_id is not distinct from old.prev_id and new.name = old.name and new.pub_hex = old.pub_hex and new.key_id_hex = old.key_id_hex and new.created_ms = old.created_ms) then
      raise exception 'founder_audit_log_keys: the only allowed change is active -> retired' using errcode = '42501';
    end if;
  end if;
  if tg_op = 'INSERT' then
    -- recompute the key id from name+pub: a wrong id would make every note unverifiable in other tools
    if new.key_id_hex <> substr(encode(extensions.digest(convert_to(new.name, 'UTF8') || '\x0a01'::bytea || decode(new.pub_hex, 'hex'), 'sha256'), 'hex'), 1, 8) then
      raise exception 'founder_audit_log_keys: key_id does not match sha256(name || 0x0A || 0x01 || pub)' using errcode = '22023';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists founder_audit_log_keys_guard on public.founder_audit_log_keys;
create trigger founder_audit_log_keys_guard before insert or update on public.founder_audit_log_keys for each row execute function public._fm_logkey_guard();
drop trigger if exists founder_audit_log_keys_guard_del on public.founder_audit_log_keys;
create trigger founder_audit_log_keys_guard_del before delete on public.founder_audit_log_keys for each row execute function public._fm_logkey_guard();
drop trigger if exists founder_audit_log_keys_guard_trunc on public.founder_audit_log_keys;
create trigger founder_audit_log_keys_guard_trunc before truncate on public.founder_audit_log_keys for each statement execute function public._fm_logkey_guard();

-- 2) signed checkpoints --------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signedcp:ddl', 0));
  create table if not exists public.founder_audit_signed_checkpoints (
    cp_id      bigint primary key check (cp_id >= 1),      -- no FK on purpose: E107's own selftest truncates the seals table, and a FK would break it; the guard trigger checks the seal exists
    key_id     bigint not null references public.founder_audit_log_keys (id),
    origin     text   not null,
    size       bigint not null check (size >= 1),
    root       text   not null check (root ~ '^[0-9a-f]{64}$'),
    note       text   not null check (length(note) between 100 and 4096),
    signed_ms  bigint not null check (signed_ms > 0)
  );
  alter table public.founder_audit_signed_checkpoints drop constraint if exists founder_audit_signed_checkpoints_cp_id_fkey;   -- re-run safe
  alter table public.founder_audit_signed_checkpoints enable row level security;
  revoke all on public.founder_audit_signed_checkpoints from public, anon, authenticated;
  grant select, insert on public.founder_audit_signed_checkpoints to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_audit_signed_checkpoints from service_role;
end $$;

-- ONE judge for "is this note exactly the signed checkpoint of this seal under this key?". Returns the problem in plain words, or null when it is fine.
-- Used by the insert trigger (refuse bad notes) AND by founder_audit_signed_verify (re-check what is stored). SQL cannot check Ed25519: Rust did before inserting, the kernel does in the browser.
create or replace function public._fm_signedcp_judge(p_note text, p_name text, p_key_id_hex text, p_size bigint, p_root text) returns text
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare v_body text; v_sig text; v_b64 text; v_raw bytea;
begin
  if p_note is null or length(p_note) > 4096 then return 'note missing or too long'; end if;
  if p_note ~ '[\x01-\x09\x0b-\x1f\x7f]' then return 'control character in the note'; end if;
  v_body := p_name || E'\n' || p_size::text || E'\n' || encode(decode(p_root, 'hex'), 'base64') || E'\n';
  if left(p_note, length(v_body) + 1) <> v_body || E'\n' then return 'the note body is not exactly the seal''s checkpoint body'; end if;
  v_sig := substr(p_note, length(v_body) + 2);
  if v_sig !~ (E'^— ' || replace(p_name, '.', '\.') || ' [A-Za-z0-9+/]{91}=\n$') then return 'the signature block is not exactly one line "— <key name> <base64 of 68 bytes>"'; end if;
  v_b64 := split_part(split_part(v_sig, ' ', 3), E'\n', 1);
  v_raw := decode(v_b64, 'base64');
  if length(v_raw) <> 68 then return 'the signature block is not 68 bytes (4 key id + 64 Ed25519)'; end if;
  if replace(encode(v_raw, 'base64'), E'\n', '') <> v_b64 then return 'the signature is not canonical base64'; end if;
  if substr(encode(v_raw, 'hex'), 1, 8) <> p_key_id_hex then return 'the signature carries another key id'; end if;
  return null;
end $$;

create or replace function public._fm_signedcp_guard() returns trigger language plpgsql as $$
declare v_cp public.founder_audit_checkpoints%rowtype; v_key public.founder_audit_log_keys%rowtype; v_bad text;
begin
  if tg_op <> 'INSERT' then raise exception 'founder_audit_signed_checkpoints is append-only (% blocked)', tg_op using errcode = '42501'; end if;
  select * into v_cp from public.founder_audit_checkpoints where id = new.cp_id;
  if not found then raise exception 'E123: no such seal' using errcode = '23503'; end if;
  select * into v_key from public.founder_audit_log_keys where id = new.key_id;
  if not found or v_key.status <> 'active' then raise exception 'E123: the signing key is unknown or retired' using errcode = '22023'; end if;
  if new.origin <> v_key.name or new.size <> v_cp.upto_seq or new.root <> v_cp.root then raise exception 'E123: origin/size/root differ from the seal' using errcode = '22023'; end if;
  v_bad := public._fm_signedcp_judge(new.note, v_key.name, v_key.key_id_hex, v_cp.upto_seq, v_cp.root);
  if v_bad is not null then raise exception 'E123: %', v_bad using errcode = '22023'; end if;
  return new;
end $$;
drop trigger if exists founder_audit_signed_cp_guard on public.founder_audit_signed_checkpoints;
create trigger founder_audit_signed_cp_guard before insert or update or delete on public.founder_audit_signed_checkpoints for each row execute function public._fm_signedcp_guard();
drop trigger if exists founder_audit_signed_cp_guard_trunc on public.founder_audit_signed_checkpoints;
create trigger founder_audit_signed_cp_guard_trunc before truncate on public.founder_audit_signed_checkpoints for each statement execute function public._fm_signedcp_guard();

-- 3) doors ----------------------------------------------------------------------------------------------------------------------
-- register (or rotate to) the audit-log public key. Same pub twice = no-op. A different pub retires the active key and activates the new one (audited).
create or replace function public.founder_audit_log_key_register(p_actor uuid, p_name text, p_pub_hex text, p_key_id_hex text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_act public.founder_audit_log_keys%rowtype; v_id bigint; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_rotated boolean := false;
begin
  if p_actor is null or not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E123: actor is not a founder' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_signedcp:key', 0));
  select * into v_act from public.founder_audit_log_keys where status = 'active';
  if found and v_act.pub_hex = p_pub_hex and v_act.name = p_name then
    return jsonb_build_object('registered', false, 'id', v_act.id, 'name', v_act.name, 'pub_hex', v_act.pub_hex, 'key_id_hex', v_act.key_id_hex, 'reason', 'already the active key');
  end if;
  if found then update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(v_ms, v_act.created_ms) where id = v_act.id; v_rotated := true; end if;
  select coalesce(max(id), 0) + 1 into v_id from public.founder_audit_log_keys;
  insert into public.founder_audit_log_keys (id, name, pub_hex, key_id_hex, status, created_ms, prev_id) values (v_id, p_name, p_pub_hex, p_key_id_hex, 'active', v_ms, case when v_rotated then v_act.id end);
  perform public.founder_audit_append(p_actor, 'audit.logkey', 'logkey:' || v_id, case when v_rotated then 'audit-log signing key rotated' else 'audit-log signing key registered' end,
                                      jsonb_build_object('id', v_id, 'name', p_name, 'pub_hex', p_pub_hex, 'key_id_hex', p_key_id_hex, 'rotated', v_rotated, 'prev_id', case when v_rotated then v_act.id end));
  return jsonb_build_object('registered', true, 'rotated', v_rotated, 'id', v_id, 'name', p_name, 'pub_hex', p_pub_hex, 'key_id_hex', p_key_id_hex);
end $$;

-- seals that still have no signed note (newest last), with exactly what Rust must sign
create or replace function public.founder_audit_signed_cp_pending(p_limit integer default 20)
returns jsonb language sql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
  select coalesce(jsonb_agg(jsonb_build_object('cp_id', c.id, 'size', c.upto_seq, 'root', c.root) order by c.id), '[]'::jsonb)
  from (select id, upto_seq, root from public.founder_audit_checkpoints cp
        where not exists (select 1 from public.founder_audit_signed_checkpoints s where s.cp_id = cp.id) order by id limit greatest(1, least(coalesce(p_limit, 20), 200))) c
$$;

create or replace function public.founder_audit_signed_cp_add(p_cp_id bigint, p_key_id bigint, p_note text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_cp public.founder_audit_checkpoints%rowtype; v_key public.founder_audit_log_keys%rowtype; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signedcp:add', 0));
  if exists (select 1 from public.founder_audit_signed_checkpoints where cp_id = p_cp_id) then return jsonb_build_object('added', false, 'reason', 'this seal already has a signed note'); end if;
  select * into v_cp from public.founder_audit_checkpoints where id = p_cp_id;
  if not found then raise exception 'E123: no such seal' using errcode = '23503'; end if;
  select * into v_key from public.founder_audit_log_keys where id = p_key_id;
  if not found then raise exception 'E123: no such key' using errcode = '23503'; end if;
  insert into public.founder_audit_signed_checkpoints (cp_id, key_id, origin, size, root, note, signed_ms) values (p_cp_id, p_key_id, v_key.name, v_cp.upto_seq, v_cp.root, p_note, v_ms);
  return jsonb_build_object('added', true, 'cp_id', p_cp_id, 'size', v_cp.upto_seq);
end $$;

-- the signed note for one seal (default: the newest signed one) + the public key it needs + every key ever (so an old note stays checkable)
create or replace function public.founder_audit_signed_cp_get(p_cp_id bigint default null)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare s public.founder_audit_signed_checkpoints%rowtype;
begin
  if p_cp_id is null then select * into s from public.founder_audit_signed_checkpoints order by cp_id desc limit 1;
  else select * into s from public.founder_audit_signed_checkpoints where cp_id = p_cp_id; end if;
  if not found then return jsonb_build_object('found', false, 'keys', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'pub_hex', pub_hex, 'key_id_hex', key_id_hex, 'status', status) order by id), '[]'::jsonb) from public.founder_audit_log_keys)); end if;
  return jsonb_build_object('found', true, 'cp_id', s.cp_id, 'size', s.size, 'root', s.root, 'origin', s.origin, 'note', s.note, 'signed_ms', s.signed_ms, 'key_id', s.key_id,
    'keys', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'pub_hex', pub_hex, 'key_id_hex', key_id_hex, 'status', status) order by id), '[]'::jsonb) from public.founder_audit_log_keys));
end $$;

-- 3b) signing-lag policy: how long a seal may stay without a signed note before the gauge warns / fails (singleton row, changed only by editing this file or an audited door later).
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_signedcp:ddl', 0));
  create table if not exists public.founder_audit_sign_policy (
    id boolean primary key default true check (id),
    warn_secs integer not null default 300,
    fail_secs integer not null default 1800,
    constraint founder_audit_sign_policy_order check (warn_secs between 60 and 86400 and fail_secs > warn_secs and fail_secs <= 604800)
  );
  insert into public.founder_audit_sign_policy (id) values (true) on conflict do nothing;
  alter table public.founder_audit_sign_policy enable row level security;
  revoke all on public.founder_audit_sign_policy from public, anon, authenticated;
  grant select on public.founder_audit_sign_policy to service_role;
end $$;

-- the pulse (replaces the first draft): + oldest unsigned age, level (ok | warn | fail | off), policy
create or replace function public.founder_audit_signed_pulse() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_pol public.founder_audit_sign_policy%rowtype; v_key public.founder_audit_log_keys%rowtype;
        v_unsigned bigint; v_oldest bigint; v_age bigint; v_level text := 'ok'; v_why text := 'every seal has a signed note';
begin
  select * into v_pol from public.founder_audit_sign_policy where id;
  select * into v_key from public.founder_audit_log_keys where status = 'active';
  select count(*), min(cp.created_ms) into v_unsigned, v_oldest from public.founder_audit_checkpoints cp where not exists (select 1 from public.founder_audit_signed_checkpoints s where s.cp_id = cp.id);
  v_age := case when v_oldest is null then 0 else greatest(0, (v_now - v_oldest) / 1000) end;
  if v_key.id is null then
    if v_unsigned > 0 then v_level := case when v_age >= v_pol.fail_secs then 'fail' when v_age >= v_pol.warn_secs then 'warn' else 'off' end; v_why := 'no audit-log key is registered yet'; else v_level := 'off'; v_why := 'no audit-log key registered and nothing to sign'; end if;
  elsif v_unsigned > 0 then
    if v_age >= v_pol.fail_secs then v_level := 'fail'; v_why := 'seals have waited for a signature past the fail limit';
    elsif v_age >= v_pol.warn_secs then v_level := 'warn'; v_why := 'seals are waiting for a signature'; end if;
  end if;
  return jsonb_build_object(
    'latest_seal', (select coalesce(max(id), 0) from public.founder_audit_checkpoints),
    'latest_signed', (select coalesce(max(cp_id), 0) from public.founder_audit_signed_checkpoints),
    'signed', (select count(*) from public.founder_audit_signed_checkpoints),
    'unsigned', v_unsigned, 'oldest_unsigned_age_s', v_age, 'level', v_level, 'why', v_why,
    'policy', jsonb_build_object('warn_secs', v_pol.warn_secs, 'fail_secs', v_pol.fail_secs),
    'active_key', case when v_key.id is null then null else jsonb_build_object('id', v_key.id, 'name', v_key.name, 'pub_hex', v_key.pub_hex, 'key_id_hex', v_key.key_id_hex, 'prev_id', v_key.prev_id) end,
    'keys', (select count(*) from public.founder_audit_log_keys), 'now_ms', v_now);
end $$;

-- re-check what is STORED against the LIVE ledger: the last n signed notes. For each: shape (same judge as the trigger), the key window, and the root RE-DERIVED from the audit rows.
-- (The Ed25519 signature itself is re-checked in the browser kernel; SQL cannot.) Returns {checked, ok, problems:[{cp_id, problem}]}.
create or replace function public.founder_audit_signed_verify(p_last integer default 5) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; v_bad text; v_probs jsonb := '[]'::jsonb; v_n integer := 0; v_root text;
begin
  for r in select s.*, k.name as k_name, k.key_id_hex, k.created_ms as k_created, k.retired_ms as k_retired, c.upto_seq as c_size, c.root as c_root
           from public.founder_audit_signed_checkpoints s join public.founder_audit_log_keys k on k.id = s.key_id join public.founder_audit_checkpoints c on c.id = s.cp_id
           order by s.cp_id desc limit greatest(1, least(coalesce(p_last, 5), 100)) loop
    v_n := v_n + 1;
    v_bad := public._fm_signedcp_judge(r.note, r.k_name, r.key_id_hex, r.c_size, r.c_root);
    if v_bad is null and (r.origin <> r.k_name or r.size <> r.c_size or r.root <> r.c_root) then v_bad := 'stored origin/size/root differ from the seal'; end if;
    if v_bad is null and (r.signed_ms < r.k_created or (r.k_retired is not null and r.signed_ms > r.k_retired)) then v_bad := 'signed outside the window in which its key was active'; end if;
    if v_bad is null then
      v_root := encode(public._fm_root_of(public._fm_leaves(r.c_size)), 'hex');
      if v_root <> r.c_root then v_bad := 'the audit rows no longer produce the signed root (the ledger was changed after signing)'; end if;
    end if;
    if v_bad is not null then v_probs := v_probs || jsonb_build_array(jsonb_build_object('cp_id', r.cp_id, 'problem', v_bad)); end if;
  end loop;
  return jsonb_build_object('checked', v_n, 'ok', jsonb_array_length(v_probs) = 0, 'problems', v_probs);
end $$;

-- the active public key in the standard verifier format `name+<8 hex key id>+base64(0x01 || pub)` (Go note.NewVerifier, Sigsum, Trillian read this); null when no key
create or replace function public.founder_audit_log_vkey() returns text
language sql stable security definer set search_path = pg_catalog, public, extensions as $$
  select name || '+' || key_id_hex || '+' || replace(encode('\x01'::bytea || decode(pub_hex, 'hex'), 'base64'), E'\n', '') from public.founder_audit_log_keys where status = 'active'
$$;

-- the newest signed note as plain text (exactly the bytes to publish as the log's latest checkpoint), null if none
create or replace function public.founder_audit_signed_cp_latest_note() returns text
language sql stable security definer set search_path = pg_catalog, public as $$
  select note from public.founder_audit_signed_checkpoints order by cp_id desc limit 1
$$;

-- 4) selftest ------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_audit_e123_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r text := ''; v_uid uuid; b_aud bigint; b_cp bigint; b_keys bigint; b_sig bigint; j jsonb; v_cp jsonb; v_pub text := repeat('ab', 32); v_pub2 text := repeat('cd', 32);
        v_name text := 'selftest.example/audit-log'; v_kid text; v_kid2 text; v_body text; v_sigline text; v_note text; v_raw text; v_kid_id bigint;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E123 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_aud from public.founder_audit; select count(*) into b_cp from public.founder_audit_checkpoints;
  select count(*) into b_keys from public.founder_audit_log_keys; select count(*) into b_sig from public.founder_audit_signed_checkpoints;
  begin
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    v_kid2 := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub2, 'hex'), 'sha256'), 'hex'), 1, 8);
    -- (the selftest retires any real active key inside this rolled-back block; nothing leaks)
    update public.founder_audit_log_keys set status = 'retired', retired_ms = created_ms where status = 'active';
    if not public._fs_fails(format($q$select public.founder_audit_log_key_register(%L, %L, %L, 'deadbeef')$q$, v_uid, v_name, v_pub)) then raise exception 'a wrong key id was accepted'; end if;
    j := public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    if not (j ->> 'registered')::boolean then raise exception 'registering failed: %', j; end if;
    j := public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    if (j ->> 'registered')::boolean then raise exception 'the same key registered twice: %', j; end if;
    r := r || 'key register + idempotent OK; ';
    if not public._fs_fails(format($q$insert into public.founder_audit_log_keys (id, name, pub_hex, key_id_hex, status, created_ms) values (900, %L, %L, %L, 'active', 1)$q$, v_name, v_pub2, v_kid2)) then raise exception 'a second active key was accepted'; end if;
    if not public._fs_fails($q$delete from public.founder_audit_log_keys$q$) or not public._fs_fails($q$update public.founder_audit_log_keys set pub_hex = repeat('ee', 32)$q$) then raise exception 'a key was changed or deleted'; end if;
    r := r || 'one-active + immutable OK; ';
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal for the signed note');
    v_cp := (public.founder_audit_signed_cp_pending(5)) -> -1;
    if v_cp is null then raise exception 'the new seal is not pending'; end if;
    v_body := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n';
    -- 68 raw bytes = 4 key id + 64 signature bytes; the signature value is fake (Ed25519 is checked by Rust + the kernel, not by SQL)
    v_raw := replace(encode(decode(v_kid, 'hex') || decode(repeat('11', 64), 'hex'), 'base64'), E'\n', '');   -- PG wraps base64 at 76 chars
    v_sigline := E'— ' || v_name || ' ' || v_raw || E'\n';
    v_note := v_body || E'\n' || v_sigline;
    if not public._fs_fails(format($q$select public.founder_audit_signed_cp_add(%s, 1000000, %L)$q$, (v_cp ->> 'cp_id'), v_note)) then raise exception 'unknown key id accepted'; end if;
    v_kid_id := (select id from public.founder_audit_log_keys where status = 'active');
    if not public._fs_fails(format($q$select public.founder_audit_signed_cp_add(%s, %s, %L)$q$, (v_cp ->> 'cp_id'), v_kid_id, replace(v_note, (v_cp ->> 'size') || E'\n', ((v_cp ->> 'size')::bigint + 1)::text || E'\n'))) then raise exception 'a note with another size was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_audit_signed_cp_add(%s, %s, %L)$q$, (v_cp ->> 'cp_id'), v_kid_id, v_body || E'\n' || E'— ' || v_name || ' AAAA' || E'\n')) then raise exception 'a short signature was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_audit_signed_cp_add(%s, %s, %L)$q$, (v_cp ->> 'cp_id'), v_kid_id, v_body || E'\n' || replace(v_sigline, v_name, 'other.example/x'))) then raise exception 'a note signed under another name was accepted'; end if;
      j := public.founder_audit_signed_cp_add((v_cp ->> 'cp_id')::bigint, v_kid_id, v_note);
      if not (j ->> 'added')::boolean then raise exception 'a correct note was refused: %', j; end if;
      j := public.founder_audit_signed_cp_add((v_cp ->> 'cp_id')::bigint, v_kid_id, v_note);
      if (j ->> 'added')::boolean then raise exception 'the same seal was signed twice'; end if;
    r := r || 'body-derived-from-seal + strict signature line OK; ';
    if not public._fs_fails($q$update public.founder_audit_signed_checkpoints set note = note$q$) or not public._fs_fails($q$delete from public.founder_audit_signed_checkpoints$q$) or not public._fs_fails($q$truncate public.founder_audit_signed_checkpoints$q$) then
      raise exception 'a signed note was changed or deleted'; end if;
    r := r || 'append-only OK; ';
    j := public.founder_audit_signed_cp_get((v_cp ->> 'cp_id')::bigint);
    if not (j ->> 'found')::boolean or j ->> 'note' <> v_note or jsonb_array_length(j -> 'keys') < 1 then raise exception 'get returned the wrong note: %', j; end if;
    j := public.founder_audit_signed_pulse();
    if (j -> 'active_key' ->> 'name') <> v_name or (j ->> 'latest_signed')::bigint <> (v_cp ->> 'cp_id')::bigint then raise exception 'pulse is wrong: %', j; end if;
    r := r || 'get + pulse OK; ';
    -- ADVANCED checks: judge, verify, vkey (against Go's own output), pulse levels, latest note
    if public._fm_signedcp_judge(v_note, v_name, v_kid, (v_cp ->> 'size')::bigint, v_cp ->> 'root') is not null then raise exception 'the judge refused a correct note'; end if;
    if public._fm_signedcp_judge(v_note || 'x', v_name, v_kid, (v_cp ->> 'size')::bigint, v_cp ->> 'root') is null then raise exception 'the judge accepted trailing bytes'; end if;
    if public._fm_signedcp_judge(replace(v_note, E'\n—', E'\n\n—'), v_name, v_kid, (v_cp ->> 'size')::bigint, v_cp ->> 'root') is null then raise exception 'the judge accepted an extra blank line'; end if;
    if public._fm_signedcp_judge(v_note || v_sigline, v_name, v_kid, (v_cp ->> 'size')::bigint, v_cp ->> 'root') is null then raise exception 'the judge accepted two signature lines'; end if;
    if public._fm_signedcp_judge(replace(v_note, v_name, v_name || chr(9)), v_name, v_kid, (v_cp ->> 'size')::bigint, v_cp ->> 'root') is null then raise exception 'the judge accepted a tab'; end if;
    if public._fm_signedcp_judge(v_note, v_name, 'ffffffff', (v_cp ->> 'size')::bigint, v_cp ->> 'root') is null then raise exception 'the judge accepted another key id'; end if;
    if public._fm_signedcp_judge(v_note, v_name, v_kid, (v_cp ->> 'size')::bigint + 1, v_cp ->> 'root') is null then raise exception 'the judge accepted another size'; end if;
    j := public.founder_audit_signed_verify(5);
    if not (j ->> 'ok')::boolean or (j ->> 'checked')::int < 1 then raise exception 'verify failed on a good ledger: %', j; end if;
    -- the vkey formula equals the one Go's note.NewVerifier-compatible output has for the published vector key 0 (Go: NewEd25519VerifierKey, committed in g5b_vectors.json)
    if 'founderworkspace.anexomail.com/audit-log' || '+' || 'b2e17a58' || '+' || replace(encode('\x01'::bytea || decode('a2622df8bfb35ab556cfb2993bc03585b34484ec894dab29926312c149b8a783', 'hex'), 'base64'), E'\n', '')
       <> 'founderworkspace.anexomail.com/audit-log+b2e17a58+AaJiLfi/s1q1Vs+ymTvANYWzRITsiU2rKZJjEsFJuKeD' then raise exception 'the vkey format differs from Go'; end if;
    if public.founder_audit_log_vkey() <> v_name || '+' || v_kid || '+' || replace(encode('\x01'::bytea || decode(v_pub, 'hex'), 'base64'), E'\n', '') then raise exception 'founder_audit_log_vkey is wrong'; end if;
    if public.founder_audit_signed_cp_latest_note() <> v_note then raise exception 'latest note is wrong'; end if;
    -- pulse levels: a fresh seal is "ok"/pending, an old unsigned seal warns then fails (clock moved by editing the seal time inside this rolled-back block is not possible: seals are immutable, so the policy is tightened instead)
    perform public.founder_audit_append(v_uid, 'e123.selftest', 'row-1', 'selftest entry for a second seal', '{}'::jsonb);
    perform public.founder_audit_checkpoint(v_uid, 'selftest second seal left unsigned');
    j := public.founder_audit_signed_pulse();
    if (j ->> 'unsigned')::int < 1 or j ->> 'level' <> 'ok' then raise exception 'a fresh unsigned seal must be ok/pending: %', j; end if;
    perform pg_sleep(1.2);   -- policy minimum is 60 s, so test the levels by lowering the limits through the table (rolled back)
    alter table public.founder_audit_sign_policy drop constraint founder_audit_sign_policy_order;
    update public.founder_audit_sign_policy set warn_secs = 0, fail_secs = 1;
    j := public.founder_audit_signed_pulse();
    if j ->> 'level' <> 'fail' then raise exception 'an unsigned seal past the fail limit must be fail: %', j; end if;
    update public.founder_audit_sign_policy set warn_secs = 0, fail_secs = 100000;
    j := public.founder_audit_signed_pulse();
    if j ->> 'level' <> 'warn' then raise exception 'an unsigned seal past the warn limit must be warn: %', j; end if;
    r := r || 'judge + verify + vkey(Go) + latest-note + pulse levels OK; ';
    -- rotation: a different key retires the first one, and the first one's note stays readable
    j := public.founder_audit_log_key_register(v_uid, v_name, v_pub2, v_kid2);
    if not (j ->> 'rotated')::boolean or (select count(*) from public.founder_audit_log_keys where status = 'active') <> 1 or (select status from public.founder_audit_log_keys where key_id_hex = v_kid and name = v_name) <> 'retired' then raise exception 'rotation failed: %', j; end if;
    if (select prev_id from public.founder_audit_log_keys where status = 'active') is distinct from (select id from public.founder_audit_log_keys where key_id_hex = v_kid and name = v_name and status = 'retired') then raise exception 'the rotation chain (prev_id) is not linked'; end if;
    if public.founder_audit_signed_cp_get((v_cp ->> 'cp_id')::bigint) ->> 'note' <> v_note then raise exception 'rotation lost the old note'; end if;
    r := r || 'rotation OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E123 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_audit_checkpoints) <> b_cp
     or (select count(*) from public.founder_audit_log_keys) <> b_keys or (select count(*) from public.founder_audit_signed_checkpoints) <> b_sig then raise exception 'E123 selftest left rows behind'; end if;
  return 'E123 selftest OK — ' || r || 'rollback clean';
end $$;

do $$ declare f text; begin
  foreach f in array array['public._fm_logkey_guard()', 'public._fm_signedcp_guard()', 'public.founder_audit_log_key_register(uuid,text,text,text)', 'public.founder_audit_signed_cp_pending(integer)',
    'public.founder_audit_signed_cp_add(bigint,bigint,text)', 'public.founder_audit_signed_cp_get(bigint)', 'public.founder_audit_signed_pulse()', 'public._fm_signedcp_judge(text,text,text,bigint,text)', 'public.founder_audit_signed_verify(integer)', 'public.founder_audit_log_vkey()', 'public.founder_audit_signed_cp_latest_note()', 'public.founder_audit_e123_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

do $$ begin raise notice '%', public.founder_audit_e123_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E123_founder_signed_checkpoints CHECK_E123  (after fetch). Needs E107 + E120 + E122.
-- Undo (safe: nothing else depends on it): drop table public.founder_audit_signed_checkpoints; drop table public.founder_audit_log_keys; drop the E123 functions. Audit rows 'audit.logkey' stay (the ledger never forgets).
