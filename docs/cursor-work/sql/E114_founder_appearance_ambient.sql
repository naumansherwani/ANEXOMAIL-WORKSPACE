-- E114 — FOUNDER SETTINGS S1b (master order, right after step 6): ONE KEY REGISTRY + the full Appearance tab + AMBIENT STUDIO (car-style ambient looks).
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), security definer RPCs (service_role only, search_path + statement_timeout pinned), on E108 (founder_settings + history), E113 (Time machine,
--             Drift, schedule). The Rust (axum) layer and the React/Three.js UI come after this file is green (Rule 64: one phase at a time).
-- Founder orders (1 Nov 2026): "jaisa awam ka Appearance hai waisa hi founder par, graphics ki speed har cheez waisi hi" and "founder ko builtin 1 million graphics option, cursor aage peeche
-- karne se change hon, jaise cars mein ambient lights ki list aati hai."
-- What this file does:
--   1) REGISTRY       — founder_setting_registry (key, area, kind, default, label). Until now the allowed keys were typed into E108 in three places (a CHECK, a validator and the write door).
--                       From here ONE table decides. founder_settings.key becomes a foreign key to it, founder_setting_set and the Time machine look keys up in it.
--   2) APPEARANCE     — the awam controls, same values as the user app: appearance.text_scale (90/100/115/130/150), animations (full/reduced/none), transitions (fast/normal/slow),
--                       celebration, focus_ring, density (compact/comfortable), reduce_motion. (appearance.graphics and appearance.sidebar_slim already exist.)
--   3) AMBIENT STUDIO — a look is a small recipe, not a picture: {palette, pattern, speed, intensity, blend, seed}. The catalog is real rows computed here:
--                       120 palettes (12 colour families x 10 moods, colours worked out from HSL), 24 patterns (each with a photosensitivity limit: never more than 2 flashes a second),
--                       20 speeds (geometric 0.25x..2x), 10 intensities, 8 blend modes, 65,536 noise seeds. Every look has ONE stable number (a mixed-radix index), so the picker can
--                       step forward and backward through the whole list like a car's ambient-light menu, and "look #n" always means the same look on every device.
--                       The total is COMPUTED from the tables (founder_ambient_total), never typed in. Favourites: up to 24 recipes.
--   4) INFO ROWS      — plain-words Explain / Blast radius text for each new key (E113 registry), and which keys can be scheduled (an "evening look at 19:00" is a scheduled ambient change).
--   5) selftest / selftest2 (rolled back, E104 standard), E113 selftest2 made registry-aware (8b), photosensitivity cap, neighbours and Surprise-me RPCs (3b). CHECK_E114.sql has 14 checks.
-- Rules kept: every write still goes through founder_setting_set (history + founder_audit in one transaction); registries are read-only for service_role (revoke all first, then grant exactly
-- what is needed — Supabase gives service_role everything on new tables by default); nothing here touches the awam tables (FC18 / Rule 35). Polar :3400 NO-TOUCH. Safe to run again.
-- Not re-runnable after this file: E108 and E113 (they would put back the old fixed key lists). sql-run.sh keeps a sha ledger, so each runs once.

set lock_timeout = '10s';
set statement_timeout = '120s';
set search_path = pg_catalog, public, extensions;

-- ==============================================================================================================================
-- 0) prerequisites
-- ==============================================================================================================================
do $$
begin
  if to_regclass('public.founder_settings') is null or to_regclass('public.founder_settings_history') is null or to_regprocedure('public.founder_setting_set(uuid,text,jsonb)') is null
     or to_regprocedure('public._founder_setting_valid(text,jsonb)') is null then
    raise exception 'E114: run E108 first (founder_settings / founder_setting_set)';
  end if;
  if to_regclass('public.founder_settings_info') is null or to_regclass('public.founder_settings_schedule') is null or to_regprocedure('public.founder_settings_history_list(uuid,text,bigint,integer)') is null then
    raise exception 'E114: run E113 first (Time machine / schedule / info registry)';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings_s1b:ddl', 0));
end $$;

-- ==============================================================================================================================
-- 1) ONE key registry
-- ==============================================================================================================================
create table if not exists public.founder_setting_registry (
  key           text primary key check (key ~ '^[a-z]+(\.[a-z_]+)+$' and length(key) <= 40),
  area          text not null check (area in ('personal','appearance','workspace','notifications','privacy','mail','ai')),
  kind          text not null check (kind in ('text','image','place','bool','enum','recipe','recipes')),
  default_value jsonb,                                    -- JSON null = no default stored (the UI shows "default" or follows the device)
  label         text not null,
  sort          integer not null default 100
);
alter table public.founder_setting_registry enable row level security;
revoke all on public.founder_setting_registry from public, anon, authenticated, service_role;
grant select on public.founder_setting_registry to service_role;
comment on table public.founder_setting_registry is 'E114: the ONE list of founder setting keys. founder_settings.key references it; founder_setting_set and the Time machine consult it. Read-only for service_role.';

insert into public.founder_setting_registry (key, area, kind, default_value, label, sort) values
  ('personal.display_name',    'personal',   'text',   null,                     'Display name',        10),
  ('personal.avatar',          'personal',   'image',  null,                     'Profile photo',       20),
  ('personal.home',            'personal',   'place',  null,                     'Home city',           30),
  ('appearance.graphics',      'appearance', 'bool',   'true'::jsonb,            'Graphics',           100),
  ('appearance.sidebar_slim',  'appearance', 'bool',   'false'::jsonb,           'Compact sidebar',    110),
  ('appearance.text_scale',    'appearance', 'enum',   '100'::jsonb,             'Text size',          120),
  ('appearance.animations',    'appearance', 'enum',   '"full"'::jsonb,          'Animations',         130),
  ('appearance.transitions',   'appearance', 'enum',   '"normal"'::jsonb,        'Transitions',        140),
  ('appearance.celebration',   'appearance', 'bool',   'true'::jsonb,            'Celebration',        150),
  ('appearance.focus_ring',    'appearance', 'bool',   'false'::jsonb,           'High-contrast focus ring', 160),
  ('appearance.density',       'appearance', 'enum',   '"comfortable"'::jsonb,   'Density',            170),
  ('appearance.reduce_motion', 'appearance', 'bool',   'false'::jsonb,           'Reduce motion',      180),
  ('appearance.ambient',       'appearance', 'recipe', '{"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}'::jsonb, 'Ambient look', 190),
  ('appearance.ambient_favs',  'appearance', 'recipes','[]'::jsonb,              'Favourite looks',    200)
on conflict (key) do update set area = excluded.area, kind = excluded.kind, default_value = excluded.default_value, label = excluded.label, sort = excluded.sort;

-- the fixed lists in E108 / E113 become a foreign key to the registry
do $$
declare c record;
begin
  alter table public.founder_settings drop constraint if exists founder_settings_key_registry;
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_key_fk' and conrelid = 'public.founder_settings'::regclass) then
    alter table public.founder_settings add constraint founder_settings_key_fk foreign key (key) references public.founder_setting_registry(key);
  end if;
  -- the schedule table had an inline CHECK listing four keys (auto-named); drop whichever check lists keys, then reference the registry
  for c in select conname from pg_constraint where conrelid = 'public.founder_settings_schedule'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%personal.display_name%' loop
    execute format('alter table public.founder_settings_schedule drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_schedule_key_fk' and conrelid = 'public.founder_settings_schedule'::regclass) then
    alter table public.founder_settings_schedule add constraint founder_settings_schedule_key_fk foreign key (key) references public.founder_setting_registry(key);
  end if;
end $$;

-- ==============================================================================================================================
-- 2) AMBIENT catalog — real rows, computed here
-- ==============================================================================================================================
-- 2a) colour helper: HSL (degrees, 0..1, 0..1) -> '#rrggbb'
create or replace function public._fa_hex(p_h numeric, p_s numeric, p_l numeric) returns text
language plpgsql immutable set search_path = pg_catalog as $$
declare hh numeric := mod(mod(p_h, 360) + 360, 360); s numeric := greatest(0, least(1, p_s)); l numeric := greatest(0, least(1, p_l));
        c numeric; x numeric; m numeric; r numeric; g numeric; b numeric;
