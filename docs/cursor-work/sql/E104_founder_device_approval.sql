-- E104 — FOUNDER DEVICE APPROVAL (F1a-1), 10/10 hardened: ek hi atomic darwaza `founder_device_exchange`, approve/revoke/list RPC, har badlav founder_audit mein.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPC (service_role only, search_path pinned), E102 `founder_devices` + `founder_audit_append` par.
--   1) Preflight     — E102 maujood na ho to saaf SKIP. Lock har founder ka apna (hashtextextended 64-bit), poore server ka nahi.
--   2) Schema        — `pending_code` = UPPER(left(ua_hash, 8)) (generated, stored), index (user_id, pending_code) + partial "active approved" index,
--                      CHECK: label printable <=80, revoked_at >= created_at, approved_at >= created_at.
--   3) Immutability  — trigger: id/user_id/ua_hash/created_at kabhi nahi badalte; approved_at ek baar lag gaya to wahi rahega; revoked_at ek baar
--                      lag gaya to wapas NULL nahi (revoke ek-tarfa darwaza). SQL editor se bhi tamper nahi.
--   4) exchange      — founder_device_exchange(uid, device_hash, label): naya device => pending (max 5 pending, 7 din baad khud saaf);
--                      AGAR koi approved device nahi to pehla device khud approve (trust-on-first-use, lock-out se bachao) + audit;
--                      approved => last_seen (60s se kam mein dobara write nahi); revoked => refuse; limit => state 'limit'.
--   5) approve/revoke— code (8 hex) YA hash ka prefix (8..64 hex, ambiguity ka ilaaj); revoke aakhri approved device ko nahi hata sakta;
--                      dono audit mein (wajah >= 8 akshar). revoke terminal hai (wohi browser dobara pending ban ke naya device banta hai).
--   6) list / ok     — list: sirf metadata (label, code, state, waqt, pending expiry). ok: har request par device ab bhi approved?
--   7) selftest      — har raasta + cap + prefix + immutability + expiry + audit chain, aakhir mein poora rollback.
-- PRIVACY: device ka sirf SHA-256 hash + label (<=80, printable). IP/network kabhi nahi. Polar :3400 NO-TOUCH. Dobara chalana safe (idempotent).

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

-- 1) + 2) preflight, schema
do $$
begin
  if to_regclass('public.founder_devices') is null or to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then
    raise notice 'E104 SKIP: E102 (founder_devices / founder_audit_append) pehle chalayein';
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_device_approval:ddl', 0));

  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_devices' and column_name = 'pending_code') then
    alter table public.founder_devices add column pending_code text generated always as (upper(left(ua_hash, 8))) stored;
  end if;
  create index if not exists founder_devices_code_idx on public.founder_devices (user_id, pending_code);
  create index if not exists founder_devices_active_idx on public.founder_devices (user_id) where approved_at is not null and revoked_at is null;
  create index if not exists founder_devices_pending_idx on public.founder_devices (user_id, created_at) where approved_at is null and revoked_at is null;

  if not exists (select 1 from pg_constraint where conname = 'founder_devices_label_printable' and conrelid = 'public.founder_devices'::regclass) then
    alter table public.founder_devices add constraint founder_devices_label_printable check (label ~ '^[ -~]{1,80}$') not valid;
    alter table public.founder_devices validate constraint founder_devices_label_printable;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_devices_time_order' and conrelid = 'public.founder_devices'::regclass) then
    alter table public.founder_devices add constraint founder_devices_time_order
      check ((approved_at is null or approved_at >= created_at) and (revoked_at is null or revoked_at >= created_at)) not valid;
    alter table public.founder_devices validate constraint founder_devices_time_order;
  end if;
end $$;

comment on column public.founder_devices.pending_code is 'E104: UPPER(first 8 hex of ua_hash). Server-side approval code shown on the pending screen. Not a secret.';
comment on column public.founder_devices.ua_hash is 'SHA-256 of the browser device id. The raw id never reaches the database.';

-- 3) immutability guard
create or replace function public._founder_devices_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if new.id is distinct from old.id or new.user_id is distinct from old.user_id or new.ua_hash is distinct from old.ua_hash or new.created_at is distinct from old.created_at then
    raise exception 'founder_devices: id/user_id/ua_hash/created_at badle nahi jaate' using errcode = '42501';
  end if;
  if old.approved_at is not null and new.approved_at is distinct from old.approved_at then
    raise exception 'founder_devices: approved_at ek baar lag gaya to badalta nahi' using errcode = '42501';
  end if;
  if old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at then
    raise exception 'founder_devices: revoke wapas nahi hota' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public._founder_devices_guard() from public, anon, authenticated;
