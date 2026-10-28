-- E104 — FOUNDER DEVICE APPROVAL (F1a-1): ek hi atomic darwaza `founder_device_exchange`, approve/revoke/list RPC, har badlav founder_audit mein.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPC (service_role only), E102 `founder_devices` + `founder_audit_append` par.
--   1) Preflight     — E102 (founder_devices, founder_audit_append, founder_accounts) maujood na ho to saaf SKIP. Advisory lock.
--   2) Column        — `pending_code` = UPPER(left(ua_hash, 8)) (generated, stored): server par approve karte waqt device ko pehchanne ka chhota code.
--                      `ua_hash` = sha256(browser ki device_id) — raw device_id DB mein kabhi nahi.
--   3) exchange      — founder_device_exchange(uid, device_hash, label): naya device => pending; AGAR is founder ka koi approved device NAHI to
--                      pehla device khud approve (trust-on-first-use, lock-out se bachao) + audit; approved => last_seen; revoked => refuse.
--   4) approve/revoke— code se; revoke aakhri approved device ko nahi hata sakta (lock-out guard); dono audit mein (wajah >= 8 akshar).
--   5) list          — founder_device_list(uid): sirf metadata (label, code, state, waqt).
--   6) check         — founder_device_ok(uid, device_id): har request par device ab bhi approved hai? (revoke foran asar)
--   7) selftest      — sab raaste try, aakhir mein poora rollback.
-- PRIVACY: device ka sirf hash + label (<=80, printable). IP/network kabhi nahi. Polar :3400 NO-TOUCH. Dobara chalana safe.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = public, extensions;

do $$
begin
  if to_regclass('public.founder_devices') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise notice 'E104 SKIP: E102 (founder_devices / founder_audit_append) pehle chalayein';
    return;
  end if;
  perform pg_advisory_xact_lock(hashtext('founder_device_approval'));

  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_devices' and column_name = 'pending_code') then
    alter table public.founder_devices add column pending_code text generated always as (upper(left(ua_hash, 8))) stored;
  end if;
  create index if not exists founder_devices_code_idx on public.founder_devices (pending_code);
  if not exists (select 1 from pg_constraint where conname = 'founder_devices_label_printable' and conrelid = 'public.founder_devices'::regclass) then
    alter table public.founder_devices add constraint founder_devices_label_printable check (label ~ '^[ -~]{1,80}$') not valid;
    alter table public.founder_devices validate constraint founder_devices_label_printable;
  end if;
end $$;

