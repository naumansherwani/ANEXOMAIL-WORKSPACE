
-- E64 — calendar #10 HISTORY SEARCH: saalon purani meetings (+ unke notes, guests, Aim) ek search mein, tareekh range aur "kis ke saath" ke saath (22 Oct 2026).
-- E58..E63 ke baad chalti hai. Dobara chalana safe. Koi DROP TABLE/COLUMN nahi. Koi nayi table nahi — sirf functions + indexes.
-- Sach ka usool: sirf wohi history jo ANEXOMAIL mein hai. Koi "relevance %" nahi; sirf: kya mila, kahan mila (title/agenda/location/aim/notes/guest), kab.
-- Advance level (Rule 38 + 42):
--   * DEEWAR (DB-side): viewer us org ka zinda (revoked nahi) member ho, warna {"error":"forbidden"}. Dikhne ki hadd = calendar jitni (org ke events + org ke event-notes); doosre org ki ek row bhi nahi.
--   * Zubaan-neutral search: to_tsvector('simple') (koi stemming nahi — Urdu/Roman/English mix mein bigaadta nahi) + ILIKE (pg_trgm GIN index se tez) = aadha likha lafz ("contr") aur typo-ke-qareeb bhi mil jaye.
--   * Search ka matn EK jagah: calendar_search_text(title, agenda, location, goal) + calendar_search_doc(...) = IMMUTABLE + PARALLEL SAFE + pinned search_path; index aur query ek hi expression — isliye index sach mein istemal hota hai.
--   * Safe input: websearch_to_tsquery (user ka matn kabhi tsquery syntax nahi banta, "quotes" aur -minus chalte hain), LIKE ke % _ \ escape (q="%" sab kuch nahi lata), q <= 200 harf, control char saaf, koi dynamic SQL string mein user ka matn nahi (USING se).
--   * Hadein: limit <= 50, offset <= 1000, function par statement_timeout 8s (kharab query baaki traffic nahi rokti), snippet ke liye agenda ke sirf pehle 5000 harf.
--   * pg_trgm kisi bhi schema mein ho (Supabase: extensions) — opclass uska asli schema dhoond kar banta hai; extension na bane to function phir bhi chalta hai (sirf dheema).
--   * work_notes (event notes) agar maujood hai to unmein bhi dhoondta hai; nahi hai to chup-chaap chhor deta hai (test DB).
--   * Indexes (non-concurrent, lock_timeout ke andar; bari live table ho to haath se CONCURRENTLY alag note ke saath): events FTS + trigram, (org_id, starts_at desc) saari rows (cancelled bhi), work_notes FTS. Attendee side ka index (lower(address), event_id) pehle se maujood.
--   * Sirf service_role (Rust) execute kar sakta hai; anon/authenticated nahi.
--   * Dohrane wali meetings: master EK baar (recurring=true), har occurrence nahi (hazaron row nahi). Cancelled bhi aati hain, `status: cancelled` ke saath.
--   * WAPAS LENA (haath se, yahan chalta nahi): drop function public.calendar_history(uuid,uuid,text,timestamptz,timestamptz,text,text,integer,integer,timestamptz,uuid,boolean); drop function public.calendar_org_member(uuid,uuid); drop function public.calendar_search_doc(text,text,text,text); drop function public.calendar_search_text(text,text,text,text); drop function public.calendar_guest_text(text,text); aur calendar_events_search_*_idx, calendar_events_org_start_all_idx, work_notes_search_idx.
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. matn ki ek hi definition ----------------------------------------------------------------------------------------------
create or replace function public.calendar_search_text(p_title text, p_agenda text, p_location text, p_goal text)
returns text language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select concat_ws(' ', nullif(p_title, ''), nullif(p_location, ''), nullif(p_goal, ''), nullif(left(p_agenda, 20000), ''))
$$;

create or replace function public.calendar_guest_text(p_address text, p_name text)
returns text language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select lower(concat_ws(' ', nullif(p_address, ''), nullif(p_name, '')))
$$;

create or replace function public.calendar_search_doc(p_title text, p_agenda text, p_location text, p_goal text)
returns tsvector language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select to_tsvector('simple'::regconfig, public.calendar_search_text(p_title, p_agenda, p_location, p_goal))
$$;

