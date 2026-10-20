-- E42 — device hash: SHA-256+pepper  ->  HMAC-SHA256 (key-separated)  — Blueprint G34 — 20 Oct 2026
--
-- Kyun: device record ka hash pehle `sha256(canon || '|' || pepper)` tha. Pepper wahi key thi jo sealed_signals ki encryption mein bhi
-- lagti hai (ek key, do kaam). Sahi tareeqa: HMAC-SHA256 aur har kaam ke liye alag derived key.
--   subkey  = HMAC-SHA256(key, 'anexomail/device-hash/v2')
--   hash_v2 = HMAC-SHA256(subkey, canon)          (canon = platform|browser|tz|screen|lang — sirf 5 moti nishaniyan, pehle jaisi)
-- Purane (v1) hash ka kya hoga:
--   * Gate + register DONO hashes dekhte hain (ban, 3+ accounts, 24 ghante wala counter) -> koi ban ya record gum nahi hota.
--   * Naya record v2 mein jata hai. Jis user ka purana v1 record hai, woh agli baar dikhne par khud v2 ban jata hai.
--   * Poora migration ek baar chalane ke liye: device_hash_migrate_v2(_key) — sealed_signals ko khol kar canon dobara bana kar v2 nikalta hai.
--     Server par chalane ka raasta: docs/cursor-work/server/device-hash-migrate.sh (key server ke env mein hai, SQL editor mein nahi).
-- Is file ka chalana safe hai (dobara chalane par kuch nahi bigarta). Kuch delete nahi hota.
-- Yeh file `signup_device_gate` (E18 wala non-blocking version, sirf human-confirmed ban rokta hai) aur `device_vault_register` ko
-- phir se likhti hai; baqi device functions (trust_set, list, purge, integrity) nahi chhedti.
set search_path = public, extensions;

create extension if not exists pgcrypto with schema extensions;

create or replace function public.device_hash_v1(_canon text, _key text)
returns text language sql immutable
set search_path = public, extensions as $$
  select encode(digest(_canon || '|' || coalesce(_key, 'no-pepper'), 'sha256'), 'hex')
$$;

create or replace function public.device_hash_v2(_canon text, _key text)
returns text language sql immutable
set search_path = public, extensions as $$
  select encode(
    hmac(convert_to(_canon, 'UTF8'),
         hmac(convert_to('anexomail/device-hash/v2', 'UTF8'),
              convert_to(coalesce(nullif(_key, ''), 'no-pepper'), 'UTF8'), 'sha256'),
         'sha256'),
    'hex')
$$;

revoke all on function public.device_hash_v1(text, text) from public, anon, authenticated;
revoke all on function public.device_hash_v2(text, text) from public, anon, authenticated;
grant execute on function public.device_hash_v1(text, text) to service_role;
grant execute on function public.device_hash_v2(text, text) to service_role;

