
-- CHECK E177C (diagnostic, writes nothing): the failing checks inside the E167 selftest on his server.
select coalesce(c ->> 'name', '?') as item, false as ok from jsonb_array_elements(public.fmail_selftest167() -> 'checks') c where coalesce((c ->> 'ok')::boolean, false) = false
union all select 'E167 selftest: only the rows above are failing', true;