do $$ begin
  if to_regclass('public.founder_devices') is not null and not exists (select 1 from pg_trigger where tgname = 'founder_devices_guard' and tgrelid = 'public.founder_devices'::regclass) then
    create trigger founder_devices_guard before update on public.founder_devices for each row execute function public._founder_devices_guard();
  end if;
end $$;

-- helper: code ya hash-prefix se EK device. Na mila / ek se zyada => saaf error.
create or replace function public._founder_device_pick(p_uid uuid, p_code text, p_pending_only boolean)
returns public.founder_devices language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare c text := lower(btrim(coalesce(p_code, ''))); d public.founder_devices%rowtype; n int;
begin
  if c !~ '^[0-9a-f]{8,64}$' then raise exception 'code 8 se 64 hex akshar ka hona chahiye'; end if;
  select count(*) into n from public.founder_devices
   where user_id = p_uid and ua_hash like c || '%' and revoked_at is null and (not p_pending_only or approved_at is null);
  if n = 0 then raise exception 'is code ka koi % device nahi', case when p_pending_only then 'pending' else 'chalu' end; end if;
  if n > 1 then raise exception 'code % device par aata hai: lamba prefix (hash ke zyada akshar) dein', n; end if;
  select * into d from public.founder_devices
   where user_id = p_uid and ua_hash like c || '%' and revoked_at is null and (not p_pending_only or approved_at is null);
  return d;
end $$;
revoke all on function public._founder_device_pick(uuid, text, boolean) from public, anon, authenticated;

