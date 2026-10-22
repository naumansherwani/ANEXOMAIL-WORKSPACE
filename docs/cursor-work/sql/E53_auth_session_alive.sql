
-- E53 — Rust local-JWT verify ke liye: "yeh login session abhi zinda hai?" (B1, 21 Oct 2026)
-- Sach ka ek hi source: Supabase `auth.sessions`. Logout (admin.signOut) aur device revoke (E47 device_trust_set) usi row ko DELETE
-- karte hain; isliye JWT ki signature local jaanchne ke baad bhi yeh row dekhna ZAROORI hai — warna "sign out everywhere" jhoota ho jata.
-- Sirf service_role (Rust engine) chala sakta hai. Dobara chalana safe.
create or replace function public.auth_session_alive(_sid uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from auth.sessions s
     where s.id = _sid
       and (s.not_after is null or s.not_after > now())
  );
$$;
revoke all on function public.auth_session_alive(uuid) from public, anon, authenticated;
grant execute on function public.auth_session_alive(uuid) to service_role;