-- 3) exchange
create or replace function public.founder_device_exchange(p_uid uuid, p_device_hash text, p_label text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare d public.founder_devices%rowtype; v_label text; v_has_approved boolean;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' then raise exception 'device hash ghalat'; end if;
  v_label := left(regexp_replace(coalesce(nullif(btrim(p_label), ''), 'Browser'), '[^ -~]', '', 'g'), 80);
  if length(v_label) < 1 then v_label := 'Browser'; end if;
  perform pg_advisory_xact_lock(hashtext('founder_device_approval'));
  select * into d from public.founder_devices where user_id = p_uid and ua_hash = p_device_hash;
  if found then
    if d.revoked_at is not null then return jsonb_build_object('state', 'revoked', 'code', d.pending_code); end if;
    if d.approved_at is not null then
      update public.founder_devices set last_seen_at = now() where id = d.id;
      return jsonb_build_object('state', 'approved', 'device_id', d.id, 'label', d.label);
    end if;
    return jsonb_build_object('state', 'pending', 'code', d.pending_code);
  end if;
  select exists (select 1 from public.founder_devices where user_id = p_uid and approved_at is not null and revoked_at is null) into v_has_approved;
  if not v_has_approved then
    insert into public.founder_devices (user_id, label, ua_hash, approved_at, last_seen_at) values (p_uid, v_label, p_device_hash, now(), now()) returning * into d;
    perform public.founder_audit_append(p_uid, 'founder.device.first_approved', d.id::text, 'first device trusted on first use (no approved device existed)', jsonb_build_object('label', v_label, 'code', d.pending_code));
    return jsonb_build_object('state', 'approved', 'device_id', d.id, 'label', d.label, 'first', true);
  end if;
  insert into public.founder_devices (user_id, label, ua_hash) values (p_uid, v_label, p_device_hash) returning * into d;
  perform public.founder_audit_append(p_uid, 'founder.device.pending', d.id::text, 'new device asked for approval, waiting for founder', jsonb_build_object('label', v_label, 'code', d.pending_code));
  return jsonb_build_object('state', 'pending', 'code', d.pending_code);
end $$;
revoke all on function public.founder_device_exchange(uuid, text, text) from public, anon, authenticated;
grant execute on function public.founder_device_exchange(uuid, text, text) to service_role;

-- 4) approve / revoke (code se; server par founder khud)
create or replace function public.founder_device_approve(p_uid uuid, p_code text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare d public.founder_devices%rowtype; n int;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_code is null or p_code !~ '^[0-9A-F]{8}$' then raise exception 'code 8 hex akshar ka hona chahiye'; end if;
  perform pg_advisory_xact_lock(hashtext('founder_device_approval'));
  select count(*) into n from public.founder_devices where user_id = p_uid and pending_code = p_code and approved_at is null and revoked_at is null;
  if n = 0 then raise exception 'is code ka koi pending device nahi'; end if;
  if n > 1 then raise exception 'code ek se zyada device par (n=%): pura hash use karein', n; end if;
  update public.founder_devices set approved_at = now(), last_seen_at = now() where user_id = p_uid and pending_code = p_code and approved_at is null and revoked_at is null returning * into d;
  perform public.founder_audit_append(p_uid, 'founder.device.approved', d.id::text, p_reason, jsonb_build_object('label', d.label, 'code', d.pending_code));
  return jsonb_build_object('state', 'approved', 'device_id', d.id, 'label', d.label);
end $$;
revoke all on function public.founder_device_approve(uuid, text, text) from public, anon, authenticated;
grant execute on function public.founder_device_approve(uuid, text, text) to service_role;

create or replace function public.founder_device_revoke(p_uid uuid, p_code text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare d public.founder_devices%rowtype; n int; left_ok int;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_code is null or p_code !~ '^[0-9A-F]{8}$' then raise exception 'code 8 hex akshar ka hona chahiye'; end if;
  perform pg_advisory_xact_lock(hashtext('founder_device_approval'));
  select count(*) into n from public.founder_devices where user_id = p_uid and pending_code = p_code and revoked_at is null;
  if n = 0 then raise exception 'is code ka koi device nahi (ya pehle se revoked)'; end if;
  if n > 1 then raise exception 'code ek se zyada device par (n=%): pura hash use karein', n; end if;
  select * into d from public.founder_devices where user_id = p_uid and pending_code = p_code and revoked_at is null;
  select count(*) into left_ok from public.founder_devices where user_id = p_uid and approved_at is not null and revoked_at is null and id <> d.id;
  if d.approved_at is not null and left_ok = 0 then raise exception 'aakhri approved device revoke nahi ho sakta (lock-out se bachao)'; end if;
  update public.founder_devices set revoked_at = now() where id = d.id;
  perform public.founder_audit_append(p_uid, 'founder.device.revoked', d.id::text, p_reason, jsonb_build_object('label', d.label, 'code', d.pending_code));
  return jsonb_build_object('state', 'revoked', 'device_id', d.id);
end $$;
revoke all on function public.founder_device_revoke(uuid, text, text) from public, anon, authenticated;
grant execute on function public.founder_device_revoke(uuid, text, text) to service_role;

-- 5) list
create or replace function public.founder_device_list(p_uid uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('code', pending_code, 'label', label,
         'state', case when revoked_at is not null then 'revoked' when approved_at is not null then 'approved' else 'pending' end,
         'created_at', created_at, 'last_seen_at', last_seen_at) order by created_at), '[]'::jsonb)
  from public.founder_devices where user_id = p_uid
$$;
revoke all on function public.founder_device_list(uuid) from public, anon, authenticated;
grant execute on function public.founder_device_list(uuid) to service_role;

