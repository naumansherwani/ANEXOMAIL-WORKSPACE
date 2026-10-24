
-- CHECK E84 — Sirf padhta hai.
select coalesce((select obj_description('public.calendar_room_guard(uuid,text,timestamptz,timestamptz)'::regprocedure, 'pg_proc') like '%E84%'), false) as ok;