-- 4) exchange
create or replace function public.founder_device_exchange(p_uid uuid, p_device_hash text, p_label text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare d public.founder_devices%rowtype; v_label text; v_has_approved boolean; v_pending int; v_pruned int;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' then raise exception 'device hash ghalat'; end if;
  v_label := left(regexp_replace(coalesce(nullif(btrim(p_label), ''), 'Browser'), '[^ -~]', '', 'g'), 80);
  if length(btrim(v_label)) < 1 then v_label := 'Browser'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_device_approval:' || p_uid::text, 0));

  select * into d from public.founder_devices where user_id = p_uid and ua_hash = p_device_hash;
  if found then
    if d.revoked_at is not null then return jsonb_build_object('state', 'revoked', 'code', d.pending_code); end if;
    if d.approved_at is not null then
      if d.last_seen_at is null or d.last_seen_at < now() - interval '60 seconds' then
        update public.founder_devices set last_seen_at = now() where id = d.id;
      end if;
      return jsonb_build_object('state', 'approved', 'device_id', d.id, 'label', d.label);
    end if;
    return jsonb_build_object('state', 'pending', 'code', d.pending_code, 'expires_at', d.created_at + interval '7 days');
  end if;

  -- naya device: purane pending (7 din) khud saaf, phir cap
  with gone as (delete from public.founder_devices where user_id = p_uid and approved_at is null and revoked_at is null and created_at < now() - interval '7 days' returning 1)
  select count(*) into v_pruned from gone;
  if v_pruned > 0 then
    perform public.founder_audit_append(p_uid, 'founder.device.pending_expired', 'devices', 'unapproved device requests older than 7 days removed', jsonb_build_object('removed', v_pruned));
  end if;

  select exists (select 1 from public.founder_devices where user_id = p_uid and approved_at is not null and revoked_at is null) into v_has_approved;
  if not v_has_approved then
    insert into public.founder_devices (user_id, label, ua_hash, approved_at, last_seen_at) values (p_uid, v_label, p_device_hash, now(), now()) returning * into d;
    perform public.founder_audit_append(p_uid, 'founder.device.first_approved', d.id::text, 'first device trusted on first use (no approved device existed)', jsonb_build_object('label', v_label, 'code', d.pending_code));
    return jsonb_build_object('state', 'approved', 'device_id', d.id, 'label', d.label, 'first', true);
  end if;

  select count(*) into v_pending from public.founder_devices where user_id = p_uid and approved_at is null and revoked_at is null;
  if v_pending >= 5 then return jsonb_build_object('state', 'limit'); end if;

  insert into public.founder_devices (user_id, label, ua_hash) values (p_uid, v_label, p_device_hash) returning * into d;
  perform public.founder_audit_append(p_uid, 'founder.device.pending', d.id::text, 'new device asked for approval, waiting for founder', jsonb_build_object('label', v_label, 'code', d.pending_code));
  return jsonb_build_object('state', 'pending', 'code', d.pending_code, 'expires_at', d.created_at + interval '7 days');
end $$;
revoke all on function public.founder_device_exchange(uuid, text, text) from public, anon, authenticated;
grant execute on function public.founder_device_exchange(uuid, text, text) to service_role;
comment on function public.founder_device_exchange(uuid, text, text) is 'E104: the one door. Returns state approved|pending|revoked|limit. First device is trusted on first use.';

-- 5) approve / revoke
create or replace function public.founder_device_approve(p_uid uuid, p_code text, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare d public.founder_devices%rowtype;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'wajah (reason) kam az kam 8 akshar'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_device_approval:' || p_uid::text, 0));
  d := public._founder_device_pick(p_uid, p_code, true);
  update public.founder_devices set approved_at = now(), last_seen_at = now() where id = d.id returning * into d;
  perform public.founder_audit_append(p_uid, 'founder.device.approved', d.id::text, p_reason, jsonb_build_object('label', d.label, 'code', d.pending_code));
  return jsonb_build_object('state', 'approved', 'device_id', d.id, 'label', d.label);
end $$;
revoke all on function public.founder_device_approve(uuid, text, text) from public, anon, authenticated;
grant execute on function public.founder_device_approve(uuid, text, text) to service_role;

create or replace function public.founder_device_revoke(p_uid uuid, p_code text, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare d public.founder_devices%rowtype; left_ok int;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'wajah (reason) kam az kam 8 akshar'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_device_approval:' || p_uid::text, 0));
  d := public._founder_device_pick(p_uid, p_code, false);
  select count(*) into left_ok from public.founder_devices where user_id = p_uid and approved_at is not null and revoked_at is null and id <> d.id;
  if d.approved_at is not null and left_ok = 0 then raise exception 'aakhri approved device revoke nahi ho sakta (lock-out se bachao)'; end if;
  update public.founder_devices set revoked_at = now() where id = d.id;
  perform public.founder_audit_append(p_uid, 'founder.device.revoked', d.id::text, p_reason, jsonb_build_object('label', d.label, 'code', d.pending_code));
  return jsonb_build_object('state', 'revoked', 'device_id', d.id);
end $$;
revoke all on function public.founder_device_revoke(uuid, text, text) from public, anon, authenticated;
grant execute on function public.founder_device_revoke(uuid, text, text) to service_role;

-- 6) list / ok
create or replace function public.founder_device_list(p_uid uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(jsonb_build_object('code', pending_code, 'label', label,
         'state', case when revoked_at is not null then 'revoked' when approved_at is not null then 'approved' else 'pending' end,
         'created_at', created_at, 'last_seen_at', last_seen_at,
         'expires_at', case when approved_at is null and revoked_at is null then created_at + interval '7 days' end) order by created_at), '[]'::jsonb)
  from public.founder_devices where user_id = p_uid
$$;
revoke all on function public.founder_device_list(uuid) from public, anon, authenticated;
grant execute on function public.founder_device_list(uuid) to service_role;

create or replace function public.founder_device_ok(p_uid uuid, p_device uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (select 1 from public.founder_devices where id = p_device and user_id = p_uid and approved_at is not null and revoked_at is null)
$$;
revoke all on function public.founder_device_ok(uuid, uuid) from public, anon, authenticated;
grant execute on function public.founder_device_ok(uuid, uuid) to service_role;

-- 7) selftest (sab raaste, aakhir mein rollback)
create or replace function public.founder_devices_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; r text := ''; v_before bigint; v_audit_before bigint; res jsonb; i int; v_ok boolean;
        h1 text := encode(digest('selftest-device-1', 'sha256'), 'hex'); h2 text := encode(digest('selftest-device-2', 'sha256'), 'hex'); c2 text; id2 uuid; hx text;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E104 selftest SKIP — founder_accounts khali'; end if;
  select count(*) into v_before from public.founder_devices; select count(*) into v_audit_before from public.founder_audit;
  begin
    delete from public.founder_devices where user_id = v_uid;  -- rollback mein wapas aayega
    res := public.founder_device_exchange(v_uid, h1, 'Selftest Laptop');
    if res ->> 'state' <> 'approved' or (res ->> 'first')::boolean is not true then raise exception 'pehla device auto-approve nahi hua: %', res; end if;
    r := r || 'pehla device TOFU OK; ';
    res := public.founder_device_exchange(v_uid, h2, 'Selftest Phone');
    if res ->> 'state' <> 'pending' or res ->> 'expires_at' is null then raise exception 'doosra device pending nahi: %', res; end if;
    c2 := res ->> 'code'; select id into id2 from public.founder_devices where ua_hash = h2;
    r := r || 'doosra pending OK; ';
    if public.founder_device_ok(v_uid, id2) then raise exception 'pending device ok nikla'; end if;
    v_ok := false; begin perform public.founder_device_approve(v_uid, c2, 'chhota'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'chhoti wajah se approve ho gaya'; end if;
    v_ok := false; begin perform public.founder_device_approve(v_uid, 'zz', 'theek wajah yahan hai'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'ghalat code se approve ho gaya'; end if;
    res := public.founder_device_approve(v_uid, lower(c2), 'approved from server selftest');
    if res ->> 'state' <> 'approved' then raise exception 'approve fail %', res; end if;
    if not public.founder_device_ok(v_uid, id2) then raise exception 'approved device ok nahi'; end if;
    r := r || 'approve OK; ';
    -- immutability
    v_ok := false; begin update public.founder_devices set ua_hash = h1 where id = id2; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'ua_hash badal gaya'; end if;
    v_ok := false; begin update public.founder_devices set approved_at = now() + interval '1 day' where id = id2; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'approved_at badal gaya'; end if;
    r := r || 'immutability OK; ';
    res := public.founder_device_revoke(v_uid, encode(digest('selftest-device-2', 'sha256'), 'hex'), 'revoked from server selftest');  -- poora hash bhi chalta hai
    if public.founder_device_ok(v_uid, id2) then raise exception 'revoked device ab bhi ok'; end if;
    v_ok := false; begin update public.founder_devices set revoked_at = null where id = id2; exception when others then v_ok := true; end;
    if not v_ok then raise exception 'revoke wapas ho gaya'; end if;
    if public.founder_device_exchange(v_uid, h2, 'x') ->> 'state' <> 'revoked' then raise exception 'revoked exchange refuse nahi'; end if;
    r := r || 'revoke foran + terminal OK; ';
    v_ok := false; begin perform public.founder_device_revoke(v_uid, upper(left(h1, 8)), 'aakhri device hatane ki koshish'); exception when others then v_ok := true; end;
    if not v_ok then raise exception 'aakhri approved device revoke ho gaya (lock-out!)'; end if;
    r := r || 'aakhri device guard OK; ';
    -- cap: 5 pending, 6th = limit
    for i in 1..5 loop
      res := public.founder_device_exchange(v_uid, encode(digest('selftest-cap-' || i, 'sha256'), 'hex'), 'Cap ' || i);
      if res ->> 'state' <> 'pending' then raise exception 'cap % pending nahi: %', i, res; end if;
    end loop;
    if public.founder_device_exchange(v_uid, encode(digest('selftest-cap-6', 'sha256'), 'hex'), 'Cap 6') ->> 'state' <> 'limit' then raise exception '6th pending ko limit nahi mili'; end if;
    r := r || 'pending cap 5 OK; ';
    -- expiry: sabse purana pending 8 din purana banao (immutability created_at rokti hai, isliye trigger ek pal ke liye band)
    alter table public.founder_devices disable trigger founder_devices_guard;
    update public.founder_devices set created_at = now() - interval '8 days' where ua_hash = encode(digest('selftest-cap-1', 'sha256'), 'hex');
    alter table public.founder_devices enable trigger founder_devices_guard;
    res := public.founder_device_exchange(v_uid, encode(digest('selftest-cap-6', 'sha256'), 'hex'), 'Cap 6');
    if res ->> 'state' <> 'pending' then raise exception 'purana pending saaf hone par naya nahi bana: %', res; end if;
    if exists (select 1 from public.founder_devices where ua_hash = encode(digest('selftest-cap-1', 'sha256'), 'hex')) then raise exception 'purana pending saaf nahi hua'; end if;
    r := r || 'pending expiry 7d OK; ';
    -- prefix ambiguity: do pending device jinke hash ka pehla akshar same ho to 8-akshar code se pehchan nahi, lamba prefix chalta hai
    hx := encode(digest('selftest-cap-2', 'sha256'), 'hex');
    res := public.founder_device_approve(v_uid, hx, 'approve by full hash selftest');
    if res ->> 'state' <> 'approved' then raise exception 'full-hash approve fail'; end if;
    r := r || 'full-hash approve OK; ';
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
  if (select tgenabled from pg_trigger where tgname = 'founder_devices_guard' and tgrelid = 'public.founder_devices'::regclass) <> 'O' then raise exception 'founder_devices_guard trigger band reh gaya'; end if;
  return 'E104 selftest OK — ' || r || 'rollback saaf';
end $$;
revoke all on function public.founder_devices_selftest() from public, anon, authenticated;
grant execute on function public.founder_devices_selftest() to service_role;

do $$ begin
  raise notice '%', public.founder_devices_selftest();
end $$;
