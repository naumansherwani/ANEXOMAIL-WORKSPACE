
-- E79 — W5 market chip: awam_ui_pref.extra mein 7th key `market` (sirf true/false). 23 Oct 2026. E78 ke baad. Dobara chalana safe. Koi DROP nahi.
-- Kya: user KHUD chip ON karta hai (default OFF = key hi nahi). Koi exchange/price/position store nahi hota; exchange ke ghante web mein bundled hain.
-- Qaida Rust locale_glue::clean_extra ("market" => boolean) ka mirror hai. Naye key = Rust + DB validator DONO (E61/E75/E78 ka sabaq).
-- Sakht-pan: jsonb_typeof(NULL) ka hole band (`is distinct from`), purane 6 keys ke qaide bilkul wahi (E78 se copy), lock_timeout/statement_timeout, pinned search_path.
set lock_timeout = '5s';
set statement_timeout = '60s';

create or replace function public.awam_ui_extra_ok(x jsonb)
returns boolean language plpgsql immutable parallel safe set search_path = pg_catalog, public as $$
declare
  k text; wh jsonb; d jsonb; p jsonb; c jsonb; ids text[] := '{}';
  s text; e text; z text; zs text[] := '{}'; h jsonb; lat numeric; lon numeric;
  tv jsonb; t_dep timestamptz; t_arr timestamptz;
