#!/usr/bin/env bash
# founder-tech-proof.sh (21 Nov 2026 00:55 PKT, his order: read-only proofs instead of guesses). READ ONLY: changes nothing, restarts nothing, opens no port, writes no file. Answers 3 open audit items with FACTS from his server:
#   (1) why 4 Inter fonts came over HTTP/1.1  (2) is the TLS on 443 AES-256 + which key exchange  (3) what the red "4 requests blocked in the last 24 h" really is
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-tech-proof.sh) 2>&1 | tail -45
unset PGHOST PGPORT PGSERVICE PGDATABASE PGUSER
H=founderworkspace.anexomail.com
echo "== 1/3a who listens on 443 (read-only ss)"
ss -tlnp 2>/dev/null | awk 'NR==1 || /:443 /' | cut -c1-150; ss -ulnp 2>/dev/null | awk 'NR==1 || /:443 /' | cut -c1-150
echo "== 1/3b DNS HTTPS record (if it says alpn=h3 the browser starts on h3; empty = it starts on TCP and learns h3 later)"
(dig +short HTTPS $H 2>/dev/null || host -t HTTPS $H 2>/dev/null) | head -3; echo "   (end of DNS answer)"
F="$(ls /opt/anexomail-founder/web/assets/Inter-Regular-*.woff2 2>/dev/null | head -1)"; [ -z "$F" ] && F="$(find /opt -name 'Inter-Regular-*.woff2' 2>/dev/null | head -1)"; FN="$(basename "$F" 2>/dev/null)"; echo "   font file: ${FN:-not found}"
echo "== 1/3c the same font over the public name (TCP path, what a first visit does)"
curl -sS -o /dev/null -D - -w 'HTTP %{http_code} version %{http_version} from %{remote_ip}:%{remote_port}\n' "https://$H/_cc/assets/$FN" 2>&1 | grep -i -E "^HTTP|alt-svc|server|content-type|cache-control|version" | cut -c1-200
echo "   curl http3 support: $(curl --version | grep -o -i -m1 'http3' || echo no)"
curl --http3-only -sS -o /dev/null -w '   h3 test: HTTP %{http_code} version %{http_version}\n' "https://$H/_cc/assets/$FN" 2>&1 | head -2 | cut -c1-160
echo "== 2/3 TLS on TCP 443 (openssl $(openssl version | cut -d' ' -f2); ML-KEM needs OpenSSL 3.5+, an older client cannot ask for it, that is a client limit, not proof either way)"
echo | openssl s_client -connect $H:443 -servername $H -tls1_3 2>/dev/null | grep -E "Protocol  :|Cipher is|Cipher    :|Server Temp Key|Negotiated TLS1.3 group|Verification" | head -6 | sed 's/^/   /'
echo | openssl s_client -connect $H:443 -servername $H -tls1_3 -groups X25519MLKEM768 2>&1 | grep -E "Negotiated TLS1.3 group|unsupported|Server Temp Key|Cipher    :" | head -3 | sed 's/^/   ML-KEM ask: /'
echo "== 3/3 the red 'blocked in the last 24 h' = founder_dbsc_events (E149), last 24 h by kind, from the MANAGED database (read only)"
. /etc/anexomail/sync.env 2>/dev/null
if [ -n "${WORKING_URL:-}" ]; then
  psql "$WORKING_URL" -X -At -F ' | ' -c "select kind, count(*), to_char(to_timestamp(max(ts_ms)/1000) at time zone 'Asia/Karachi','DD Mon HH24:MI') from public.founder_dbsc_events where ts_ms > (extract(epoch from now())*1000 - 86400000)::bigint group by kind order by 2 desc" 2>&1 | head -12 | sed 's/^/   /'
  echo "   -- the blocked rows themselves (facts, no secrets in this column by its CHECK):"
  psql "$WORKING_URL" -X -At -F ' | ' -c "select to_char(to_timestamp(ts_ms/1000) at time zone 'Asia/Karachi','DD Mon HH24:MI:SS'), left(facts::text,200) from public.founder_dbsc_events where kind='blocked' and ts_ms > (extract(epoch from now())*1000 - 86400000)::bigint order by id desc limit 6" 2>&1 | sed 's/^/   /'
else echo "   WORKING_URL missing"; fi
echo "DONE (read only). Paste this whole output."