-- ── signup gate: ban dono hash par; naya hash v2 ───────────────────────────────────────────────
create or replace function public.signup_device_gate(_signals jsonb, _key text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ua       text := coalesce(_signals->>'ua', '');
  v_platform text;
  v_browser  text;
  v_tz       int;
  v_screen   text;
  v_lang     text;
  v_canon    text;
  v_h1       text;
  v_h2       text;
  v_banned   boolean := false;
begin
  if to_regclass('public.device_vault') is null then
    return jsonb_build_object('ok', true, 'device_hash', null, 'skipped', true);
  end if;
  v_platform := coalesce(nullif(_signals->>'platform_class',''), public.device_signal_class(v_ua,'platform'));
  v_browser  := coalesce(nullif(_signals->>'browser_class',''), public.device_signal_class(v_ua,'browser'));
  v_tz       := coalesce((_signals->>'tz_offset_minutes')::int, 0) / 60;
  v_screen   := coalesce(_signals->>'screen_bucket', 'unknown');
  v_lang     := lower(left(coalesce(_signals->>'language','xx'), 2));
  v_canon    := concat_ws('|', v_platform, v_browser, v_tz::text, v_screen, v_lang);
  v_h1       := public.device_hash_v1(v_canon, _key);
  v_h2       := public.device_hash_v2(v_canon, _key);

  if to_regclass('public.device_bans') is not null then
    select exists (
      select 1 from public.device_bans b
       where b.device_hash in (v_h1, v_h2) and (b.expires_at is null or b.expires_at > now())
    ) into v_banned;
  end if;
  if v_banned then
    return jsonb_build_object('ok', false, 'error', 'device_banned', 'device_hash', v_h2);
  end if;

  return jsonb_build_object('ok', true, 'device_hash', v_h2);
end $$;

revoke all on function public.signup_device_gate(jsonb, text) from public, anon, authenticated;
grant execute on function public.signup_device_gate(jsonb, text) to service_role;

-- ── register: dono hash dekho, v2 mein likho, purana record khud v2 banao ──────────────────────
create or replace function public.device_vault_register(
  _user uuid, _signals jsonb, _key text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_ua        text := coalesce(_signals->>'ua', '');
  v_platform  text := coalesce(nullif(_signals->>'platform_class',''), public.device_signal_class(v_ua,'platform'));
  v_browser   text := coalesce(nullif(_signals->>'browser_class',''), public.device_signal_class(v_ua,'browser'));
  v_tz        int  := coalesce((_signals->>'tz_offset_minutes')::int, 0) / 60;   -- hour bucket
  v_screen    text := coalesce(_signals->>'screen_bucket', 'unknown');
  v_lang      text := lower(left(coalesce(_signals->>'language','xx'), 2));
  v_minimized jsonb;
  v_canon     text;
  v_h1        text;
  v_hash      text;      -- v2
  v_row       public.device_vault;
  v_reasons   jsonb := '[]'::jsonb;
  v_state     text := 'pending';
  v_users     int;
  v_recent    int;
  v_retain    int;
  v_limit     jsonb;
  v_count     int;
begin
  if _user is null then raise exception 'user_required'; end if;

  -- MINIMIZATION: sirf yeh 5 coarse signals, koi canvas/audio/font fingerprint nahi
  v_minimized := jsonb_build_object(
    'platform_class', v_platform, 'browser_class', v_browser,
    'timezone_bucket', v_tz, 'screen_bucket', v_screen, 'language', v_lang);

  v_canon := concat_ws('|', v_platform, v_browser, v_tz::text, v_screen, v_lang);
  v_h1    := public.device_hash_v1(v_canon, _key);
  v_hash  := public.device_hash_v2(v_canon, _key);

  -- is user ka purana v1 record: us ko ab v2 bana do (naya v2 record pehle se nahi hai to)
  if not exists (select 1 from public.device_vault where user_id = _user and device_hash = v_hash)
     and exists (select 1 from public.device_vault where user_id = _user and device_hash = v_h1) then
    update public.device_vault set device_hash = v_hash where user_id = _user and device_hash = v_h1;
    update public.device_trust_events set device_hash = v_hash where user_id = _user and device_hash = v_h1;
  end if;

  select retain_days into v_retain from public.device_vault_policy where id = 1;

  -- banned device? (dono hash)
  if exists (select 1 from public.device_bans b
              where b.device_hash in (v_hash, v_h1) and (b.expires_at is null or b.expires_at > now())) then
    v_state := 'banned';
    v_reasons := v_reasons || jsonb_build_array('device is on the banned list');
  end if;

  -- same hash multiple accounts = suspicious registration
  select count(distinct user_id) into v_users from public.device_vault where device_hash in (v_hash, v_h1);
  if v_users >= 3 and v_state <> 'banned' then
    v_state := 'suspicious';
    v_reasons := v_reasons || jsonb_build_array('this device shape registered on ' || v_users || ' accounts');
  end if;

  -- burst registrations from one device in 24h
  select count(*) into v_recent from public.device_trust_events
   where device_hash in (v_hash, v_h1) and event = 'registered' and at > now() - interval '24 hours';
  if v_recent >= 3 and v_state = 'pending' then
    v_state := 'suspicious';
    v_reasons := v_reasons || jsonb_build_array(v_recent || ' registrations from this device in 24h');
  end if;

  -- plan cap on vault size (naya device add karne se pehle)
  v_limit := public.chat_feature_allowed(_user, 'device_vault');
  select count(*) into v_count from public.device_vault where user_id = _user;
  if not exists (select 1 from public.device_vault where user_id = _user and device_hash = v_hash)
     and (v_limit->>'limit') is not null and v_count >= (v_limit->>'limit')::int then
    return jsonb_build_object('ok', false, 'error', 'device_limit_reached',
      'plan', v_limit->>'plan', 'limit', (v_limit->>'limit')::int);
  end if;

  insert into public.device_vault as d (
    user_id, device_hash, label, platform_class, browser_class, signal_count,
    sealed_signals, state, reasons, retain_until)
  values (
    _user, v_hash, v_browser || ' · ' || v_platform, v_platform, v_browser,
    5, pgp_sym_encrypt(v_minimized::text, coalesce(_key, 'no-pepper')),
    v_state, v_reasons, now() + make_interval(days => coalesce(v_retain, 180)))
  on conflict (user_id, device_hash) do update
    set last_seen_at = now(),
        registrations = d.registrations + 1,
        label = excluded.label,
        state = case when d.state = 'revoked' then 'revoked'
                     when excluded.state in ('banned','suspicious') then excluded.state
                     else d.state end,
        reasons = excluded.reasons,
        retain_until = now() + make_interval(days => coalesce(v_retain, 180))
  returning * into v_row;

  insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
  values (_user, v_hash,
          case when v_row.registrations = 1 then 'registered' else 'seen' end,
          'engine', jsonb_build_object('state', v_row.state, 'reasons', v_row.reasons));

  return jsonb_build_object(
    'ok', v_row.state not in ('banned','revoked'),
    'device_hash', v_hash,
    'label', v_row.label,
    'state', v_row.state,
    'reasons', v_row.reasons,
    'signals_collected', 5,
    'retain_until', v_row.retain_until,
    'legal_basis', v_row.legal_basis);
end $$;

revoke all on function public.device_vault_register(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.device_vault_register(uuid, jsonb, text) to service_role;

-- ── poora migration (ek baar): sealed_signals se canon dobara bana kar v2; ban pehle ────────────
create or replace function public.device_hash_migrate_v2(_key text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  r        record;
  s        jsonb;
  canon    text;
  h2       text;
  n_vault  int := 0;
  n_bans   int := 0;
  n_events int := 0;
  n_skip   int := 0;
begin
  if _key is null or _key = '' then raise exception 'key_required'; end if;

  for r in select d.id, d.user_id, d.device_hash, d.sealed_signals from public.device_vault d
            where d.sealed_signals is not null
  loop
    begin
      s := pgp_sym_decrypt(r.sealed_signals::bytea, _key)::jsonb;
      canon := concat_ws('|', s->>'platform_class', s->>'browser_class', s->>'timezone_bucket', s->>'screen_bucket', s->>'language');
      -- sirf woh record jinka hash sach mein v1 se milta hai (naye v2 ko chhedna nahi)
      if public.device_hash_v1(canon, _key) <> r.device_hash then n_skip := n_skip + 1; continue; end if;
      h2 := public.device_hash_v2(canon, _key);

      -- ban: purane hash par ban tha to v2 par bhi lagao (v1 wali row wahin rehti hai)
      if to_regclass('public.device_bans') is not null then
        insert into public.device_bans (device_hash, reason, banned_by, banned_at, expires_at)
        select h2, b.reason, b.banned_by, b.banned_at, b.expires_at
          from public.device_bans b where b.device_hash = r.device_hash
        on conflict (device_hash) do nothing;
        get diagnostics n_events = row_count;
        n_bans := n_bans + n_events;
      end if;

      if exists (select 1 from public.device_vault x where x.user_id = r.user_id and x.device_hash = h2) then
        n_skip := n_skip + 1; continue;   -- is user ke paas v2 pehle se hai
      end if;
      update public.device_vault set device_hash = h2 where id = r.id;
      update public.device_trust_events set device_hash = h2 where user_id = r.user_id and device_hash = r.device_hash;
      n_vault := n_vault + 1;
    exception when others then
      n_skip := n_skip + 1;   -- kisi aur key se seal hua tha / kharab record: chhod do, kuch nahi bigarta
    end;
  end loop;

  select count(*) into n_events from public.device_vault d
   where d.sealed_signals is not null;
  return jsonb_build_object('ok', true, 'vault_rows_moved_to_v2', n_vault, 'bans_copied_to_v2', n_bans,
                            'skipped', n_skip, 'vault_rows_total', n_events);
end $$;

revoke all on function public.device_hash_migrate_v2(text) from public, anon, authenticated;
grant execute on function public.device_hash_migrate_v2(text) to service_role;
