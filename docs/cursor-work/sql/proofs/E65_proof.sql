-- E65 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -f E65_proof.sql
begin;
create table public.zz_new_tbl (id int);
select 'event trigger: nayi table RLS ON', relrowsecurity from pg_class where oid='public.zz_new_tbl'::regclass;
create temp table zz_tmp (id int);
create table public.zz_q (id int primary key);
select 'create-table-as bhi', relrowsecurity from (select 1) x, pg_class where oid='public.zz_q'::regclass;
alter table public.zz_new_tbl disable row level security;
grant select on public.zz_new_tbl to anon;
\i ../E65_rls_and_advisor_sweep.sql
select 'dobara sweep: RLS ON', relrowsecurity, has_table_privilege('anon','public.zz_new_tbl','select') as anon_haq, exists(select 1 from pg_policy where polrelid='public.zz_new_tbl'::regclass) as policy from pg_class where oid='public.zz_new_tbl'::regclass;
rollback;
