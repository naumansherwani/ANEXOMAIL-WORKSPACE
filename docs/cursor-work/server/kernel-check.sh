#!/usr/bin/env bash
# ANEXOMAIL — WASM KERNEL (Rule 52) deploy ke baad SERVER-SIDE saboot. Sirf padhta hai, kuch badalta nahi.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh)
# Dekhta hai: (1) Rust engine up + WebTransport live, (2) udp/3443 sun raha hai, (3) cert ki maiyad,
#             (4) kernel wasm site se serve hota hai aur uska SHA-256 repo ke pin se milta hai, (5) /rpc/kernel.report route maujood (E90 + Rust).
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
SITE="${SITE:-https://anexomail.com}"
RUST="${RUST:-http://127.0.0.1:3200}"
BAD=0
ok()   { echo "PASS  $*"; }
bad()  { echo "FAIL  $*"; BAD=1; }

H="$(curl -s --max-time 5 "$RUST/rpc/health" || true)"
case "$H" in *'"webtransport":"live"'*) ok "Rust engine up, WebTransport LIVE";; *'"status":"up"'*) bad "Rust up lekin WebTransport live nahi (ANEXOCHAT_WT_CERT/KEY? udp/3443 bind?)";; *) bad "Rust engine jawab nahi deta ($RUST/rpc/health)";; esac

if command -v ss >/dev/null 2>&1; then
  ss -lunH 2>/dev/null | grep -q ':3443 ' && ok "udp/3443 sun raha hai (QUIC)" || bad "udp/3443 par koi nahi sun raha"
else
  echo "SKIP  ss nahi mila (udp/3443 check)"
fi

CERT="${ANEXOCHAT_WT_CERT:-$(grep -hs '^ANEXOCHAT_WT_CERT=' /opt/anexomail-rust/.env | head -1 | cut -d= -f2-)}"
if [ -n "$CERT" ] && [ -r "$CERT" ] && command -v openssl >/dev/null 2>&1; then
  if openssl x509 -in "$CERT" -noout -checkend $((14*86400)) >/dev/null 2>&1; then ok "WebTransport cert 14 din se zyada baqi ($(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2))"
  else bad "WebTransport cert 14 din ke andar khatam ho raha hai / ho chuka ($CERT)"; fi
  openssl x509 -in "$CERT" -noout -text 2>/dev/null | grep -q 'anexochat.anexomail.com' && ok "cert mein anexochat.anexomail.com maujood" || bad "cert mein anexochat.anexomail.com nahi (browser judega nahi)"
else
  echo "SKIP  cert path nahi mila (ANEXOCHAT_WT_CERT)"
fi

PIN="$(git -C "$REPO" show origin/main:src/lib/kernel/pin.gen.ts 2>/dev/null)"
VER="$(echo "$PIN" | sed -n 's/.*version: "\([^"]*\)".*/\1/p' | head -1)"
SHA="$(echo "$PIN" | sed -n 's/.*sha256: "\([^"]*\)".*/\1/p' | head -1)"
if [ -n "$VER" ] && [ -n "$SHA" ]; then
  GOT=""; WST=""
  for _i in 1 2 3; do
    WST="$(curl -s --max-time 10 -o /tmp/.kc.wasm -w 'http=%{http_code} type=%{content_type} size=%{size_download}' "$SITE/kernel/anexo-kernel-$VER.wasm")"
    GOT="$(sha256sum /tmp/.kc.wasm 2>/dev/null | cut -d' ' -f1)"
    [ "$GOT" = "$SHA" ] && break; sleep 3
  done
  rm -f /tmp/.kc.wasm
  [ "$GOT" = "$SHA" ] || echo "     (wasm jawab: $WST)"
  [ "$GOT" = "$SHA" ] && ok "kernel $VER wasm site se serve hota hai, SHA-256 pin se mila" || bad "kernel $VER wasm ka hash pin se nahi milta (Web pull.sh chali? Caddy/Bun static?)  got=${GOT:0:12} want=${SHA:0:12}"
else
  bad "repo mein kernel pin nahi mila (src/lib/kernel/pin.gen.ts)"
fi

C="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'content-type: application/json' -d '{"input":{}}' "$RUST/rpc/kernel.report" || true)"
[ "$C" = "401" ] && ok "kernel.report maujood (bina login 401)" || bad "kernel.report ka jawab $C (Rust installer chala? 401 hona chahiye)"

# E90 request tag: Rust ne kitne tag valid/missing/invalid dekhe (ANEXO_TAG_MODE observe = sirf ginti). Browser mein kuch trafic aane ke baad chalayein.
TL="$( (pm2 logs anexomail-rust --nostream --lines 600 2>/dev/null; journalctl -u anexomail-rust -n 600 --no-pager 2>/dev/null) | grep 'kernel request-tag' | tail -1 || true)"
if [ -n "$TL" ]; then ok "request-tag ginti: ${TL##*INFO }"; else echo "   (request-tag log abhi nahi: browser mein app kholein, phir dobara chalayein)"; fi
SK="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'content-type: application/json' -d '{"input":{}}' "$RUST/rpc/kernel.ticket" || true)"
[ "$SK" = "401" ] && ok "kernel.ticket maujood (bina login 401)" || bad "kernel.ticket ka jawab $SK (Rust installer chala? 401 hona chahiye)"

echo; [ "$BAD" = 0 ] && echo "KERNEL CHECK: ALL PASS" || echo "KERNEL CHECK: FAIL (upar dekhein)"
exit "$BAD"