-- 6) har request par: device ab bhi approved?
create or replace function public.founder_device_ok(p_uid uuid, p_device uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.founder_devices where id = p_device and user_id = p_uid and approved_at is not null and revoked_at is null)
$$;
revoke all on function public.founder_device_ok(uuid, uuid) from public, anon, authenticated;
grant execute on function public.founder_device_ok(uuid, uuid) to service_role;

-- 7) selftest
create or replace function public.founder_devices_selftest() returns text language plpgsql security definer set search_path = public, extensions as $$
declare v_uid uuid; r text := ''; v_before bigint; v_audit_before bigint; res jsonb; h1 text := encode(digest('selftest-device-1', 'sha256'), 'hex'); h2 text := encode(digest('selftest-device-2', 'sha256'), 'hex'); v_ok boolean; c2 text;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E104 selftest SKIP — founder_accounts khali'; end if;
  select count(*) into v_before from public.founder_devices; select count(*) into v_audit_before from public.founder_audit;
  begin
    -- is selftest ke liye maujooda approved devices ko alag dikhane ke bajaye: naya founder-bina-device haalat chahiye; isliye sirf behaviour jo hamesha sach hai:
    delete from public.founder_devices where user_id = v_uid;  -- rollback mein wapas aayega
    res := public.founder_device_exchange(v_uid, h1, 'Selftest Laptop');
    if res ->> 'state' <> 'approved' or (res ->> 'first')::boolean is not true then raise exception 'pehla device auto-approve nahi hua: %', res; end if;
    r := r || 'pehla device TOFU approve OK; ';
    res := public.founder_device_exchange(v_uid, h2, 'Selftest Phone');
    if res ->> 'state' <> 'pending' then raise exception 'doosra device pending nahi: %', res; end if;
    c2 := res ->> 'code';
    r := r || 'doosra device pending OK; ';
    if public.founder_device_ok(v_uid, (select id from public.founder_devices where ua_hash = h2)) then raise exception 'pending device ok nikla'; end if;
    v_ok := false; begin perform public.founder_device_approve(v_uid, c2, 'chhota'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'chhoti wajah se approve ho gaya'; end if;
    res := public.founder_device_approve(v_uid, c2, 'approved from server selftest');
    if res ->> 'state' <> 'approved' then raise exception 'approve fail %', res; end if;
    if not public.founder_device_ok(v_uid, (select id from public.founder_devices where ua_hash = h2)) then raise exception 'approved device ok nahi'; end if;
    r := r || 'approve OK; ';
    res := public.founder_device_revoke(v_uid, c2, 'revoked from server selftest');
    if public.founder_device_ok(v_uid, (select id from public.founder_devices where ua_hash = h2)) then raise exception 'revoked device ab bhi ok'; end if;
    if public.founder_device_exchange(v_uid, h2, 'x') ->> 'state' <> 'revoked' then raise exception 'revoked exchange refuse nahi'; end if;
    r := r || 'revoke foran asar OK; ';
    v_ok := false; begin perform public.founder_device_revoke(v_uid, upper(left(h1, 8)), 'aakhri device hatane ki koshish'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'aakhri approved device revoke ho gaya (lock-out!)'; end if;
    r := r || 'aakhri device guard OK; ';
    v_ok := false; begin perform public.founder_device_exchange(gen_random_uuid(), h1, 'x'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'gair-founder ko exchange mila'; end if;
    v_ok := false; begin perform public.founder_device_exchange(v_uid, 'zzz', 'x'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'ghalat hash qubool'; end if;
    r := r || 'non-founder + bad hash band OK; ';
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain toot gayi'; end if;
    r := r || 'audit chain saaf OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E104 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_devices) <> v_before or (select count(*) from public.founder_audit) <> v_audit_before then raise exception 'E104 selftest ne saaf nahi kiya'; end if;
  return 'E104 selftest OK — ' || r || 'rollback saaf';
end $$;
revoke all on function public.founder_devices_selftest() from public, anon, authenticated;
grant execute on function public.founder_devices_selftest() to service_role;

do $$ begin
  raise notice '%', public.founder_devices_selftest();
end $$;