begin
  c := (1 - abs(2 * l - 1)) * s; x := c * (1 - abs(mod(hh / 60, 2) - 1)); m := l - c / 2;
  if    hh < 60  then r := c; g := x; b := 0;
  elsif hh < 120 then r := x; g := c; b := 0;
  elsif hh < 180 then r := 0; g := c; b := x;
  elsif hh < 240 then r := 0; g := x; b := c;
  elsif hh < 300 then r := x; g := 0; b := c;
  else r := c; g := 0; b := x; end if;
  return '#' || lpad(to_hex(round((r + m) * 255)::integer), 2, '0') || lpad(to_hex(round((g + m) * 255)::integer), 2, '0') || lpad(to_hex(round((b + m) * 255)::integer), 2, '0');
end $$;

-- 2b) tables (read-only for service_role)
create table if not exists public.founder_ambient_palettes (
  id    smallint primary key check (id >= 0),
  name  text not null unique check (length(name) between 3 and 40),
  stops text[] not null check (array_length(stops, 1) = 3 and stops[1] ~ '^#[0-9a-f]{6}$' and stops[2] ~ '^#[0-9a-f]{6}$' and stops[3] ~ '^#[0-9a-f]{6}$'),
  family text not null, mood text not null
);
create table if not exists public.founder_ambient_patterns (
  id smallint primary key check (id >= 0),
  name text not null unique check (length(name) between 3 and 30),
  motion boolean not null,
  flashes_per_sec numeric not null check (flashes_per_sec >= 0 and flashes_per_sec <= 2),      -- photosensitivity: never more than 2 flashes a second, at any speed step (speed max is applied in the UI as a cap too)
  note text not null
);
create table if not exists public.founder_ambient_blends (
  id smallint primary key check (id >= 0),
  name text not null unique,
  css text not null check (css in ('normal','screen','overlay','soft-light','lighten','color-dodge','hue','plus-lighter'))
);
create table if not exists public.founder_ambient_speeds (
  id smallint primary key check (id >= 0), factor numeric not null check (factor between 0.25 and 2.0), label text not null
);
create table if not exists public.founder_ambient_intensities (
  id smallint primary key check (id >= 0), percent smallint not null check (percent between 10 and 100), label text not null
);
do $$
declare t text;
begin
  foreach t in array array['founder_ambient_palettes','founder_ambient_patterns','founder_ambient_blends','founder_ambient_speeds','founder_ambient_intensities'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to service_role', t);
  end loop;
end $$;

-- 2c) rows. Palettes: 12 colour families x 10 moods = 120. Id = family*10 + mood. Family 6 is "Aurora" (the look the founder already has), so palette 60 = "Aurora Dawn".
do $$
declare fam text[] := array['Ruby','Ember','Amber','Citrine','Lime','Emerald','Aurora','Glacier','Cobalt','Indigo','Violet','Magenta'];
        hue numeric[] := array[350,18,38,55,90,140,165,195,220,250,275,315];
        mood text[] := array['Dawn','Mist','Neon','Velvet','Dusk','Pulse','Noir','Pearl','Storm','Halo'];
        sat numeric[] := array[0.75,0.30,1.00,0.55,0.65,0.90,0.40,0.25,0.50,0.85];
        lig numeric[] := array[0.62,0.74,0.55,0.34,0.45,0.50,0.22,0.86,0.38,0.70];
        shf numeric[] := array[25,-15,40,-20,50,10,0,12,-35,30];
        f integer; m integer; h numeric; s numeric; l numeric; d numeric;
begin
  for f in 1..12 loop
    for m in 1..10 loop
      h := hue[f]; s := sat[m]; l := lig[m]; d := shf[m];
      insert into public.founder_ambient_palettes (id, name, stops, family, mood)
        values (((f - 1) * 10 + (m - 1))::smallint, fam[f] || ' ' || mood[m],
                array[public._fa_hex(h, s, l), public._fa_hex(h + d, s, least(1, l + 0.06)), public._fa_hex(h + 2 * d, s * 0.9, greatest(0, l - 0.08))], fam[f], mood[m])
      on conflict (id) do update set name = excluded.name, stops = excluded.stops, family = excluded.family, mood = excluded.mood;
    end loop;
  end loop;
end $$;

insert into public.founder_ambient_patterns (id, name, motion, flashes_per_sec, note) values
  (0,  'Still',      false, 0.0, 'One steady colour wash, no movement.'),
  (1,  'Breathe',    true,  0.2, 'Slow in-and-out glow, like a calm breath. The default.'),
  (2,  'Wave',       true,  0.3, 'A soft band of light rolling across the screen.'),
  (3,  'Sweep',      true,  0.4, 'A gentle sweep from one edge to the other.'),
  (4,  'Ripple',     true,  0.5, 'Rings of light spreading from the centre.'),
  (5,  'Chase',      true,  0.6, 'Light travelling around the border.'),
  (6,  'Pulse',      true,  0.8, 'A steady, soft heartbeat of light.'),
  (7,  'Drift',      true,  0.1, 'Colours slowly floating past each other.'),
  (8,  'Spiral',     true,  0.3, 'A slow spiral of colour turning around the centre.'),
  (9,  'Tide',       true,  0.2, 'Light rising and falling from the bottom edge.'),
  (10, 'Bloom',      true,  0.3, 'Colour opening outward like a flower.'),
  (11, 'Comet',      true,  0.5, 'A bright head with a long fading tail crossing the screen.'),
  (12, 'Glow',       true,  0.1, 'A very slight swell of one colour; the quietest moving look.'),
  (13, 'Shimmer',    true,  1.0, 'Fine sparkle, kept below the flash limit.'),
  (14, 'Cascade',    true,  0.4, 'Light falling from the top in soft curtains.'),
  (15, 'Orbit',      true,  0.3, 'Two colours circling each other.'),
  (16, 'Horizon',    true,  0.1, 'A glowing line that slowly rises and settles.'),
  (17, 'Prism',      true,  0.4, 'Colour splitting into bands that slowly rotate.'),
  (18, 'Veil',       true,  0.2, 'Translucent curtains of colour drifting sideways.'),
  (19, 'Echo',       true,  0.6, 'A pulse that repeats smaller and fainter.'),
  (20, 'Rise',       true,  0.2, 'Light climbing from the bottom corners.'),
  (21, 'Fall',       true,  0.2, 'Light settling toward the bottom corners.'),
  (22, 'Weave',      true,  0.4, 'Two ribbons of colour crossing over and under.'),
  (23, 'Heartbeat',  true,  1.2, 'Two-beat pulse at a calm resting rate, below the flash limit.')
on conflict (id) do update set name = excluded.name, motion = excluded.motion, flashes_per_sec = excluded.flashes_per_sec, note = excluded.note;

insert into public.founder_ambient_blends (id, name, css) values
  (0, 'Normal', 'normal'), (1, 'Screen', 'screen'), (2, 'Overlay', 'overlay'), (3, 'Soft light', 'soft-light'),
  (4, 'Lighten', 'lighten'), (5, 'Colour dodge', 'color-dodge'), (6, 'Hue', 'hue'), (7, 'Plus lighter', 'plus-lighter')
on conflict (id) do update set name = excluded.name, css = excluded.css;

insert into public.founder_ambient_speeds (id, factor, label)
  select i::smallint, round(0.25 * power(8::numeric, i / 19.0), 3), 'Speed ' || (i + 1) from generate_series(0, 19) i
on conflict (id) do update set factor = excluded.factor, label = excluded.label;

insert into public.founder_ambient_intensities (id, percent, label)
  select i::smallint, ((i + 1) * 10)::smallint, ((i + 1) * 10) || '%' from generate_series(0, 9) i
on conflict (id) do update set percent = excluded.percent, label = excluded.label;

-- ==============================================================================================================================
-- 3) recipe maths: validity, one stable number per look (mixed radix), step forward / backward, describe
--    index = palette + P*(pattern + T*(speed + S*(intensity + I*(blend + B*seed))))   -> palette changes fastest, like cycling a car's ambient colours
-- ==============================================================================================================================
create or replace function public._fa_seeds() returns integer language sql immutable set search_path = pg_catalog as $$ select 65536 $$;

create or replace function public.founder_ambient_total() returns bigint
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select (select count(*) from public.founder_ambient_palettes)::bigint * (select count(*) from public.founder_ambient_patterns)
       * (select count(*) from public.founder_ambient_speeds) * (select count(*) from public.founder_ambient_intensities)
       * (select count(*) from public.founder_ambient_blends) * public._fa_seeds()
$$;

