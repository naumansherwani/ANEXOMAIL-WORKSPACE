
-- =============================================================================
-- E99 — FILE CONTEXT (compose): email mein "the latest CRM sheet" likhte hi us file ka asli sach — kaun ne bheji, kis thread mein,
-- kitne versions, har version mein kya badla (size, content wahi ya naya) — email se bahar gaye baghair.
-- Sach sirf wahi jo database mein hai: mail_attachments (+ sha256 jo E48 ne jodi) + mail_messages (kaun/kab/thread) + mail_threads (subject).
-- "Version" = same naam ki family (v1/v2/final/copy/date hata kar) — koi file andar se nahi kholi jati, is liye diff = metadata:
--   same content (sha256 barabar) / size ka farq / kab / kisne. Asli cell-level diff yahan NAHI (jhoota claim nahi).
-- Org ke andar hi (wahi scope jo search.universal ka hai). SECURITY DEFINER, sirf service_role. Idempotent. Rule 38/42/43/44.
-- =============================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.mail_attachments') is null then raise exception 'E99 PREFLIGHT: mail_attachments nahi'; end if;
  if to_regclass('public.mail_messages') is null then raise exception 'E99 PREFLIGHT: mail_messages nahi'; end if;
  if to_regclass('public.mail_threads') is null then raise exception 'E99 PREFLIGHT: mail_threads nahi'; end if;
end $$;

set search_path = public, extensions;

alter table public.mail_attachments add column if not exists sha256 text;
alter table public.mail_attachments add column if not exists mime_type text;
alter table public.mail_attachments add column if not exists size_bytes bigint not null default 0;
create index if not exists mail_attachments_message_idx on public.mail_attachments (message_id);

-- Naam ka "khandan": extension, v2/ver3/version 4, final/latest/new/old/copy/draft/signed/updated/revised, (1), tareekh hata kar, sirf haroof/ankre.
create or replace function public.file_stem(p_name text) returns text
language sql immutable parallel safe set search_path = public as $$
  select trim(both ' ' from
           regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(regexp_replace(lower(coalesce(p_name, '')), '\([0-9]+\)', ' ', 'g'), '\.[a-z0-9]{1,5}$', ''),
                 '(^|[ _.\-])(v|ver|version|rev)[ _.\-]?[0-9]+([.][0-9]+)*($|[ _.\-])', ' ', 'g'),
               '(^|[ _.\-])(final|latest|new|old|copy|draft|signed|updated|revised|backup)($|[ _.\-])', ' ', 'g'),
             '[^a-z0-9]+', ' ', 'g'))
$$;

-- Extension ka ishara: "sheet" likhne wala xlsx/csv bhi dhoondta hai.
create or replace function public.file_kind_exts(p_token text) returns text[]
language sql immutable parallel safe set search_path = public as $$
  select case lower(coalesce(p_token, ''))
    when 'sheet' then array['xlsx','xls','csv','numbers','ods']
    when 'spreadsheet' then array['xlsx','xls','csv','numbers','ods']
    when 'budget' then array['xlsx','xls','csv']
    when 'forecast' then array['xlsx','xls','csv']
    when 'doc' then array['docx','doc','pages','odt']
    when 'document' then array['docx','doc','pages','odt','pdf']
    when 'contract' then array['pdf','docx','doc']
    when 'agreement' then array['pdf','docx','doc']
    when 'proposal' then array['pdf','docx','doc','pptx']
    when 'invoice' then array['pdf']
    when 'pdf' then array['pdf']
    when 'deck' then array['pptx','ppt','key','pdf']
    when 'slides' then array['pptx','ppt','key','pdf']
    when 'presentation' then array['pptx','ppt','key','pdf']
    else null end
$$;

-- Asli kaam: query -> upar 'p_limit' file-families, har ek ke versions (naye pehle), har version ka pichle se farq.
create or replace function public.file_context_find(p_org uuid, p_query text, p_limit int default 3) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  v_toks text[];
  v_lim  int := greatest(1, least(coalesce(p_limit, 3), 5));
  v_out  jsonb;
