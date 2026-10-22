
-- E49 — ek mail mein attachments ki hadd 7 MB se 18 MB (raw) tak — G38 — 20 Oct 2026 (founder "haan" 21:38 PKT)
-- Hisaab: 18_874_368 raw -> base64 ~25.2 MB (Gmail ki 25 MB jaisi hadd). Server ka Postfix `message_size_limit` = 52_428_800 (attach-check.sh ne
-- 20 Oct 21:38 par dikhaya) => mehfooz raw hadd 39_171_600 — yeh qeemat uske andar hai, Postfix ko haath nahi lagta.
-- Asal hadd har package ke liye = min(plan ka max_send_bytes, yeh qeemat). Dobara chalana safe.
set search_path = public, extensions;
insert into public.mail_attach_limits (key, value, note)
values ('server_ceiling_bytes', 18874368, 'raw bytes per message; value*4/3 + 200000 must stay under Postfix message_size_limit (52428800 on 20 Oct 2026)')
on conflict (key) do update set value = excluded.value, note = excluded.note, updated_at = now();
select key, value from public.mail_attach_limits where key = 'server_ceiling_bytes';
