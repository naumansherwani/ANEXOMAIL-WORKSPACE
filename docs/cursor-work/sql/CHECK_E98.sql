
-- CHECK E98 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E98 kernel 0.3.0 release darj aur current' as item,
       exists (select 1 from public.kernel_releases where version = '0.3.0' and status = 'current') as ok, 1 as n
union all select 'E98 release ka sha256 repo ki pin se mel khata hai',
       exists (select 1 from public.kernel_releases where version = '0.3.0' and wasm_sha256 = 'd19eded45df6e6ae421ad2b209b33352ed701f1970d5c0dacbdd46669a873482'), 2
union all select 'E98 modules mein intent@1',
       exists (select 1 from public.kernel_releases where version = '0.3.0' and 'intent@1' = any(modules)), 3
union all select 'E98 kernel_modules mein intent',
       exists (select 1 from public.kernel_modules where name = 'intent' and version = 1), 4
union all select 'E98 constitution ab bhi theek',
       coalesce((public.kernel_constitution_ok()->>'ok')::boolean, false), 5
) t order by n;