create or replace function public._fa_recipe_valid(p_r jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog, public as $$
declare k text; v text;
begin
  if p_r is null or jsonb_typeof(p_r) <> 'object' then return false; end if;
  if (select array_agg(x order by x) from jsonb_object_keys(p_r) x) is distinct from array['blend','intensity','palette','pattern','seed','speed'] then return false; end if;
  foreach k in array array['blend','intensity','palette','pattern','seed','speed'] loop
    if jsonb_typeof(p_r -> k) <> 'number' then return false; end if;
    v := p_r ->> k;
    if v !~ '^[0-9]{1,6}$' then return false; end if;               -- whole non-negative numbers only (no decimals, no signs, no exponents)
  end loop;
  return (p_r ->> 'palette')::integer < (select count(*) from public.founder_ambient_palettes)
     and (p_r ->> 'pattern')::integer < (select count(*) from public.founder_ambient_patterns)
     and (p_r ->> 'speed')::integer < (select count(*) from public.founder_ambient_speeds)
     and (p_r ->> 'intensity')::integer < (select count(*) from public.founder_ambient_intensities)
     and (p_r ->> 'blend')::integer < (select count(*) from public.founder_ambient_blends)
     and (p_r ->> 'seed')::integer < public._fa_seeds();
end $$;

create or replace function public.founder_ambient_index(p_r jsonb) returns bigint
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare P bigint := (select count(*) from public.founder_ambient_palettes); T bigint := (select count(*) from public.founder_ambient_patterns);
        S bigint := (select count(*) from public.founder_ambient_speeds); I bigint := (select count(*) from public.founder_ambient_intensities); B bigint := (select count(*) from public.founder_ambient_blends);
begin
  if not public._fa_recipe_valid(p_r) then raise exception 'not a valid ambient look' using errcode = '22023'; end if;
  return (p_r ->> 'palette')::bigint + P * ((p_r ->> 'pattern')::bigint + T * ((p_r ->> 'speed')::bigint + S * ((p_r ->> 'intensity')::bigint + I * ((p_r ->> 'blend')::bigint + B * (p_r ->> 'seed')::bigint))));
end $$;

create or replace function public.founder_ambient_at(p_n bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare P bigint := (select count(*) from public.founder_ambient_palettes); T bigint := (select count(*) from public.founder_ambient_patterns);
        S bigint := (select count(*) from public.founder_ambient_speeds); I bigint := (select count(*) from public.founder_ambient_intensities); B bigint := (select count(*) from public.founder_ambient_blends);
        q bigint; r jsonb;
begin
  if p_n is null or p_n < 0 or p_n >= public.founder_ambient_total() then raise exception 'look number out of range' using errcode = '22023'; end if;
  q := p_n;
  r := jsonb_build_object('palette', q % P); q := q / P;
  r := r || jsonb_build_object('pattern', q % T); q := q / T;
  r := r || jsonb_build_object('speed', q % S); q := q / S;
  r := r || jsonb_build_object('intensity', q % I); q := q / I;
  r := r || jsonb_build_object('blend', q % B); q := q / B;
  r := r || jsonb_build_object('seed', q);
  return r;
end $$;

-- step through the whole list, wrapping around at both ends (delta may be negative)
create or replace function public.founder_ambient_step(p_r jsonb, p_delta bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_total bigint := public.founder_ambient_total(); v_n bigint;
begin
  if p_delta is null or abs(p_delta) > v_total then raise exception 'step too large' using errcode = '22023'; end if;
  v_n := public.founder_ambient_index(p_r);
  return public.founder_ambient_at(((v_n + p_delta) % v_total + v_total) % v_total);
end $$;

create or replace function public.founder_ambient_describe(p_r jsonb) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_n bigint;
begin
  v_n := public.founder_ambient_index(p_r);
  return jsonb_build_object('index', v_n,
    'palette', (select jsonb_build_object('id', id, 'name', name, 'stops', to_jsonb(stops)) from public.founder_ambient_palettes where id = (p_r ->> 'palette')::smallint),
    'pattern', (select jsonb_build_object('id', id, 'name', name, 'motion', motion, 'flashes_per_sec', flashes_per_sec, 'note', note) from public.founder_ambient_patterns where id = (p_r ->> 'pattern')::smallint),
    'speed',   (select jsonb_build_object('id', id, 'factor', factor) from public.founder_ambient_speeds where id = (p_r ->> 'speed')::smallint),
    'intensity', (select jsonb_build_object('id', id, 'percent', percent) from public.founder_ambient_intensities where id = (p_r ->> 'intensity')::smallint),
    'blend',   (select jsonb_build_object('id', id, 'name', name, 'css', css) from public.founder_ambient_blends where id = (p_r ->> 'blend')::smallint),
    'seed', (p_r ->> 'seed')::integer,
    'effective_flashes_per_sec', public.founder_ambient_effective_rate(p_r));
end $$;

-- the whole catalog in one answer (small: about 120 palettes), with the totals computed from the tables
create or replace function public.founder_ambient_catalog() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select jsonb_build_object(
    'palettes',  (select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'stops', to_jsonb(stops), 'family', family, 'mood', mood) order by id) from public.founder_ambient_palettes),
    'patterns',  (select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'motion', motion, 'flashes_per_sec', flashes_per_sec, 'note', note) order by id) from public.founder_ambient_patterns),
    'blends',    (select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'css', css) order by id) from public.founder_ambient_blends),
    'speeds',    (select jsonb_agg(jsonb_build_object('id', id, 'factor', factor) order by id) from public.founder_ambient_speeds),
    'intensities', (select jsonb_agg(jsonb_build_object('id', id, 'percent', percent) order by id) from public.founder_ambient_intensities),
    'seeds', public._fa_seeds(),
    'total', public.founder_ambient_total(),
    'default', (select default_value from public.founder_setting_registry where key = 'appearance.ambient'),
    'max_favourites', 24)
$$;


-- ==============================================================================================================================
-- 3b) photosensitivity, the picker's neighbours, and "Surprise me"
-- ==============================================================================================================================
-- A pattern's own rate is multiplied by the speed. The effective rate is capped at 2 flashes a second, whatever pattern and speed are chosen (at speed 2.0x, Heartbeat would otherwise reach 2.4).
create or replace function public.founder_ambient_effective_rate(p_r jsonb) returns numeric
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_raw numeric;
begin
  if not public._fa_recipe_valid(p_r) then raise exception 'not a valid ambient look' using errcode = '22023'; end if;
  select pt.flashes_per_sec * sp.factor into v_raw
    from public.founder_ambient_patterns pt, public.founder_ambient_speeds sp
   where pt.id = (p_r ->> 'pattern')::smallint and sp.id = (p_r ->> 'speed')::smallint;
  return round(least(2, v_raw), 3);
end $$;

-- the looks around the current one, so the picker can pre-render the next and previous before the cursor gets there (both directions wrap)
create or replace function public.founder_ambient_neighbours(p_r jsonb, p_each integer default 3) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_each integer := least(greatest(coalesce(p_each, 3), 1), 12); v_n bigint; v_total bigint := public.founder_ambient_total();
begin
  v_n := public.founder_ambient_index(p_r);
  return jsonb_build_object('index', v_n, 'total', v_total,
    'previous', (select coalesce(jsonb_agg(jsonb_build_object('n', ((v_n - i) % v_total + v_total) % v_total, 'recipe', public.founder_ambient_at(((v_n - i) % v_total + v_total) % v_total)) order by i), '[]'::jsonb) from generate_series(1, v_each) i),
    'next',     (select coalesce(jsonb_agg(jsonb_build_object('n', (v_n + i) % v_total, 'recipe', public.founder_ambient_at((v_n + i) % v_total)) order by i), '[]'::jsonb) from generate_series(1, v_each) i));
end $$;