-- ---- 2. dewaar ka ek function (E62 wali shart) ----------------------------------------------------------------------------------
create or replace function public.calendar_org_member(p_org uuid, p_viewer uuid)
returns boolean language plpgsql stable parallel safe set search_path = pg_catalog, public as $$
begin
  if p_org is null or p_viewer is null or to_regclass('public.org_members') is null then return false; end if;
  return exists (select 1 from public.org_members m
                  where m.org_id = p_org and m.user_id = p_viewer and coalesce(m.status::text, 'active') <> 'revoked');
end $$;

-- ---- 3. PREFLIGHT + indexes ---------------------------------------------------------------------------------------------------
do $$
declare v_trgm_schema text; v_ops text;
begin
  if to_regclass('public.calendar_events') is null or to_regclass('public.calendar_attendees') is null then
    raise exception 'E64 PREFLIGHT: calendar_events / calendar_attendees maujood nahi — pehle phase61/E31 chalayen' using errcode = 'AX064';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'calendar_events' and column_name = 'goal') then
    raise exception 'E64 PREFLIGHT: calendar_events.goal nahi — pehle E63 chalayen' using errcode = 'AX064';
  end if;

  -- (a) FTS
  if to_regclass('public.calendar_events_search_fts_idx') is null then
    create index calendar_events_search_fts_idx on public.calendar_events using gin (public.calendar_search_doc(title, agenda, location, goal));
  end if;

  -- (b) trigram (ILIKE) — extension jis schema mein ho
  begin
    create extension if not exists pg_trgm;
  exception when others then
    raise notice 'E64: pg_trgm nahi bana (%). Search chalega, ILIKE dheema.', sqlerrm;
  end;
  select n.nspname into v_trgm_schema from pg_extension x join pg_namespace n on n.oid = x.extnamespace where x.extname = 'pg_trgm';
  if v_trgm_schema is not null and to_regclass('public.calendar_events_search_trgm_idx') is null then
    v_ops := format('%I.gin_trgm_ops', v_trgm_schema);
    execute format('create index calendar_events_search_trgm_idx on public.calendar_events using gin (public.calendar_search_text(title, agenda, location, goal) %s)', v_ops);
  end if;

  if v_trgm_schema is not null and to_regclass('public.calendar_attendees_guest_trgm_idx') is null then
    execute format('create index calendar_attendees_guest_trgm_idx on public.calendar_attendees using gin (public.calendar_guest_text(address, display_name) %I.gin_trgm_ops)', v_trgm_schema);
  end if;

  -- (c) tareekh se browse: saari rows (cancelled bhi) — purana live-time index partial hai
  if to_regclass('public.calendar_events_org_start_all_idx') is null then
    create index calendar_events_org_start_all_idx on public.calendar_events (org_id, starts_at desc);
  end if;

  -- (d) event notes
  if to_regclass('public.work_notes') is not null
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'work_notes' and column_name = 'body')
     and to_regclass('public.work_notes_search_idx') is null then
    create index work_notes_search_idx on public.work_notes using gin (to_tsvector('simple'::regconfig, coalesce(body, ''))) where event_id is not null;
  end if;
end $$;

-- ---- 4. history ---------------------------------------------------------------------------------------------------------------------
-- 100 SAAL KE LIYE BANAYA: tareekh ki koi hadd nahi (1900 ya 2126 — timestamptz), jitni purani history ho utni milti hai.
-- p_order: 'recent' (naye pehle, default) | 'oldest' | 'relevance' (jitni zyada jagah mile).
-- Paging: recent/oldest = KEYSET (cursor = (starts_at, id) jo pichle page ka "next" tha) — kisi bhi gehrai par har page barabar tez, offset ki hadd nahi.
--         relevance = offset (<= 1000), kyunke wahan tarteeb (score, tareekh) hai. (offset har order mein chalta hai, par gehri history ke liye cursor.)
-- p_facets: true to pehle page par saal-ba-saal ginti ("by_year": {"2006": 3, ...}) — matn + banda ke hisaab se, tareekh ki range nazar-andaaz,
--           taake poori history ka naksha ek nazar mein dikhe.
-- HYBRID: milne wali ids <= 2000 => index se ids materialize; zyada ("meeting" jaisa aam lafz) => date index par chalo aur seedha filter.
-- Returns {"events":[...], "has_more":bool, "next":{"ts","id"}|null, "by_year":{..}|null, ...} ya {"error":"forbidden"|"empty_query"|"bad_range"|"bad_cursor"}.
drop function if exists public.calendar_history(uuid, uuid, text, timestamptz, timestamptz, text, text, integer, integer);
create or replace function public.calendar_history(
  p_org uuid, p_viewer uuid, p_q text, p_from timestamptz, p_to timestamptz, p_person text,
  p_order text default 'recent', p_limit integer default 20, p_offset integer default 0,
  p_after_ts timestamptz default null, p_after_id uuid default null, p_facets boolean default false)
