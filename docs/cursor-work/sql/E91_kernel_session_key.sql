
-- ============================================================================
-- E91 — KERNEL SESSION KEY (E90 Article: request tag). Rust :3200 (Tokio) ticket se session key nikalta hai, ek baar cache karta hai,
-- phir har WebTransport request ka HMAC-SHA256 tag LOCALLY verify karta hai (DB roundtrip har call par nahi).
-- Key sirf service_role ko; browser ko wahi key kernel.ticket se TLS par milti hai. Secret (server_secret) kabhi bahar nahi nikalta.
-- Idempotent (create or replace). RLS: koi table nahi badli. Pehle E90 chali honi chahiye.
-- ============================================================================
create or replace function public.kernel_session_key(p_ticket text, p_host text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare v jsonb; parts text[]; body text; skey text;
begin
  v := public.kernel_ticket_verify(p_ticket, p_host);
  if not coalesce((v->>'ok')::boolean, false) then
    return jsonb_build_object('ok', false, 'reason', coalesce(v->>'reason', 'invalid'));
  end if;
  parts := string_to_array(p_ticket, '.');
  body := parts[2] || '|' || parts[3] || '|' || parts[4] || '|' || lower(btrim(p_host));
  skey := split_part(public.kernel_hmac_sign('ticket', 'session-key:' || body), '.', 2);
  return jsonb_build_object('ok', true, 'user_id', v->>'user_id', 'expires_epoch', (v->>'expires_epoch')::bigint, 'session_key', skey);
end $$;

revoke all on function public.kernel_session_key(text, text) from public, anon, authenticated;
grant execute on function public.kernel_session_key(text, text) to service_role;

-- self-test: ticket issue -> session_key wahi jo kernel_request_verify maanta hai; bigra ticket / galat host reject.
do $$
declare u uuid := '00000000-0000-4000-8000-000000000e91'; t jsonb; k jsonb; msg text := 'mail.threads.1700000000.abc'; tag text;
begin
  perform public.kernel_hmac_ensure_keys();
  t := public.kernel_ticket_issue(u, 'anexomail.com', 300);
  k := public.kernel_session_key(t->>'ticket', 'anexomail.com');
  if not coalesce((k->>'ok')::boolean, false) then raise exception 'E91 SELFTEST: session key nahi mili'; end if;
  if k->>'session_key' <> t->>'session_key' then raise exception 'E91 SELFTEST: ticket ki key aur session_key alag'; end if;
  tag := encode(extensions.hmac(convert_to(msg, 'UTF8'), convert_to(k->>'session_key', 'UTF8'), 'sha256'), 'hex');
  if not public.kernel_request_verify(t->>'ticket', 'anexomail.com', msg, tag) then raise exception 'E91 SELFTEST: tag verify nahi hua'; end if;
  if coalesce((public.kernel_session_key(t->>'ticket', 'evil.example')->>'ok')::boolean, true) then raise exception 'E91 SELFTEST: galat host chal gaya'; end if;
  if coalesce((public.kernel_session_key(t->>'ticket' || 'x', 'anexomail.com')->>'ok')::boolean, true) then raise exception 'E91 SELFTEST: bigra ticket chal gaya'; end if;
end $$;