-- "Surprise me": a whole number from the browser becomes one look. Same input, same look (deterministic, so it can be tested), spread over the whole list.
create or replace function public.founder_ambient_surprise(p_entropy bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_total bigint := public.founder_ambient_total();
begin
  if p_entropy is null then raise exception 'entropy needed' using errcode = '22023'; end if;
  return public.founder_ambient_at(abs(hashtextextended('ambient:' || p_entropy::text, 114)) % v_total);
end $$;

-- ==============================================================================================================================
-- 4) validator + write door now read the registry
-- ==============================================================================================================================
create or replace function public._founder_setting_valid(p_key text, p_value jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog, public as $$
declare t text; e jsonb;
begin
  case p_key
    when 'personal.display_name' then
      if jsonb_typeof(p_value) <> 'string' then return false; end if;
      t := p_value #>> '{}';
      return t ~ '^[^\x00-\x1f\x7f<>]{2,60}$' and btrim(t) = t;
    when 'personal.avatar' then
      if jsonb_typeof(p_value) <> 'string' then return false; end if;
      t := p_value #>> '{}';
      if t like 'data:image/%' then
        return length(t) <= 180000 and t ~ '^data:image/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=]+$';
      end if;
      return length(t) <= 500 and t ~ '^https://[^\s"<>'']+$';
    when 'personal.home' then
      if jsonb_typeof(p_value) <> 'object' then return false; end if;
      if (select array_agg(k order by k) from jsonb_object_keys(p_value) k) is distinct from array['city','country','iana','lat','lon'] then return false; end if;
      if jsonb_typeof(p_value -> 'city') <> 'string' or jsonb_typeof(p_value -> 'country') <> 'string' or jsonb_typeof(p_value -> 'iana') <> 'string'
         or jsonb_typeof(p_value -> 'lat') <> 'number' or jsonb_typeof(p_value -> 'lon') <> 'number' then return false; end if;
      if (p_value ->> 'city') !~ '^[^\x00-\x1f\x7f<>]{1,60}$' or (p_value ->> 'country') !~ '^[^\x00-\x1f\x7f<>]{0,60}$' then return false; end if;
      if (p_value ->> 'lat')::numeric not between -90 and 90 or (p_value ->> 'lon')::numeric not between -180 and 180 then return false; end if;
      return exists (select 1 from pg_timezone_names where name = p_value ->> 'iana');
    when 'appearance.graphics', 'appearance.sidebar_slim', 'appearance.celebration', 'appearance.focus_ring', 'appearance.reduce_motion' then
      return jsonb_typeof(p_value) = 'boolean';
    when 'appearance.text_scale' then
      return jsonb_typeof(p_value) = 'number' and (p_value #>> '{}') in ('90','100','115','130','150');
    when 'appearance.animations' then
      return jsonb_typeof(p_value) = 'string' and (p_value #>> '{}') in ('full','reduced','none');
    when 'appearance.transitions' then
      return jsonb_typeof(p_value) = 'string' and (p_value #>> '{}') in ('fast','normal','slow');
    when 'appearance.density' then
      return jsonb_typeof(p_value) = 'string' and (p_value #>> '{}') in ('compact','comfortable');
    when 'appearance.ambient' then
      return public._fa_recipe_valid(p_value);
    when 'appearance.ambient_favs' then
      if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) > 24 then return false; end if;
      for e in select x from jsonb_array_elements(p_value) x loop
        if not public._fa_recipe_valid(e) then return false; end if;
      end loop;
      return (select count(distinct x) from jsonb_array_elements(p_value) x) = jsonb_array_length(p_value);   -- no duplicates
    else return false;
  end case;
end $$;
revoke all on function public._founder_setting_valid(text, jsonb) from public, anon, authenticated;

create or replace function public.founder_setting_set(p_uid uuid, p_key text, p_value jsonb)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare old jsonb; v_new jsonb := case when p_value is null or jsonb_typeof(p_value) = 'null' then null else p_value end; ho text; hn text; v_avatar boolean := (p_key = 'personal.avatar'); a jsonb;
begin
  if p_uid is null or not exists (select 1 from public.founder_accounts where user_id = p_uid) then raise exception 'founder nahi' using errcode = '42501'; end if;
  if p_key is null or not exists (select 1 from public.founder_setting_registry where key = p_key) then raise exception 'unknown setting' using errcode = '22023'; end if;
  if v_new is not null and not public._founder_setting_valid(p_key, v_new) then raise exception 'invalid value for %', p_key using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_settings:' || p_uid::text, 0));
  select value into old from public.founder_settings where user_id = p_uid and key = p_key;
  if old is not distinct from v_new then return jsonb_build_object('changed', false, 'key', p_key); end if;
  ho := case when old is null then null else encode(digest(old::text, 'sha256'), 'hex') end;
  hn := case when v_new is null then null else encode(digest(v_new::text, 'sha256'), 'hex') end;
  if v_new is null then delete from public.founder_settings where user_id = p_uid and key = p_key;
  else insert into public.founder_settings (user_id, key, value) values (p_uid, p_key, v_new)
       on conflict (user_id, key) do update set value = excluded.value, updated_at = now(); end if;
  insert into public.founder_settings_history (user_id, key, old_hash, new_hash, old_value, new_value)
    values (p_uid, p_key, ho, hn, case when v_avatar then null else old end, case when v_avatar then null else v_new end);
  a := public.founder_audit_append(p_uid, 'settings.' || p_key, p_key, 'founder changed own setting', jsonb_build_object('from', left(coalesce(ho, 'default'), 12), 'to', left(coalesce(hn, 'default'), 12)));
  return jsonb_build_object('changed', true, 'key', p_key, 'audit_seq', a -> 'seq');
end $$;
revoke all on function public.founder_setting_set(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.founder_setting_set(uuid, text, jsonb) to service_role;

-- the Time machine list: same as E113 but the key filter reads the registry (so new keys appear without editing a list)
create or replace function public.founder_settings_history_list(p_uid uuid, p_key text default null, p_before_id bigint default null, p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200); v_items jsonb; v_more boolean;
begin
  perform public._fs_assert_founder(p_uid);
  if p_key is not null and not exists (select 1 from public.founder_setting_registry where key = p_key) then raise exception 'unknown setting' using errcode = '22023'; end if;
  with page as (
    select h.* from public.founder_settings_history h
     where h.user_id = p_uid and (p_key is null or h.key = p_key) and (p_before_id is null or h.id < p_before_id)
     order by h.id desc limit v_lim + 1
  ), shown as (select * from page order by id desc limit v_lim)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'key', s.key, 'at_ms', public._fs_ms(s.changed_at), 'at', to_char(s.changed_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'hash_only', s.key = 'personal.avatar',
           'from', s.old_value, 'to', s.new_value,
           'from_hash', left(s.old_hash, 12), 'to_hash', left(s.new_hash, 12),
           'was_default', s.old_hash is null, 'now_default', s.new_hash is null,
           'reverted', exists (select 1 from public.founder_settings_revert_log r where r.target_history_id = s.id),
           'can_undo', s.key <> 'personal.avatar'
                       and not exists (select 1 from public.founder_settings_revert_log r where r.target_history_id = s.id)
                       and public._fs_current(p_uid, s.key) is distinct from s.old_value,
           'audit_seq', public._fs_audit_seq_for(p_uid, s.key, s.old_hash, s.new_hash, s.changed_at)
         ) order by s.id desc), '[]'::jsonb),
         (select count(*) > v_lim from page)
    into v_items, v_more from shown s;
  return jsonb_build_object('items', v_items, 'more', v_more,
                            'next_before_id', case when v_more then (select min((e ->> 'id')::bigint) from jsonb_array_elements(v_items) e) else null end);
end $$;
revoke all on function public.founder_settings_history_list(uuid, text, bigint, integer) from public, anon, authenticated;
grant execute on function public.founder_settings_history_list(uuid, text, bigint, integer) to service_role;

-- registry answer for the UI (kinds + defaults, so the page never invents either)
create or replace function public.founder_setting_registry_list() returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce(jsonb_agg(jsonb_build_object('key', r.key, 'area', r.area, 'kind', r.kind, 'default', r.default_value, 'label', r.label,
                                               'schedulable', coalesce(i.schedulable, false), 'reversible', coalesce(i.reversible, true)) order by r.sort), '[]'::jsonb)
    from public.founder_setting_registry r left join public.founder_settings_info i on i.key = r.key
$$;

-- ==============================================================================================================================
-- 5) plain-words info rows for every new key (Explain / Blast radius in the Settings page, E113 registry)
-- ==============================================================================================================================
insert into public.founder_settings_info (key, label, plain, example, tradeoff, surfaces, severity, reversible, schedulable) values
 ('appearance.text_scale', 'Text size',
  'Makes every piece of text on the founder workspace bigger or smaller. Saved on your account, so each approved device shows the same size.',
  '115% reads comfortably on a large monitor; 90% fits more on a small laptop.',
  'Bigger text means fewer rows on screen.', array['Every page'], 'low', true, true),
 ('appearance.animations', 'Animations',
  'Full keeps the whole motion language. Reduced keeps only fades. None is complete stillness. Your operating system''s reduced-motion setting always wins on top of this.',
  'Choose Reduced on a slow laptop; the dashboard keeps all its data.',
  'None is the calmest and the lightest, but nothing moves to show that something changed.', array['Every page','Ambient look'], 'low', true, true),
 ('appearance.transitions', 'Transitions',
  'The tempo of every panel, hover and reveal. Fast is 0.6 times the standard clock, slow is 1.5 times.',
  'Fast feels snappy when you click through many pages.',
  'Slow is gentler but makes busy work feel slower.', array['Every page'], 'low', true, true),
 ('appearance.celebration', 'Celebration',
  'A short, earned moment of delight when work is really finished — for example a proof completing or a queue reaching zero.',
  'Turn it off if you prefer a quiet workspace.',
  'Off removes the small confirmation of a finished piece of work.', array['Dashboard','Settings'], 'low', true, true),
 ('appearance.focus_ring', 'High-contrast focus ring',
  'Makes the keyboard position unmistakable with a thick, high-contrast ring. Useful on projectors and for accessibility reviews.',
  'Turn it on before sharing your screen on a projector.',
  'It is visually heavier than the default ring.', array['Every page'], 'low', true, true),
 ('appearance.density', 'Density',
  'How tightly the layout packs information. Compact fits more on screen, Comfortable gives more breathing room.',
  'Compact shows more audit rows without scrolling.',
  'Compact is denser and easier to misclick on a touch screen.', array['Every page'], 'low', true, true),
 ('appearance.reduce_motion', 'Reduce motion',
  'Honour the calm setting and drop all non-essential animation on this account.',
  'Helpful if movement on screen is distracting.',
  'Some transitions that explain what changed will not play.', array['Every page','Ambient look'], 'low', true, true),
 ('appearance.ambient', 'Ambient look',
  'The atmosphere behind the workspace, picked like a car''s ambient lighting: step forward and backward through the whole list and the screen changes live. A look is a small recipe (palette, pattern, speed, intensity, blend, seed), so the same look appears the same on every approved device.',
  'Aurora Dawn with Breathe at 70% is the default. Step on to Aurora Mist, Aurora Neon, and so on.',
  'Moving looks use a little more battery; Graphics off or Reduce motion turns them into a still wash. No look flashes more than twice a second: that is enforced for every pattern at every speed.',
  array['Aurora background','3D scenes','Ambient edge'], 'low', true, true),
 ('appearance.ambient_favs', 'Favourite looks',
  'Up to 24 ambient looks you have kept, one tap away.',
  'Keep a calm look for work and a bright one for presenting.',
  'The list holds 24; adding a 25th needs one to be removed first.', array['Ambient look picker'], 'low', true, false)
on conflict (key) do update set label = excluded.label, plain = excluded.plain, example = excluded.example, tradeoff = excluded.tradeoff, surfaces = excluded.surfaces,
  severity = excluded.severity, reversible = excluded.reversible, schedulable = excluded.schedulable;

-- ==============================================================================================================================
-- 6) grants (service_role only)
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array['public.founder_ambient_total()','public.founder_ambient_index(jsonb)','public.founder_ambient_at(bigint)','public.founder_ambient_step(jsonb,bigint)',
                           'public.founder_ambient_describe(jsonb)','public.founder_ambient_catalog()','public.founder_setting_registry_list()',
                           'public.founder_ambient_effective_rate(jsonb)','public.founder_ambient_neighbours(jsonb,integer)','public.founder_ambient_surprise(bigint)',
                           'public.founder_appearance_selftest()','public.founder_appearance_selftest2()'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon, authenticated', f);
      execute format('grant execute on function %s to service_role', f);
    end if;
  end loop;
  revoke all on function public._fa_hex(numeric, numeric, numeric), public._fa_seeds(), public._fa_recipe_valid(jsonb) from public, anon, authenticated;
end $$;

comment on function public.founder_ambient_total() is 'E114: number of distinct ambient looks, computed from the catalog tables (palettes x patterns x speeds x intensities x blends x seeds). Never typed in.';
comment on function public.founder_ambient_step(jsonb, bigint) is 'E114: step forward/backward through the whole look list, wrapping at both ends. Palette changes fastest.';

-- ==============================================================================================================================
-- 7) selftest (everything rolled back)
-- ==============================================================================================================================
create or replace function public.founder_appearance_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '90s' as $$
declare
  u uuid; r text := ''; j jsonb; j2 jsonb; v_total bigint; n bigint; bad integer; k text; recipe jsonb; fav jsonb; sid uuid;
  b_set bigint; b_hist bigint; b_audit bigint; b_rev bigint; b_sch bigint;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E114 selftest SKIP — no founder account'; end if;
  select count(*) into b_set from public.founder_settings; select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  select count(*) into b_rev from public.founder_settings_revert_log; select count(*) into b_sch from public.founder_settings_schedule;
  begin
    delete from public.founder_settings where user_id = u;

    -- registry
    if (select count(*) from public.founder_setting_registry) <> 14 then raise exception 'registry must list 14 keys'; end if;
    if exists (select 1 from public.founder_settings_info i where not exists (select 1 from public.founder_setting_registry r where r.key = i.key)) then raise exception 'info row without a registry key'; end if;
    if exists (select 1 from public.founder_setting_registry r where not exists (select 1 from public.founder_settings_info i where i.key = r.key)) then raise exception 'registry key without an info row'; end if;
    if public._fs_fails(format($q$insert into public.founder_settings (user_id, key, value) values (%L, 'bad.key', 'true'::jsonb)$q$, u)) is not true then raise exception 'unregistered key stored'; end if;
    if public._fs_fails(format($q$select public.founder_setting_set(%L, 'appearance.nope', 'true'::jsonb)$q$, u)) is not true then raise exception 'unregistered key set through the door'; end if;
    j := public.founder_setting_registry_list();
    if jsonb_array_length(j) <> 14 or (select count(*) from jsonb_array_elements(j) e where (e ->> 'schedulable')::boolean) < 10 then raise exception 'registry list shape: %', j; end if;
    r := r || 'registry OK; ';

    -- every old key still works through the door
    perform public.founder_setting_set(u, 'personal.display_name', to_jsonb('Registry Tester'::text));
    perform public.founder_setting_set(u, 'appearance.graphics', to_jsonb(false));
    perform public.founder_setting_set(u, 'appearance.sidebar_slim', to_jsonb(true));
    perform public.founder_setting_set(u, 'personal.home', jsonb_build_object('city','Lahore','country','Pakistan','iana','Asia/Karachi','lat',31.52,'lon',74.36));
    perform public.founder_setting_set(u, 'personal.avatar', to_jsonb('data:image/png;base64,iVBORw0KGgo='::text));
    r := r || 'old keys OK; ';

    -- Appearance keys: valid and invalid
    perform public.founder_setting_set(u, 'appearance.text_scale', to_jsonb(115));
    perform public.founder_setting_set(u, 'appearance.animations', to_jsonb('reduced'::text));
    perform public.founder_setting_set(u, 'appearance.transitions', to_jsonb('slow'::text));
    perform public.founder_setting_set(u, 'appearance.celebration', to_jsonb(false));
    perform public.founder_setting_set(u, 'appearance.focus_ring', to_jsonb(true));
    perform public.founder_setting_set(u, 'appearance.density', to_jsonb('compact'::text));
    perform public.founder_setting_set(u, 'appearance.reduce_motion', to_jsonb(true));
    foreach k in array array['appearance.text_scale|120','appearance.text_scale|"115"','appearance.text_scale|115.5','appearance.animations|"off"','appearance.animations|true','appearance.transitions|"medium"',
                             'appearance.celebration|"yes"','appearance.focus_ring|1','appearance.density|"cozy"','appearance.density|["compact"]','appearance.reduce_motion|"true"'] loop
      if not public._fs_fails(format($q$select public.founder_setting_set(%L, %L, %L::jsonb)$q$, u, split_part(k, '|', 1), split_part(k, '|', 2))) then raise exception 'invalid value accepted: %', k; end if;
    end loop;
    if public.founder_settings_get(u) -> 'appearance.text_scale' <> to_jsonb(115) or public.founder_settings_get(u) -> 'appearance.density' <> to_jsonb('compact'::text) then raise exception 'appearance values not stored'; end if;
    perform public.founder_setting_set(u, 'appearance.text_scale', 'null'::jsonb);
    if public.founder_settings_get(u) ? 'appearance.text_scale' then raise exception 'null did not return text_scale to default'; end if;
    r := r || 'appearance keys OK; ';

    -- catalog sizes and the computed total
    if (select count(*) from public.founder_ambient_palettes) <> 120 or (select count(*) from public.founder_ambient_patterns) <> 24 or (select count(*) from public.founder_ambient_speeds) <> 20
       or (select count(*) from public.founder_ambient_intensities) <> 10 or (select count(*) from public.founder_ambient_blends) <> 8 then raise exception 'catalog sizes wrong'; end if;
    v_total := public.founder_ambient_total();
    if v_total <> 120::bigint * 24 * 20 * 10 * 8 * 65536 then raise exception 'total is %, expected the product of the table sizes', v_total; end if;
    if v_total < 1000000 then raise exception 'fewer than one million looks'; end if;
    r := r || 'catalog+total (' || v_total || ') OK; ';

    -- palette quality: unique names, 3 hex stops, Aurora Dawn is id 60 and is the default recipe's palette
    if (select count(distinct name) from public.founder_ambient_palettes) <> 120 then raise exception 'palette names not unique'; end if;
    if (select count(distinct stops) from public.founder_ambient_palettes) < 110 then raise exception 'too many identical colour sets'; end if;
    if (select name from public.founder_ambient_palettes where id = 60) <> 'Aurora Dawn' then raise exception 'palette 60 must be Aurora Dawn'; end if;
    if (select name from public.founder_ambient_patterns where id = 1) <> 'Breathe' or (select name from public.founder_ambient_patterns where id = 0) <> 'Still' then raise exception 'pattern ids wrong'; end if;
    if (select max(flashes_per_sec) from public.founder_ambient_patterns) > 2 then raise exception 'a pattern exceeds the flash limit'; end if;
    if exists (select 1 from public.founder_ambient_patterns where not motion and flashes_per_sec > 0) then raise exception 'a still pattern flashes'; end if;
    if (select factor from public.founder_ambient_speeds where id = 0) <> 0.25 or (select factor from public.founder_ambient_speeds where id = 19) <> 2.000 then raise exception 'speed range wrong'; end if;
    if public._fa_hex(0, 1, 0.5) <> '#ff0000' or public._fa_hex(120, 1, 0.5) <> '#00ff00' or public._fa_hex(240, 1, 0.5) <> '#0000ff' or public._fa_hex(0, 0, 1) <> '#ffffff' or public._fa_hex(0, 0, 0) <> '#000000' then raise exception 'HSL maths wrong'; end if;
    r := r || 'palettes+patterns+speeds OK; ';

    -- recipe validation
    recipe := (select default_value from public.founder_setting_registry where key = 'appearance.ambient');
    if not public._fa_recipe_valid(recipe) then raise exception 'the default recipe is invalid'; end if;
    foreach k in array array['{"palette":120,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}','{"palette":60,"pattern":24,"speed":9,"intensity":6,"blend":0,"seed":0}','{"palette":60,"pattern":1,"speed":20,"intensity":6,"blend":0,"seed":0}',
                             '{"palette":60,"pattern":1,"speed":9,"intensity":10,"blend":0,"seed":0}','{"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":8,"seed":0}','{"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":65536}',
                             '{"palette":-1,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}','{"palette":60.5,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}','{"palette":"60","pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}',
                             '{"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0}','{"palette":60,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0,"extra":1}','[]','"x"','null'] loop
      if public._fa_recipe_valid(k::jsonb) then raise exception 'invalid recipe accepted: %', k; end if;
    end loop;
    r := r || 'recipe validation OK; ';

    -- one stable number per look: round trip on the edges and on 3000 spread-out numbers
    if public.founder_ambient_index(public.founder_ambient_at(0)) <> 0 or public.founder_ambient_index(public.founder_ambient_at(v_total - 1)) <> v_total - 1 then raise exception 'edge round trip failed'; end if;
    if public.founder_ambient_at(0) <> '{"palette":0,"pattern":0,"speed":0,"intensity":0,"blend":0,"seed":0}'::jsonb then raise exception 'look 0 wrong'; end if;
    if public.founder_ambient_at(v_total - 1) <> '{"palette":119,"pattern":23,"speed":19,"intensity":9,"blend":7,"seed":65535}'::jsonb then raise exception 'last look wrong'; end if;
    if public.founder_ambient_index(recipe) <> 60 + 120 * 1 + 120 * 24 * 9 + 120 * 24 * 20 * 6 then raise exception 'default look number wrong: %', public.founder_ambient_index(recipe); end if;
    select count(*) into bad from generate_series(1, 3000) i where public.founder_ambient_index(public.founder_ambient_at(abs(hashtextextended(i::text, 7)) % v_total)) <> abs(hashtextextended(i::text, 7)) % v_total;
    if bad > 0 then raise exception 'round trip failed for % numbers', bad; end if;
    select count(*) into bad from (select distinct public.founder_ambient_at(i)::text from generate_series(0, 4999) i) d;
    if bad <> 5000 then raise exception 'two numbers gave the same look (% distinct of 5000)', bad; end if;
    if not public._fs_fails(format($q$select public.founder_ambient_at(%s)$q$, v_total)) or not public._fs_fails($q$select public.founder_ambient_at(-1)$q$) then raise exception 'out-of-range number accepted'; end if;
    r := r || 'index bijection OK; ';

    -- stepping like a car menu: palette first, wrap at the ends, step back undoes step forward
    j := public.founder_ambient_step(recipe, 1);
    if (j ->> 'palette')::integer <> 61 or j - 'palette' <> recipe - 'palette' then raise exception 'step +1 must only move the palette: %', j; end if;
    j := public.founder_ambient_step('{"palette":119,"pattern":1,"speed":9,"intensity":6,"blend":0,"seed":0}'::jsonb, 1);
    if (j ->> 'palette')::integer <> 0 or (j ->> 'pattern')::integer <> 2 then raise exception 'palette wrap must carry to the next pattern: %', j; end if;
    if public.founder_ambient_step(public.founder_ambient_step(recipe, 37), -37) <> recipe then raise exception 'step back did not undo step forward'; end if;
    if public.founder_ambient_step(recipe, v_total) <> recipe or public.founder_ambient_step(recipe, -v_total) <> recipe then raise exception 'a full lap must return to the same look'; end if;
    if public.founder_ambient_step('{"palette":119,"pattern":23,"speed":19,"intensity":9,"blend":7,"seed":65535}'::jsonb, 1) <> '{"palette":0,"pattern":0,"speed":0,"intensity":0,"blend":0,"seed":0}'::jsonb then raise exception 'the very last look must wrap to the first'; end if;
    if not public._fs_fails(format($q$select public.founder_ambient_step(%L::jsonb, %s)$q$, recipe::text, v_total + 1)) then raise exception 'step larger than a lap accepted'; end if;
    r := r || 'stepping+wrap OK; ';

    -- describe + catalog
    j := public.founder_ambient_describe(recipe);
    if j -> 'palette' ->> 'name' <> 'Aurora Dawn' or j -> 'pattern' ->> 'name' <> 'Breathe' or j -> 'blend' ->> 'css' <> 'normal' or jsonb_array_length(j -> 'palette' -> 'stops') <> 3 then raise exception 'describe wrong: %', j; end if;
    j := public.founder_ambient_catalog();
    if jsonb_array_length(j -> 'palettes') <> 120 or (j ->> 'total')::bigint <> v_total or (j ->> 'max_favourites')::integer <> 24 or j -> 'default' <> recipe then raise exception 'catalog answer wrong'; end if;
    r := r || 'describe+catalog OK; ';

    -- ambient setting through the door, history, undo, replay
    j := public.founder_setting_set(u, 'appearance.ambient', public.founder_ambient_step(recipe, 5));
    if (j ->> 'changed')::boolean is not true then raise exception 'ambient not saved'; end if;
    -- write first, read after, in separate statements: Postgres may evaluate the operands of one OR in any order (it did, in the first server run)
    j := public.founder_setting_set(u, 'appearance.ambient', 'null'::jsonb);
    if j ->> 'changed' <> 'true' then raise exception 'ambient null must change the stored value'; end if;
    j2 := public.founder_settings_get(u);
    if j2 ? 'appearance.ambient' then raise exception 'ambient null must return to the default'; end if;
    perform public.founder_setting_set(u, 'appearance.ambient', public.founder_ambient_step(recipe, 5));
    perform public.founder_setting_set(u, 'appearance.ambient', public.founder_ambient_step(recipe, 9));
    j := public.founder_setting_revert(u, public._fs_last_history_id(u, 'appearance.ambient'), 'selftest undo the look');
    if public._fs_current(u, 'appearance.ambient') <> public.founder_ambient_step(recipe, 5) then raise exception 'undo of an ambient look failed'; end if;
    j := public.founder_settings_history_list(u, 'appearance.ambient', null, 10);
    if jsonb_array_length(j -> 'items') < 4 then raise exception 'ambient history not listed'; end if;
    r := r || 'ambient set+undo OK; ';

    -- favourites: 24 fine, 25 refused, duplicates and invalid refused
    select jsonb_agg(public.founder_ambient_at(i * 120)) into fav from generate_series(0, 23) i;
    if (public.founder_setting_set(u, 'appearance.ambient_favs', fav) ->> 'changed')::boolean is not true then raise exception '24 favourites refused'; end if;
    select jsonb_agg(public.founder_ambient_at(i * 120)) into fav from generate_series(0, 24) i;
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'appearance.ambient_favs', %L::jsonb)$q$, u, fav::text)) then raise exception '25 favourites accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'appearance.ambient_favs', %L::jsonb)$q$, u, jsonb_build_array(recipe, recipe)::text)) then raise exception 'duplicate favourites accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'appearance.ambient_favs', '[{"palette":1}]'::jsonb)$q$, u)) then raise exception 'invalid favourite accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_setting_set(%L, 'appearance.ambient_favs', '{"a":1}'::jsonb)$q$, u)) then raise exception 'favourites as an object accepted'; end if;
    r := r || 'favourites OK; ';

    -- an "evening look" can be scheduled; the tick applies it and the rollback timer puts the old look back
    j := public.founder_settings_schedule_create(u, 'appearance.ambient', public.founder_ambient_step(recipe, 20), now() + interval '2 minutes', 15, 'selftest evening look');
    sid := (j ->> 'id')::uuid;
    perform public.founder_settings_schedule_tick(now() + interval '3 minutes');
    if public._fs_current(u, 'appearance.ambient') <> public.founder_ambient_step(recipe, 20) then raise exception 'scheduled look not applied'; end if;
    perform public.founder_settings_schedule_tick(now() + interval '30 minutes');
    if public._fs_current(u, 'appearance.ambient') <> public.founder_ambient_step(recipe, 5) or (select state from public.founder_settings_schedule where id = sid) <> 'rolled_back' then raise exception 'scheduled look not rolled back'; end if;
    if not public._fs_fails(format($q$select public.founder_settings_schedule_create(%L, 'appearance.ambient_favs', '[]'::jsonb, now() + interval '5 minutes', null, 'selftest favs cannot be scheduled')$q$, u)) then raise exception 'favourites were schedulable'; end if;
    r := r || 'scheduled look+rollback OK; ';

    -- photosensitivity: for EVERY pattern at EVERY speed the effective rate is at most 2 a second; a still pattern is 0; the cap really bites (Heartbeat at top speed)
    select count(*) into bad from public.founder_ambient_patterns pt, public.founder_ambient_speeds sp
     where public.founder_ambient_effective_rate(jsonb_build_object('palette',0,'pattern',pt.id,'speed',sp.id,'intensity',0,'blend',0,'seed',0)) > 2;
    if bad > 0 then raise exception '% pattern/speed pairs exceed 2 flashes a second', bad; end if;
    if public.founder_ambient_effective_rate('{"palette":0,"pattern":0,"speed":19,"intensity":0,"blend":0,"seed":0}'::jsonb) <> 0 then raise exception 'a still look must not flash'; end if;
    if public.founder_ambient_effective_rate('{"palette":0,"pattern":23,"speed":19,"intensity":0,"blend":0,"seed":0}'::jsonb) <> 2 then raise exception 'Heartbeat at top speed must be capped at 2'; end if;
    if (public.founder_ambient_describe(recipe) ->> 'effective_flashes_per_sec')::numeric > 2 then raise exception 'describe must show the capped rate'; end if;
    r := r || 'flash cap (480 pairs) OK; ';

    -- neighbours: n+1..n+k and n-1..n-k, in order, wrapping at both ends; every neighbour is a valid look
    j := public.founder_ambient_neighbours(recipe, 4);
    if jsonb_array_length(j -> 'next') <> 4 or jsonb_array_length(j -> 'previous') <> 4 then raise exception 'neighbours shape: %', j; end if;
    if (j -> 'next' -> 0 -> 'recipe') <> public.founder_ambient_step(recipe, 1) or (j -> 'previous' -> 0 -> 'recipe') <> public.founder_ambient_step(recipe, -1)
       or (j -> 'next' -> 3 -> 'recipe') <> public.founder_ambient_step(recipe, 4) or (j -> 'previous' -> 3 -> 'recipe') <> public.founder_ambient_step(recipe, -4) then raise exception 'neighbours out of order'; end if;
    j2 := public.founder_ambient_neighbours(public.founder_ambient_at(0), 2);
    if (j2 -> 'previous' -> 0 ->> 'n')::bigint <> v_total - 1 then raise exception 'previous of look 0 must wrap to the last look'; end if;
    if jsonb_array_length(public.founder_ambient_neighbours(recipe, 999) -> 'next') <> 12 then raise exception 'neighbour count must be limited to 12'; end if;
    r := r || 'neighbours OK; ';

    -- surprise: deterministic, valid, spread out (500 different numbers give at least 495 different looks)
    if public.founder_ambient_surprise(42) <> public.founder_ambient_surprise(42) then raise exception 'surprise must be deterministic'; end if;
    if not public._fa_recipe_valid(public.founder_ambient_surprise(-9223372036854775807)) or not public._fa_recipe_valid(public.founder_ambient_surprise(0)) then raise exception 'surprise gave an invalid look'; end if;
    select count(distinct public.founder_ambient_surprise(i)::text) into bad from generate_series(1, 500) i;
    if bad < 495 then raise exception 'surprise is not spread out (% distinct of 500)', bad; end if;
    if not public._fs_fails($q$select public.founder_ambient_surprise(null)$q$) then raise exception 'surprise accepted a null'; end if;
    r := r || 'surprise OK; ';

    -- the history replay and the Time machine still agree with the live table, drift still answers, chain clean
    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check dirty: %', public.founder_settings_replay_check(u); end if;
    if public.founder_settings_crosscheck(u) not like 'E113 crosscheck OK%' then raise exception 'crosscheck: %', public.founder_settings_crosscheck(u); end if;
    if (public.founder_settings_drift(u) ->> 'score')::integer not between 0 and 100 then raise exception 'drift broken'; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    r := r || 'replay+drift+chain OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E114 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> b_set or (select count(*) from public.founder_settings_history) <> b_hist or (select count(*) from public.founder_audit) <> b_audit
     or (select count(*) from public.founder_settings_revert_log) <> b_rev or (select count(*) from public.founder_settings_schedule) <> b_sch then
    raise exception 'E114 selftest left rows behind';
  end if;
  return 'E114 selftest OK — ' || r || 'rollback clean';