returns jsonb language plpgsql stable parallel safe set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare
  v_q      text;
  v_like   text;
  v_tsq    tsquery;
  v_person text;
  v_plike  text;
  v_limit  integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000);
  v_notes  boolean := false;
  v_order  text;
  v_sql    text;
  v_rows   jsonb;
  v_n      integer;
  v_body_t text;          -- match-ids query template: events matn | guests | notes; '@@U@@' = union / union all
  v_body   text;
  v_probe  text;
  v_cte    text := '';
  v_where  text;
  v_common boolean := false;
  v_cursor text := '';
  v_years  jsonb := null;
  v_next   jsonb := null;
  v_events jsonb;
  v_last   jsonb;
begin
  if not public.calendar_org_member(p_org, p_viewer) then return jsonb_build_object('error', 'forbidden'); end if;
  if p_from is not null and p_to is not null and p_to <= p_from then return jsonb_build_object('error', 'bad_range'); end if;
  if (p_after_ts is null) <> (p_after_id is null) then return jsonb_build_object('error', 'bad_cursor'); end if;   -- aadha cursor andaza nahi lagate

  -- saaf matn: control char -> space, spaces ikatthe, <= 200
  v_q := nullif(left(btrim(regexp_replace(coalesce(p_q, ''), '[\x01-\x1f\x7f]+', ' ', 'g')), 200), '');
  if v_q is not null and char_length(v_q) < 2 then v_q := null; end if;
  v_person := nullif(left(btrim(regexp_replace(coalesce(p_person, ''), '[\x01-\x1f\x7f]+', ' ', 'g')), 120), '');
  if v_person is not null and char_length(v_person) < 2 then v_person := null; end if;

  -- itna khaali sawal poori history nahi ugalta: kam az kam matn, banda, ya tareekh ki range
  if v_q is null and v_person is null and p_from is null and p_to is null then
    return jsonb_build_object('error', 'empty_query');
  end if;

  if v_q is not null then
    v_like := '%' || replace(replace(replace(lower(v_q), '\', '\\'), '%', '\%'), '_', '\_') || '%';
    v_tsq := websearch_to_tsquery('simple'::regconfig, v_q);
  end if;
  if v_person is not null then
    v_plike := '%' || replace(replace(replace(lower(v_person), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  v_notes := to_regclass('public.work_notes') is not null
             and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'work_notes' and column_name = 'body');
  v_order := case when p_order = 'oldest' then 'oldest' when p_order = 'relevance' and v_q is not null then 'relevance' else 'recent' end;

  -- static shape; user ka matn sirf $n parameters ke zariye aata hai
  if v_q is not null then
    -- Har source apne index se (OR mein correlated exists() bitmap-or tod deta hai): events matn | guest | notes.
    v_body_t := $m$
      select e.id from public.calendar_events e
       where e.org_id = $3
         and (public.calendar_search_doc(e.title, e.agenda, e.location, e.goal) @@ $2::tsquery
              or public.calendar_search_text(e.title, e.agenda, e.location, e.goal) ilike $1 escape '\')
      @@U@@
      select a.event_id from public.calendar_attendees a
       where a.org_id = $3 and public.calendar_guest_text(a.address, a.display_name) like $1 escape '\'$m$
      || case when v_notes then $n$
      @@U@@
      select n.event_id from public.work_notes n
       where n.org_id = $3 and n.event_id is not null and to_tsvector('simple'::regconfig, coalesce(n.body, '')) @@ $2::tsquery$n$ else '' end;
    v_body  := replace(v_body_t, '@@U@@', 'union');
    v_probe := replace(v_body_t, '@@U@@', 'union all');   -- limit 2001 par jaldi ruk jata hai (union ko poora hash karna padta)

    execute 'select count(*) > 2000 from (select u.id from (' || v_probe || ') u limit 2001) x' into v_common using v_like, v_tsq, p_org;
  end if;

  -- aam lafz (2000+ barabar ke matches) par "relevance" ka matlab nahi (sab barabar) aur har row ka score nikalna sekondon leta hai => naye pehle
  if v_common and v_order = 'relevance' then v_order := 'recent'; end if;

  if v_q is null then
    v_where := 'true';
  elsif not v_common then
    v_cte := 'm as materialized (' || v_body || '), ';
    v_where := 'e.id in (select id from m)';
  else
    v_where := '(public.calendar_search_doc(e.title, e.agenda, e.location, e.goal) @@ $2::tsquery'
            || ' or public.calendar_search_text(e.title, e.agenda, e.location, e.goal) ilike $1 escape ''\'''
            || ' or exists (select 1 from public.calendar_attendees a where a.event_id = e.id and public.calendar_guest_text(a.address, a.display_name) like $1 escape ''\'')'
            || case when v_notes then ' or exists (select 1 from public.work_notes n where n.org_id = e.org_id and n.event_id = e.id and to_tsvector(''simple''::regconfig, coalesce(n.body, '''')) @@ $2::tsquery)' else '' end
            || ')';
  end if;

  if v_order = 'recent' then
    v_cursor := 'and ($9::timestamptz is null or (e.starts_at, e.id) < ($9::timestamptz, $10::uuid))';
  elsif v_order = 'oldest' then
    v_cursor := 'and ($9::timestamptz is null or (e.starts_at, e.id) > ($9::timestamptz, $10::uuid))';
  end if;

  v_sql := $q$
    with %s cand as (
      select e.id, e.title, e.agenda, e.location, e.goal, e.goal_state, e.starts_at, e.ends_at, e.organiser, e.cancelled_at, e.rrule, e.series_id, e.org_id,
             %s as rk
        from public.calendar_events e
       where e.org_id = $3
         and ($4::timestamptz is null or e.starts_at >= $4)
         and ($5::timestamptz is null or e.starts_at <  $5)
         and %s
         %s
         and ($6::text is null
              or exists (select 1 from public.calendar_attendees a
                          where a.event_id = e.id and public.calendar_guest_text(a.address, a.display_name) like $6 escape '\')
              or lower(coalesce(e.organiser, '')) like $6 escape '\')
       order by %s
       limit $7 offset $8
    )
    select coalesce(jsonb_agg(z.row_json order by z.ord), '[]'::jsonb), count(*)::int
      from (
        select row_number() over (order by %s) as ord,
               jsonb_build_object(
                 'id', c.id, 'title', c.title, 'starts_at', c.starts_at, 'ends_at', c.ends_at,
                 'status', case when c.cancelled_at is not null then 'cancelled' else 'confirmed' end,
                 'organiser', c.organiser, 'location', c.location,
                 'goal', c.goal, 'goal_state', c.goal_state,
                 'recurring', (c.rrule is not null and c.rrule <> '') or c.series_id is not null,
                 'matched', to_jsonb(array_remove(array[
                      case when $1::text is not null and public.calendar_search_text(c.title, null, null, null) ilike $1 escape '\' then 'title' end,
                      case when $1::text is not null and public.calendar_search_text(null, c.agenda, null, null) ilike $1 escape '\' then 'agenda' end,
                      case when $1::text is not null and public.calendar_search_text(null, null, c.location, null) ilike $1 escape '\' then 'location' end,
                      case when $1::text is not null and public.calendar_search_text(null, null, null, c.goal) ilike $1 escape '\' then 'aim' end,
                      case when %s then 'notes' end,
                      case when $1::text is not null and exists (select 1 from public.calendar_attendees a
                             where a.event_id = c.id and public.calendar_guest_text(a.address, a.display_name) like $1 escape '\') then 'guest' end
                    ], null)),
                 'snippet', case when $2::tsquery is not null and c.agenda is not null
                                      and public.calendar_search_doc(null, c.agenda, null, null) @@ $2::tsquery
                                 then nullif(ts_headline('simple'::regconfig, left(c.agenda, 5000), $2::tsquery,
                                        'MaxFragments=1, MaxWords=22, MinWords=8, StartSel=' || chr(1) || ', StopSel=' || chr(2)), '')
                            end,
                 'guest_count', (select count(*) from public.calendar_attendees a where a.event_id = c.id),
                 'guests', (select coalesce(jsonb_agg(jsonb_build_object('address', g.address, 'name', left(g.display_name, 80))), '[]'::jsonb)
                              from (select a.address, a.display_name from public.calendar_attendees a where a.event_id = c.id order by lower(a.address) limit 6) g)
               ) as row_json
          from cand c
      ) z
  $q$;
  -- tarteeb: starts_at ke saath id bhi UNIQUE tie-break (keyset cursor isi par chalta hai; dono taraf ek hi disha)
  v_sql := format(v_sql,
    v_cte,
    case when v_order = 'relevance' then 'ts_rank_cd(public.calendar_search_doc(e.title, e.agenda, e.location, e.goal), $2::tsquery)' else '0::real' end,
    v_where, v_cursor,
    case v_order when 'oldest' then 'e.starts_at asc, e.id asc' when 'relevance' then 'rk desc, e.starts_at desc, e.id desc' else 'e.starts_at desc, e.id desc' end,
    case v_order when 'oldest' then 'c.starts_at asc, c.id asc' when 'relevance' then 'c.rk desc, c.starts_at desc, c.id desc' else 'c.starts_at desc, c.id desc' end,
    case when v_notes then $n$($1::text is not null and exists (select 1 from public.work_notes n where n.org_id = c.org_id and n.event_id = c.id
                              and to_tsvector('simple'::regconfig, coalesce(n.body, '')) @@ $2::tsquery))$n$ else 'false' end);

  -- ek zyada mangwa kar has_more
  execute v_sql into v_rows, v_n
    using v_like, v_tsq, p_org, p_from, p_to, v_plike, v_limit + 1, v_offset, p_after_ts, p_after_id;

  v_events := case when v_n > v_limit
                   then (select coalesce(jsonb_agg(x order by i), '[]'::jsonb) from jsonb_array_elements(v_rows) with ordinality t(x, i) where i <= v_limit)
                   else v_rows end;

  -- agle page ka cursor (relevance mein nahi: wahan offset chalta hai)
  if v_n > v_limit and v_order <> 'relevance' then
    v_last := v_events -> (jsonb_array_length(v_events) - 1);
    v_next := jsonb_build_object('ts', v_last ->> 'starts_at', 'id', v_last ->> 'id');
  end if;

  -- saal-ba-saal naksha (sirf pehle page par, jab maanga jaye): matn + banda ke hisaab se, tareekh ki range ke baghair
  if coalesce(p_facets, false) and p_after_ts is null and v_offset = 0 then
    v_sql := 'select coalesce(jsonb_object_agg(f.y::text, f.c), ''{}''::jsonb) from ('
          || 'select extract(year from e.starts_at at time zone ''UTC'')::int as y, count(*) as c from public.calendar_events e where e.org_id = $3 and '
          || case when v_q is null then 'true' else 'e.id in (' || v_body || ')' end
          || ' and ($6::text is null or exists (select 1 from public.calendar_attendees a where a.event_id = e.id and public.calendar_guest_text(a.address, a.display_name) like $6 escape ''\'')'
          || ' or lower(coalesce(e.organiser, '''')) like $6 escape ''\'') group by 1) f';
    execute v_sql into v_years using v_like, v_tsq, p_org, p_from, p_to, v_plike;
  end if;

  return jsonb_build_object('events', v_events, 'has_more', v_n > v_limit, 'next', v_next, 'by_year', v_years,
    'q', v_q, 'person', v_person, 'order', v_order, 'limit', v_limit, 'offset', v_offset);
end $$;

revoke all on function public.calendar_search_text(text, text, text, text)  from public, anon, authenticated;
revoke all on function public.calendar_search_doc(text, text, text, text)   from public, anon, authenticated;
revoke all on function public.calendar_guest_text(text, text)               from public, anon, authenticated;
revoke all on function public.calendar_org_member(uuid, uuid)               from public, anon, authenticated;
revoke all on function public.calendar_history(uuid, uuid, text, timestamptz, timestamptz, text, text, integer, integer, timestamptz, uuid, boolean) from public, anon, authenticated;
grant execute on function public.calendar_search_text(text, text, text, text) to service_role;
grant execute on function public.calendar_search_doc(text, text, text, text)  to service_role;
grant execute on function public.calendar_guest_text(text, text)              to service_role;
grant execute on function public.calendar_org_member(uuid, uuid)              to service_role;
grant execute on function public.calendar_history(uuid, uuid, text, timestamptz, timestamptz, text, text, integer, integer, timestamptz, uuid, boolean) to service_role;

comment on function public.calendar_history(uuid, uuid, text, timestamptz, timestamptz, text, text, integer, integer, timestamptz, uuid, boolean) is
  'History search over the org''s meetings (title, agenda, location, aim, guests, event notes). Viewer must be an active org member (DB-side wall). Same visibility as the calendar itself. Max 50 rows/page; keyset paging for recent/oldest (century-scale safe); optional by_year facet.';
comment on function public.calendar_search_text(text, text, text, text) is 'One definition of the searchable text of a meeting; index and query use the same expression.';

notify pgrst, 'reload schema';
