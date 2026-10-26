
-- DIAG (read-only, sab kuch rollback): pipeline UPDATE ka asli DB error dikhata hai. Koi data nahi badalta.
set lock_timeout = '5s';
set statement_timeout = '30s';
create or replace function pg_temp.crm_diag() returns text language plpgsql as $$
declare sc text; pid uuid; r jsonb;
begin
  select p.scope, p.id into sc, pid from public.crm_pipelines p where p.is_default order by p.created_at limit 1;
  if pid is null then return 'no default pipeline row'; end if;
  begin
    r := public.crm_pipeline_save(sc, pid, (select name from public.crm_pipelines where id = pid),
      (select jsonb_agg(jsonb_build_object('key', key, 'label', label, 'probability', probability, 'kind', kind) order by position) from public.crm_pipeline_stages where pipeline_id = pid), 'diag', 1);
    raise exception 'DIAG_ROLLBACK %', r;
  exception when others then
    return 'result: ' || sqlerrm || ' | sqlstate ' || sqlstate;
  end;
end $$;
select pg_temp.crm_diag() as diag;
