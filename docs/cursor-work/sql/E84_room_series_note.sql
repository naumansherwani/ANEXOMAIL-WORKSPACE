
-- E84 — Tarteeb ka number (founder hukm 24 Oct 2026: SQL ki tarteeb nahi tootni). E83 ke baad, E85 se pehle. Dobara chalana safe.
-- Is number ka asli kaam Rust-only tha: repeat-series ka room check (rooms_core/glue) — us ke liye naya table/column nahi chahiye.
-- SQL ka hissa: sirf yeh note E83 ke guard function par (comment), taake DB se bhi dikhe ke series check Rust mein hai aur guard sirf pehla slot dekhta hai.
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regprocedure('public.calendar_room_guard(uuid,text,timestamptz,timestamptz)') is null then
    raise exception 'E84 PREFLIGHT: calendar_room_guard nahi — pehle E83 chalayen' using errcode = 'AX084';
  end if;
end $$;

comment on function public.calendar_room_guard(uuid, text, timestamptz, timestamptz) is 'E83 guard: sirf stored pehla slot check karta hai. E84 (Rust rooms module): repeat-series ke baqi slots ka room check Rust mein.';