begin
  if x is null or jsonb_typeof(x) <> 'object' then return false; end if;
  for k in select jsonb_object_keys(x) loop
    if k not in ('calendars', 'work_hours', 'ooo', 'clocks', 'home', 'travel', 'market') then return false; end if;
  end loop;

  if x ? 'calendars' then
    c := x -> 'calendars';
    if jsonb_typeof(c) <> 'array' or jsonb_array_length(c) not between 1 and 20 then return false; end if;
    for p in select * from jsonb_array_elements(c) loop
      if jsonb_typeof(p) <> 'object'
         or jsonb_typeof(p -> 'id') <> 'string' or (p ->> 'id') !~ '^[a-z0-9_-]{1,24}$'
         or (p ->> 'id') = any (ids)
         or jsonb_typeof(p -> 'name') <> 'string' or char_length(btrim(p ->> 'name')) not between 1 and 40
         or jsonb_typeof(p -> 'color') <> 'string' or (p ->> 'color') !~ '^#[0-9a-fA-F]{6}$'
      then return false; end if;
      ids := ids || (p ->> 'id');
    end loop;
  end if;

  if x ? 'work_hours' then
    wh := x -> 'work_hours';
    if jsonb_typeof(wh) <> 'object' or jsonb_typeof(wh -> 'days') <> 'array' or jsonb_array_length(wh -> 'days') <> 7 then
      return false;
    end if;
    for d in select * from jsonb_array_elements(wh -> 'days') loop
      if jsonb_typeof(d) <> 'object' or jsonb_typeof(d -> 'on') <> 'boolean' then return false; end if;
      s := coalesce(d ->> 'start', '09:00');
      e := coalesce(d ->> 'end', '17:00');
      if s !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or e !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then return false; end if;
      if (d -> 'on') = 'true'::jsonb and s collate "C" >= e collate "C" then return false; end if;
    end loop;
    if wh ? 'tz' and (jsonb_typeof(wh -> 'tz') <> 'string' or (wh ->> 'tz') !~ '^[A-Za-z0-9_/+-]{1,64}$') then
      return false;
    end if;
  end if;

  if x ? 'ooo' then
    if jsonb_typeof(x -> 'ooo') <> 'array' or jsonb_array_length(x -> 'ooo') > 20 then return false; end if;
    for p in select * from jsonb_array_elements(x -> 'ooo') loop
      if jsonb_typeof(p) <> 'object'
         or jsonb_typeof(p -> 'from') <> 'string' or (p ->> 'from') !~ '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
         or jsonb_typeof(p -> 'to') <> 'string' or (p ->> 'to') !~ '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
         or (p ->> 'from') > (p ->> 'to')
         or (p ? 'note' and (jsonb_typeof(p -> 'note') <> 'string' or char_length(p ->> 'note') > 200))
      then return false; end if;
    end loop;
  end if;
  if x ? 'clocks' then
    if jsonb_typeof(x -> 'clocks') <> 'array' or jsonb_array_length(x -> 'clocks') > 6 then return false; end if;
    for c in select * from jsonb_array_elements(x -> 'clocks') loop
      if jsonb_typeof(c) <> 'string' then return false; end if;
      z := c #>> '{}';
      if z !~ '^[A-Za-z][A-Za-z0-9_/+-]{0,63}$' or position('..' in z) > 0 or z = any (zs) then return false; end if;
      zs := zs || z;
    end loop;
  end if;
  if x ? 'home' then
    h := x -> 'home';
    if jsonb_typeof(h) is distinct from 'object'
       or jsonb_typeof(h -> 'city') is distinct from 'string' or char_length(btrim(h ->> 'city')) not between 1 and 60
       or (h ? 'country' and (jsonb_typeof(h -> 'country') is distinct from 'string' or char_length(h ->> 'country') > 60))
       or jsonb_typeof(h -> 'iana') is distinct from 'string' or (h ->> 'iana') !~ '^[A-Za-z][A-Za-z0-9_/+-]{0,63}$' or position('..' in (h ->> 'iana')) > 0
       or jsonb_typeof(h -> 'lat') is distinct from 'number' or jsonb_typeof(h -> 'lon') is distinct from 'number'
    then return false; end if;
    lat := (h ->> 'lat')::numeric;
    lon := (h ->> 'lon')::numeric;
    if lat not between -90 and 90 or lon not between -180 and 180 then return false; end if;
  end if;
  if x ? 'travel' then
    tv := x -> 'travel';
    if jsonb_typeof(tv) is distinct from 'object'
       or jsonb_typeof(tv -> 'to_city') is distinct from 'string' or char_length(btrim(tv ->> 'to_city')) not between 1 and 60
       or jsonb_typeof(tv -> 'to_zone') is distinct from 'string' or (tv ->> 'to_zone') !~ '^[A-Za-z][A-Za-z0-9_/+-]{0,63}$' or position('..' in (tv ->> 'to_zone')) > 0
       or jsonb_typeof(tv -> 'depart_at') is distinct from 'string' or (tv ->> 'depart_at') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
       or jsonb_typeof(tv -> 'arrive_at') is distinct from 'string' or (tv ->> 'arrive_at') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
    then return false; end if;
    -- real calendar dates only (Feb 30 raises), explicit UTC so the session time zone cannot change the answer
    begin
      t_dep := make_timestamptz(substr(tv ->> 'depart_at', 1, 4)::int, substr(tv ->> 'depart_at', 6, 2)::int, substr(tv ->> 'depart_at', 9, 2)::int,
                                substr(tv ->> 'depart_at', 12, 2)::int, substr(tv ->> 'depart_at', 15, 2)::int, substr(tv ->> 'depart_at', 18, 2)::int, 'UTC');
      t_arr := make_timestamptz(substr(tv ->> 'arrive_at', 1, 4)::int, substr(tv ->> 'arrive_at', 6, 2)::int, substr(tv ->> 'arrive_at', 9, 2)::int,
                                substr(tv ->> 'arrive_at', 12, 2)::int, substr(tv ->> 'arrive_at', 15, 2)::int, substr(tv ->> 'arrive_at', 18, 2)::int, 'UTC');
    exception when others then
      return false;
    end;
    if t_arr <= t_dep or t_arr - t_dep > interval '72 hours' then return false; end if;
  end if;
  if x ? 'market' and jsonb_typeof(x -> 'market') is distinct from 'boolean' then return false; end if;
  return true;
end $$;



comment on function public.awam_ui_extra_ok(jsonb) is 'Validates awam_ui_pref.extra (calendars, work_hours, ooo, clocks, home, travel, market). Mirror of Rust locale_glue clean_extra — never stricter.';
