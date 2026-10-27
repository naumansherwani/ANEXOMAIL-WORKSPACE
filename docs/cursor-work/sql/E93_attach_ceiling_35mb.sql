
-- E93 — attachment ki server ceiling 18 MiB (E49) -> 35 MiB (36_700_160 bytes) taa ke Pro ka vaada (35 MB) asli ho.
--  Asli limit = least(storage_plans.max_send_bytes, mail_attach_limits.server_ceiling_bytes): Basic 25 MB, Pro 35 MB tab hi dikhega jab ceiling 35 MB ho.
--  SHART: pehle `attach-limit-measure.sh` chalao. Pro "SAFE" na aaye (Postfix ya clamd chhota) to yeh SQL mat chalao.
--  36_700_160 * 4/3 + 200_000 = 49_133_546 < Postfix 52_428_800 (20 Oct ka naapa hua). clamd StreamMaxLength >= 36_700_160 hona chahiye.
--  Business 45 / Business Pro 60 MB: Postfix limit badhane ke baad alag SQL (TODO-1) — yahan nahi.
-- Dobara chalana safe. Rollback: update mail_attach_limits set value=18874368 where key='server_ceiling_bytes';
set lock_timeout = '5s';
set statement_timeout = '30s';
set search_path = public, extensions;

do $$ declare cur bigint; pro bigint;
begin
  if to_regclass('public.mail_attach_limits') is null then raise exception 'E93 PREFLIGHT: mail_attach_limits nahi (E48)'; end if;
  select value into cur from public.mail_attach_limits where key = 'server_ceiling_bytes';
  if cur is null then raise exception 'E93 PREFLIGHT: server_ceiling_bytes row nahi (E48/E49)'; end if;
  select max_send_bytes into pro from public.storage_plans where plan_id = 'pro';
  if pro is distinct from 36700160 then raise exception 'E93 PREFLIGHT: pro max_send_bytes 36700160 nahi (E88 pehle)'; end if;
end $$;

update public.mail_attach_limits
   set value = 36700160,
       note = 'raw bytes per message (E93: 35 MiB = Pro vaada); value*4/3 + 200000 must stay under Postfix message_size_limit AND <= clamd StreamMaxLength',
       updated_at = now()
 where key = 'server_ceiling_bytes' and value is distinct from 36700160;