begin
  if p_org is null then return jsonb_build_object('ok', false, 'error', 'org_required'); end if;
  select coalesce(array_agg(t), '{}'::text[]) into v_toks
    from (select distinct t from unnest(regexp_split_to_array(lower(coalesce(p_query, '')), '[^a-z0-9]+')) t
           where length(t) >= 2 limit 6) s;
  if cardinality(v_toks) = 0 then return jsonb_build_object('ok', true, 'files', '[]'::jsonb); end if;

  with cand as (
    select a.id, a.filename, coalesce(a.size_bytes, 0) as size_bytes, a.sha256, a.mime_type,
           m.thread_id, m.sent_at, m.direction, m.from_name, m.from_address, th.subject,
           public.file_stem(a.filename) as stem
      from public.mail_attachments a
      join public.mail_messages m on m.id = a.message_id
      left join public.mail_threads th on th.id = m.thread_id
     where m.org_id = p_org
       and not exists (
             select 1 from unnest(v_toks) t
              where not coalesce(   -- NULL (naam mein extension nahi) = "match nahi", warna har bina-extension file har sawal par aa jati (live bug 27 Oct 08:3x)
                    a.filename ilike '%' || t || '%'
                 or (public.file_kind_exts(t) is not null
                     and lower(substring(a.filename from '\.([A-Za-z0-9]{1,5})$')) = any (public.file_kind_exts(t))), false))
  ), fam as (
    select c.*,
           row_number() over (partition by stem order by sent_at desc nulls last, id)  as rn,
           count(*)     over (partition by stem)                                       as n,
           lead(sha256)     over (partition by stem order by sent_at desc nulls last, id) as older_sha,
           lead(size_bytes) over (partition by stem order by sent_at desc nulls last, id) as older_size,
           max(sent_at) over (partition by stem)                                       as fam_last
      from cand c
  ), top as (
    select distinct stem, fam_last from fam order by fam_last desc nulls last, stem limit v_lim
  )
  select coalesce(jsonb_agg(f.obj order by f.fam_last desc nulls last), '[]'::jsonb) into v_out
    from (
      select t.stem, t.fam_last,
             jsonb_build_object(
               'stem', t.stem,
               'total_versions', max(fm.n),
               'latest', (array_agg(to_jsonb(fm.id) order by fm.rn))[1],
               'versions', jsonb_agg(jsonb_build_object(
                   'id', fm.id, 'filename', fm.filename, 'version', fm.n - fm.rn + 1, 'size_bytes', fm.size_bytes,
                   'sent_at', fm.sent_at, 'thread_id', fm.thread_id, 'thread_subject', fm.subject, 'direction', fm.direction,
                   'by_name', fm.from_name, 'by_address', fm.from_address,
                   'same_as_older', case when fm.older_sha is null or fm.sha256 is null then null else fm.sha256 = fm.older_sha end,
                   'size_delta', case when fm.older_size is null then null else fm.size_bytes - fm.older_size end
                 ) order by fm.rn) filter (where fm.rn <= 6)
             ) as obj
        from top t join fam fm on fm.stem = t.stem
       group by t.stem, t.fam_last
    ) f;

  return jsonb_build_object('ok', true, 'files', coalesce(v_out, '[]'::jsonb));
end $$;

revoke all on function public.file_stem(text), public.file_kind_exts(text) from public, anon, authenticated;
grant execute on function public.file_stem(text), public.file_kind_exts(text) to service_role;
revoke all on function public.file_context_find(uuid, text, int) from public, anon, authenticated;
grant execute on function public.file_context_find(uuid, text, int) to service_role;

-- SELF-TEST: file_stem aur ek asli (lekin dummy org ke) fitting.
do $$
declare v jsonb; f jsonb; n int;
begin
  if public.file_stem('CRM Sheet v2.xlsx') <> 'crm sheet' or public.file_stem('CRM_sheet_FINAL (1).xlsx') <> 'crm sheet'
     or public.file_stem('Q3-budget-2026-10-12.pdf') <> 'q3 budget 2026 10 12' then
    raise exception 'E99 SELFTEST: file_stem % / % / %', public.file_stem('CRM Sheet v2.xlsx'), public.file_stem('CRM_sheet_FINAL (1).xlsx'), public.file_stem('Q3-budget-2026-10-12.pdf');
  end if;
  if public.file_kind_exts('sheet') is null or public.file_kind_exts('banana') is not null then raise exception 'E99 SELFTEST: file_kind_exts'; end if;
  v := public.file_context_find('00000000-0000-4000-8000-0000000e9900', 'crm sheet', 3);
  if (v->>'ok')::boolean is not true or jsonb_array_length(v->'files') <> 0 then raise exception 'E99 SELFTEST: khali org par kuch nahi aana chahiye %', v; end if;
  if (public.file_context_find(null, 'x', 3)->>'error') <> 'org_required' then raise exception 'E99 SELFTEST: org_required'; end if;
end $$;

notify pgrst, 'reload schema';
