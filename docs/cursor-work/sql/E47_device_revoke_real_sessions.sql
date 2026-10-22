
-- E47 — device REVOKE se asli login session khatam + device record ki deletion ka asli job — Blueprint G37 / PROMISES #5, #6 — 20 Oct 2026
--
-- Loophole jo audit mein mila: `device_trust_set(... 'revoked')` sirf `security_sessions` (app ki apni list) ki rows mitata tha. Asli login
-- (Supabase `auth.sessions`) zinda rehti thi — "revoke se live session foran khatam" jhoota tha. Ab:
--   * device_session_links  — har device_hash ke saath uski auth session (Rust `chat.device.vault` JWT ka session_id link karta hai)
--   * device_trust_set      — revoke par: linked auth.sessions DELETE (refresh token bhi saath jaate hain) + jin sessions ka link nahi
--                             un mein se wohi jinka browser+platform is device jaisa hai (device_signal_class); result mein 'sessions_killed' + 'method'
--   * device_vault_purge()  — "deletion date" asli ho: timer (integrity-purge runner) har ghante chalata hai (pehle koi nahi chalata tha)
-- PEHLE: phase19_22 (device_vault, device_trust_set, device_signal_class). Dobara chalana safe.
set search_path = public, extensions;

create table if not exists public.device_session_links (
  session_id  uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_hash text not null,
  linked_at   timestamptz not null default now()
);
create index if not exists device_session_links_dev_idx on public.device_session_links (user_id, device_hash);
alter table public.device_session_links enable row level security;
revoke all on public.device_session_links from public, anon, authenticated;
grant all on public.device_session_links to service_role;

create or replace function public.device_session_link(_user uuid, _device_hash text, _session uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
begin
  if _user is null or _session is null or coalesce(_device_hash, '') = '' then return jsonb_build_object('ok', false, 'error', 'bad_input'); end if;
  -- sirf us user ki apni, maujooda session link ho sakti hai
  if not exists (select 1 from auth.sessions s where s.id = _session and s.user_id = _user) then
    return jsonb_build_object('ok', false, 'error', 'session_not_found');
  end if;
  if not exists (select 1 from public.device_vault v where v.user_id = _user and v.device_hash = _device_hash) then
    return jsonb_build_object('ok', false, 'error', 'device_not_found');
  end if;
  insert into public.device_session_links (session_id, user_id, device_hash) values (_session, _user, _device_hash)
  on conflict (session_id) do update set device_hash = excluded.device_hash, linked_at = now();
  delete from public.device_session_links l where l.user_id = _user and not exists (select 1 from auth.sessions s where s.id = l.session_id);  -- purani/khatam links saaf
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.device_trust_set(
  _user uuid, _device_hash text, _state text, _actor text default 'user')
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_row public.device_vault; v_killed int := 0; v_n int := 0; v_method text := null;
begin
  if _state not in ('trusted','suspicious','revoked') then raise exception 'bad_state'; end if;

  update public.device_vault set state = _state, last_seen_at = last_seen_at
   where user_id = _user and device_hash = _device_hash
   returning * into v_row;
  if not found then raise exception 'device_not_found'; end if;

  -- Revoke = access marta hai: asli login sessions (auth.sessions) bhi
  if _state = 'revoked' then
    -- 1) is device se linked sessions
    if to_regclass('auth.sessions') is not null then
      delete from auth.sessions s
       where s.user_id = _user
         and s.id in (select l.session_id from public.device_session_links l where l.user_id = _user and l.device_hash = _device_hash);
      get diagnostics v_n = row_count; v_killed := v_killed + v_n;
      if v_n > 0 then v_method := 'linked'; end if;
      -- 2) jin sessions ka kisi device se link nahi: browser+platform jaisa is device ka hai
      if to_regprocedure('public.device_signal_class(text,text)') is not null then
        delete from auth.sessions s
         where s.user_id = _user
           and not exists (select 1 from public.device_session_links l where l.session_id = s.id)
           and public.device_signal_class(coalesce(s.user_agent, ''), 'platform') = v_row.platform_class
           and public.device_signal_class(coalesce(s.user_agent, ''), 'browser')  = v_row.browser_class;
        get diagnostics v_n = row_count; v_killed := v_killed + v_n;
        if v_n > 0 then v_method := coalesce(v_method || '+', '') || 'user_agent'; end if;
      end if;
    end if;
    -- 3) purani app-side list (jaisa pehle)
    if to_regclass('public.security_sessions') is not null then
      execute 'delete from public.security_sessions where user_id = $1 and device_label = $2' using _user, v_row.label;
    end if;
    if to_regclass('public.security_devices') is not null then
      execute 'update public.security_devices set state = ''blocked'' where user_id = $1 and label = $2' using _user, v_row.label;
    end if;
  end if;

  insert into public.device_trust_events (user_id, device_hash, event, actor, detail)
  values (_user, _device_hash,
          case _state when 'trusted' then 'trusted' when 'revoked' then 'revoked' else 'suspicious' end,
          _actor, jsonb_build_object('sessions_killed', v_killed, 'method', v_method));

  return jsonb_build_object('ok', true, 'device_hash', _device_hash, 'state', _state,
                            'sessions_killed', v_killed, 'method', v_method);
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.device_session_link(uuid,text,uuid)', 'public.device_trust_set(uuid,text,text,text)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

notify pgrst, 'reload schema';
-- Verify: select proname from pg_proc where proname in ('device_session_link','device_trust_set');
