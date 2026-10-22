-- E62 — Overlap Matrix (calendar #4b / W1): team ke working-hours + out-of-office + guest ka timezone, EK function mein (22 Oct 2026).
-- E57 + E58 + E61 ke baad. Dobara chalana safe. Koi DROP TABLE/COLUMN nahi, koi data nahi badalta (sirf function + index).
-- Advance level (Rule 38):
--   * PRIVACY DEEWAR DB mein (Rust par bharosa nahi): viewer us org ka active member na ho to {"error":"forbidden"}. Sirf SAME-org members ka
--     apna likha hua schedule (work_hours + ooo from/to) milta hai. OOO ka `note` (nijji) kabhi bahar nahi. Mail/event ka content kabhi nahi
--     (busy time alag `calendar_busy`, sirf free/busy).
--   * Guest (member nahi) ka sirf timezone (uski pichli meeting se) — schedule nahi; Rust usse "andaza" nahi, sirf raat/din se classify karta hai.
--   * Input sakht: pehle 100 entries hi dekhta hai (DoS), lower+trim, '@' wale, <= 254 chars, duplicate hata, <= 12 log (zyada ho to `truncated: true`), tz naam ka shape-check (Rust mirror).
--   * SECURITY INVOKER (least privilege), pinned search_path, STABLE + PARALLEL SAFE, sirf service_role ko execute (anon/authenticated/PUBLIC revoke).
--   * Lookup indexes: org_members (org_id, lower(email)); attendee side ka index (lower(address), event_id) pehle se maujood — naya nahi banta.
--   * lock_timeout / statement_timeout: lock na mile to 5s mein saaf fail.
--   * Member ko org_members.email se, na mile to auth.users.email se pehchanta hai (purani rows jinki email khali ho) — wahi org, zinda member.
--   * org_members na ho (test DB) to function sab ko guest maanta hai — toot'ta nahi (plpgsql lazy plan + to_regclass guard).
set lock_timeout = '5s';
set statement_timeout = '60s';

-- ---- 1. tz naam ka shape (Rust locale_core::clocks_ok / book_core::tz_shape_ok ka mirror, kabhi sakht nahi) -------------------
create or replace function public.calendar_team_zone_ok(z text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select z is not null and z ~ '^[A-Za-z][A-Za-z0-9_/+-]{0,63}$' and position('..' in z) = 0
$$;

-- ---- 2. lookup index (org_members: email se member dhoondna) ---------------------------------------------------------------
do $$ begin
  if to_regclass('public.org_members') is not null
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'org_members' and column_name = 'email')
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'org_members' and column_name = 'org_id') then
    create index if not exists org_members_org_email_lc_idx on public.org_members (org_id, lower(email));
  end if;
end $$;

-- ---- 3. team context ------------------------------------------------------------------------------------------------------------
-- p_viewer: jo dekh raha hai (auth se Rust deta hai) — DB khud dobara check karta hai.
-- Returns: {"members":[{address,kind,name,tz,known,work_hours,ooo}], "truncated":bool}  ya  {"error":"forbidden"}.
create or replace function public.calendar_team_context(p_org uuid, p_viewer uuid, p_addresses text[])
returns jsonb language plpgsql stable parallel safe set search_path = pg_catalog, public as $$
declare
  v_ok     boolean := false;
  v_addr   text[];
  v_total  integer;
  v_out    jsonb := '[]'::jsonb;
  a        text;
  v_uid    uuid;
  v_name   text;
  v_extra  jsonb;
  v_wh     jsonb;
  v_tz     text;
  v_ooo    jsonb;
  v_has    boolean;
