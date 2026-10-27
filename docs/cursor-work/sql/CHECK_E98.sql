
-- CHECK E98 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E98 kernel 0.4.0 release darj aur current' as item,
       exists (select 1 from public.kernel_releases where version = '0.4.0' and status = 'current') as ok, 1 as n
union all select 'E98 release ka sha256 repo ki pin se mel khata hai',
       exists (select 1 from public.kernel_releases where version = '0.4.0' and wasm_sha256 = '7499188264a10c8da1a3f82a9ddad20cc2da791b8362b862f11b94925901f88c'), 2
union all select 'E98 modules mein intent@1 aur filectx@1',
       exists (select 1 from public.kernel_releases where version = '0.4.0' and 'intent@1' = any(modules) and 'filectx@1' = any(modules)), 3
union all select 'E98 kernel_modules mein intent aur filectx',
       (select count(*) from public.kernel_modules where name in ('intent','filectx') and version = 1) = 2, 4
union all select 'E98 constitution ab bhi theek',
       coalesce((public.kernel_constitution_ok()->>'ok')::boolean, false), 5
) t order by n;