end $$;

-- ==============================================================================================================================
-- 8) selftest2 — structure, privileges, hygiene
-- ==============================================================================================================================
create or replace function public.founder_appearance_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r text := ''; t text; f text; v_n integer;
begin
  foreach t in array array['public.founder_setting_registry','public.founder_ambient_palettes','public.founder_ambient_patterns','public.founder_ambient_blends','public.founder_ambient_speeds','public.founder_ambient_intensities'] loop
    if to_regclass(t) is null then raise exception 'table missing: %', t; end if;
    if not (select relrowsecurity from pg_class where oid = to_regclass(t)) then raise exception 'RLS off on %', t; end if;
    if has_table_privilege('anon', t, 'select') or has_table_privilege('authenticated', t, 'select') then raise exception 'anon/authenticated can read %', t; end if;
    if has_table_privilege('service_role', t, 'insert') or has_table_privilege('service_role', t, 'update') or has_table_privilege('service_role', t, 'delete') then raise exception 'service_role can write to the read-only registry %', t; end if;
    if not has_table_privilege('service_role', t, 'select') then raise exception 'service_role cannot read %', t; end if;
  end loop;
  r := r || 'tables+RLS+read-only OK; ';
  foreach f in array array['public.founder_ambient_total()','public.founder_ambient_index(jsonb)','public.founder_ambient_at(bigint)','public.founder_ambient_step(jsonb,bigint)',
                           'public.founder_ambient_describe(jsonb)','public.founder_ambient_catalog()','public.founder_setting_registry_list()','public.founder_setting_set(uuid,text,jsonb)',
                           'public.founder_settings_history_list(uuid,text,bigint,integer)'] loop
    if to_regprocedure(f) is null then raise exception 'function missing: %', f; end if;
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') or has_function_privilege('public', f, 'execute') then raise exception 'function open to the public: %', f; end if;
    if not has_function_privilege('service_role', f, 'execute') then raise exception 'service_role cannot run %', f; end if;
  end loop;
  r := r || 'function grants OK; ';
  select count(*) into v_n from pg_proc p where p.oid in (to_regprocedure('public.founder_ambient_at(bigint)'), to_regprocedure('public.founder_ambient_step(jsonb,bigint)'), to_regprocedure('public.founder_ambient_index(jsonb)'),
        to_regprocedure('public.founder_ambient_catalog()'), to_regprocedure('public.founder_ambient_describe(jsonb)'))
     and p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(p.proconfig) c where c like 'statement_timeout=%');
  if v_n <> 5 then raise exception 'security definer functions must pin search_path and statement_timeout (%/5)', v_n; end if;
  r := r || 'definer hygiene OK; ';
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_key_fk' and conrelid = 'public.founder_settings'::regclass) then raise exception 'founder_settings.key is not tied to the registry'; end if;
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_schedule_key_fk' and conrelid = 'public.founder_settings_schedule'::regclass) then raise exception 'schedule.key is not tied to the registry'; end if;
  if exists (select 1 from pg_constraint where conrelid = 'public.founder_settings'::regclass and conname = 'founder_settings_key_registry') then raise exception 'the old fixed key list is still there'; end if;
  r := r || 'foreign keys OK; ';
  if (select count(*) from public.founder_setting_registry where area = 'appearance') <> 11 then raise exception 'appearance should have 11 keys (9 new + graphics + sidebar)'; end if;
  r := r || 'appearance coverage OK; ';
  return 'E114 selftest2 OK — ' || r || 'done';