begin
  if p_org is null or p_viewer is null then return jsonb_build_object('error', 'forbidden'); end if;
  v_has := to_regclass('public.org_members') is not null;

  -- viewer us org ka zinda member ho (revoked nahi)
  if v_has then
    select exists (select 1 from public.org_members m
                    where m.org_id = p_org and m.user_id = p_viewer and coalesce(m.status::text, 'active') <> 'revoked')
      into v_ok;
  end if;
  if not v_ok then return jsonb_build_object('error', 'forbidden'); end if;

  -- saaf, unique (pehli baar dikhne ka order), <= 12
  select coalesce(array_agg(x.addr order by x.ord), '{}'), count(*)
    into v_addr, v_total
    from (select s.addr, min(s.ord) as ord
            from (select lower(btrim(e.v)) as addr, e.ord
                    from unnest((coalesce(p_addresses, '{}'::text[]))[1:100]) with ordinality as e(v, ord)) s
           where s.addr like '%_@_%' and char_length(s.addr) <= 254
           group by s.addr) x;
  if v_total > 12 then v_addr := v_addr[1:12]; end if;

  foreach a in array v_addr loop
    v_uid := null; v_name := null; v_wh := null; v_tz := null; v_ooo := '[]'::jsonb;

    select m.user_id into v_uid
      from public.org_members m
     where m.org_id = p_org and lower(m.email) = a and coalesce(m.status::text, 'active') <> 'revoked'
     limit 1;
    -- purani rows: org_members.email khali ho sakti hai -> login email (auth.users) se bhi pehchano (sirf usi org ka zinda member)
    if v_uid is null and to_regclass('auth.users') is not null then
      select m.user_id into v_uid
        from public.org_members m
        join auth.users u on u.id = m.user_id
       where m.org_id = p_org and lower(u.email) = a and coalesce(m.status::text, 'active') <> 'revoked'
       limit 1;
    end if;

    if v_uid is not null then
      select p.extra into v_extra from public.awam_ui_pref p where p.user_id = v_uid;
      v_extra := coalesce(v_extra, '{}'::jsonb);
      if jsonb_typeof(v_extra -> 'work_hours') = 'object' then
        v_wh := v_extra -> 'work_hours';
        if public.calendar_team_zone_ok(v_wh ->> 'tz') then v_tz := v_wh ->> 'tz'; end if;
      end if;
      -- sirf aaj-se-kal-pehle ke baad ke OOO; `note` kabhi nahi
      select coalesce(jsonb_agg(jsonb_build_object('from', o ->> 'from', 'to', o ->> 'to')), '[]'::jsonb)
        into v_ooo
        from jsonb_array_elements(case when jsonb_typeof(v_extra -> 'ooo') = 'array' then v_extra -> 'ooo' else '[]'::jsonb end) o
       where (o ->> 'to') >= to_char(current_date - 1, 'YYYY-MM-DD');
    end if;

    -- guest (ya member jis ne tz nahi likhi): pichli meeting ka timezone
    if v_tz is null then
      select att.timezone into v_tz
        from public.calendar_attendees att
        join public.calendar_events ev on ev.id = att.event_id
       where att.org_id = p_org and lower(att.address) = a and public.calendar_team_zone_ok(att.timezone)
       order by ev.starts_at desc
       limit 1;
    end if;

    select att.display_name into v_name
      from public.calendar_attendees att
     where att.org_id = p_org and lower(att.address) = a and nullif(btrim(att.display_name), '') is not null
     limit 1;

    v_out := v_out || jsonb_build_object(
      'address', a,
      'kind', case when v_uid is not null then 'member' else 'guest' end,
      'name', left(v_name, 80),
      'tz', v_tz,
      'known', v_wh is not null,            -- schedule khud likha hua hai?
      'work_hours', v_wh,
      'ooo', v_ooo);
  end loop;

  return jsonb_build_object('members', v_out, 'truncated', v_total > 12 or coalesce(cardinality(p_addresses), 0) > 100);
end $$;

revoke all on function public.calendar_team_zone_ok(text)                 from public, anon, authenticated;
revoke all on function public.calendar_team_context(uuid, uuid, text[])   from public, anon, authenticated;
grant execute on function public.calendar_team_zone_ok(text)              to service_role;
grant execute on function public.calendar_team_context(uuid, uuid, text[]) to service_role;

comment on function public.calendar_team_zone_ok(text) is 'IANA zone name shape (mirror of Rust). Shape only; never stricter than Rust.';
comment on function public.calendar_team_context(uuid, uuid, text[]) is
  'Overlap Matrix input: same-org members'' self-declared work_hours + ooo dates (never notes) and guests'' last known timezone. Viewer must be an active member (DB-side wall). Max 12 addresses.';

notify pgrst, 'reload schema';
