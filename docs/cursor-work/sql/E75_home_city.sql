

-- E75 — Home city: awam_ui_pref.extra mein 5th key `home` ({city, country, iana, lat, lon}). 23 Oct 2026. E61 ke baad. Dobara chalana safe. Koi DROP nahi.
-- Wajah (meri chook, live pakdi): Rust locale `home` maanta hai, lekin DB ka validator sirf 4 keys maanta tha => Settings > Home city "Could not save preference" (500).
-- E61 mein yehi sabaq likha tha: naya key = Rust + DB validator DONO. Qaida Rust locale_glue::clean_home ka mirror hai (DB kabhi Rust se sakht nahi):
--   city 1..60, country <= 60, iana ^[A-Za-z][A-Za-z0-9_/+-]{0,63}$ bina '..', lat -90..90, lon -180..180 (numbers). Constraint dobara nahi lagani (function body badalti hai).
-- Advance: lock_timeout, immutable parallel safe, pinned search_path, purani rows ab bhi sahi, naya key sirf lagne par check.
set lock_timeout = '5s';
set statement_timeout = '60s';

create or replace function public.awam_ui_extra_ok(x jsonb)
returns boolean language plpgsql immutable parallel safe set search_path = pg_catalog, public as $$
declare
  k text; wh jsonb; d jsonb; p jsonb; c jsonb; ids text[] := '{}';
  s text; e text; z text; zs text[] := '{}'; h jsonb; lat numeric; lon numeric;
begin
  if x is null or jsonb_typeof(x) <> 'object' then return false; end if;
  for k in select jsonb_object_keys(x) loop
    if k not in ('calendars', 'work_hours', 'ooo', 'clocks', 'home') then return false; end if;
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
    if jsonb_typeof(h) <> 'object'
       or jsonb_typeof(h -> 'city') <> 'string' or char_length(btrim(h ->> 'city')) not between 1 and 60
       or jsonb_typeof(h -> 'country') <> 'string' or char_length(h ->> 'country') > 60
       or jsonb_typeof(h -> 'iana') <> 'string' or (h ->> 'iana') !~ '^[A-Za-z][A-Za-z0-9_/+-]{0,63}$' or position('..' in (h ->> 'iana')) > 0
       or jsonb_typeof(h -> 'lat') <> 'number' or jsonb_typeof(h -> 'lon') <> 'number'
    then return false; end if;
    lat := (h ->> 'lat')::numeric;
    lon := (h ->> 'lon')::numeric;
    if lat not between -90 and 90 or lon not between -180 and 180 then return false; end if;
  end if;
  return true;
end $$;



comment on function public.awam_ui_extra_ok(jsonb) is 'Validates awam_ui_pref.extra (calendars, work_hours, ooo, clocks, home). Mirror of Rust locale_glue clean_extra — never stricter.';