end $$;


-- ==============================================================================================================================
-- 8b) E113's selftest2 assumed exactly 5 keys (the E108 list). The registry is now the one list, so the test reads it instead.
--     Same checks otherwise. (E113 itself is left untouched: the server keeps a sha ledger of files already run.)
-- ==============================================================================================================================
create or replace function public.founder_settings_s2_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r text := ''; t text; f text; v_n integer;
begin
  foreach t in array array['public.founder_settings_revert_log','public.founder_settings_schedule','public.founder_settings_info','public.founder_settings_baseline'] loop
    if to_regclass(t) is null then raise exception 'table missing: %', t; end if;
    if not (select relrowsecurity from pg_class where oid = to_regclass(t)) then raise exception 'RLS off on %', t; end if;
    if has_table_privilege('anon', t, 'select') or has_table_privilege('authenticated', t, 'select') or has_table_privilege('anon', t, 'insert') or has_table_privilege('authenticated', t, 'insert') then raise exception 'anon/authenticated can reach %', t; end if;
  end loop;
  if has_table_privilege('service_role', 'public.founder_settings_info', 'insert') or has_table_privilege('service_role', 'public.founder_settings_baseline', 'update') then raise exception 'registries must be read-only for service_role'; end if;
  if has_table_privilege('service_role', 'public.founder_settings_revert_log', 'update') or has_table_privilege('service_role', 'public.founder_settings_revert_log', 'delete') then raise exception 'revert log must be append-only for service_role'; end if;
  if has_table_privilege('service_role', 'public.founder_settings_schedule', 'delete') then raise exception 'service_role must not delete schedule rows'; end if;
  r := r || 'tables+RLS+grants OK; ';
  foreach f in array array[
      'public.founder_settings_history_list(uuid,text,bigint,integer)','public.founder_setting_revert(uuid,bigint,text)','public.founder_settings_at(uuid,timestamptz)',
      'public.founder_settings_diff(uuid,timestamptz,timestamptz)','public.founder_settings_replay_check(uuid)','public.founder_settings_timeline(uuid,integer)',
      'public.founder_settings_drift(uuid)','public.founder_setting_explain(text)','public.founder_setting_blast(uuid,text)',
      'public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)','public.founder_settings_schedule_cancel(uuid,uuid,text)',
      'public.founder_settings_schedule_confirm(uuid,uuid,text)','public.founder_settings_schedule_tick(timestamptz)','public.founder_settings_schedule_preview(timestamptz)',
      'public.founder_settings_schedule_list(uuid,integer)','public.founder_settings_pulse(uuid)','public.founder_settings_crosscheck(uuid)'] loop
    if to_regprocedure(f) is null then raise exception 'rpc missing: %', f; end if;
    if has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute') or has_function_privilege('public', f, 'execute') then raise exception 'rpc open to the public: %', f; end if;
    if not has_function_privilege('service_role', f, 'execute') then raise exception 'service_role cannot run %', f; end if;
  end loop;
  r := r || 'rpc grants OK; ';
  select count(*) into v_n from pg_proc p where p.oid = any (array[to_regprocedure('public.founder_setting_revert(uuid,bigint,text)'), to_regprocedure('public.founder_settings_schedule_tick(timestamptz)'),
        to_regprocedure('public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)'), to_regprocedure('public.founder_settings_drift(uuid)'),
        to_regprocedure('public.founder_settings_history_list(uuid,text,bigint,integer)')])
     and p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(p.proconfig) c where c like 'statement_timeout=%');
  if v_n <> 5 then raise exception 'security definer functions must pin search_path and statement_timeout (%/5)', v_n; end if;
  r := r || 'definer hygiene OK; ';
  if (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_settings_schedule') and tgname in ('founder_settings_schedule_guard','founder_settings_schedule_no_trunc')) <> 2 then raise exception 'schedule triggers missing'; end if;
  if (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_settings_revert_log') and tgname in ('founder_settings_revert_log_no_upd','founder_settings_revert_log_no_trunc')) <> 2 then raise exception 'revert log triggers missing'; end if;
  r := r || 'triggers OK; ';
  if exists (select 1 from public.founder_settings_info i where not exists (select 1 from public.founder_setting_registry r where r.key = i.key)) then raise exception 'info has a key outside the registry'; end if;
  if exists (select 1 from public.founder_setting_registry r where not exists (select 1 from public.founder_settings_info i where i.key = r.key)) then raise exception 'every registry key needs an info row'; end if;
  r := r || 'registry coverage OK; ';
  if not exists (select 1 from public.founder_live_sources where key = 'settings_history') then raise exception 'live source missing'; end if;
  r := r || 'live source OK; ';
  return 'E113 selftest2 OK — registry-aware (E114); ' || r || 'done';
end $$;
revoke all on function public.founder_settings_s2_selftest2() from public, anon, authenticated;
grant execute on function public.founder_settings_s2_selftest2() to service_role;

do $$ begin
  perform public._fs_noop_probe();
exception when undefined_function then null;
end $$;

-- grants for the selftests (functions exist now)
do $$
declare f text;
begin
  foreach f in array array['public.founder_appearance_selftest()','public.founder_appearance_selftest2()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ==============================================================================================================================
-- 9) run the selftests now (output shows in sql-run.sh)
-- ==============================================================================================================================
do $$ begin
  raise notice '%', public.founder_appearance_selftest();
  raise notice '%', public.founder_appearance_selftest2();
  raise notice 'E114 ambient looks in the catalog: %', public.founder_ambient_total();
end $$;

-- ==============================================================================================================================
-- RUNBOOK (comments only)
-- ==============================================================================================================================
-- Run:        bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E114_founder_appearance_ambient CHECK_E114   (after the usual fetch)
-- Order:      E102 -> E107 -> E108 -> E109 -> E113 -> E114. E114 is safe to run again (create-if-not-exists, create-or-replace, upserts).
-- Rust:       settings.rs REGISTRY grows to the same 14 keys (first line of defence mirrors the SQL); settings_s2.rs SCHEDULABLE adds the new schedulable keys;
--             new signed reads: ambient catalog / describe / step / at / index (answers of founder_ambient_*).
-- UI:         Appearance tab = the awam controls (instant, no save button) + Ambient Studio (prev/next, arrow keys, wheel, swipe; Enter keeps; favourites; look number shown).
--             Look rendering = one shader whose uniforms are the recipe; lazy chunk; frame-time guard; Graphics off / OS reduced-motion = still wash. Nothing is stored as an image.
-- Undo plan:  founder_settings.key FK -> drop and re-add the E108 CHECK (only if no new key was ever stored); drop the founder_ambient_* tables and functions.
