#!/usr/bin/env bash
# ANEXOMAIL — axum 0.7.9 -> 0.8.x: PEHLE SIRF DEKHNA + scratch copy par cargo check. LIVE KUCH NAHI BADLATA. (TECH-MAP 0a, Rule 25)
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/axum-scratch-check.sh)
#
#   1. live Cargo.toml mein axum (aur saath ke tower/hyper/axum-extra) ki lines.
#   2. live src mein axum 0.8 se toot'ne wali cheezein: path syntax (`/:x`, `/*x`), `#[async_trait]`, `Option<..>` extractors, `Host`, `axum::Server`.
#   3. /opt/anexomail-rust ki COPY /tmp/ax8-scratch mein; wahan axum -> 0.8 laga kar `cargo check` (alag target dir; production ko haath nahi).
#   4. errors ka khulasa — isi se agla patch likha jata hai.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; SCR="${SCR:-/tmp/ax8-scratch}"
command -v cargo >/dev/null || { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; }
cd "$TARGET" || { echo "FAIL: $TARGET nahi"; exit 2; }
echo "== 1) Cargo.toml (axum aur saathi)"
grep -nE '^(axum|axum-extra|tower|tower-http|tower_http|hyper|hyper-util|http|http-body|http-body-util|async-trait|tokio|wtransport|serde_json|reqwest)\b' Cargo.toml | sed 's/^/   /'
echo "   Cargo.lock: axum $(awk '$0=="name = \"axum\""{getline; gsub(/version = |"/,""); print}' Cargo.lock | tr '\n' ' ')  axum-core $(awk '$0=="name = \"axum-core\""{getline; gsub(/version = |"/,""); print}' Cargo.lock | tr '\n' ' ')"
echo "== 2) src: axum 0.8 se tootne wali jagahen (file:line)"
cnt() { grep -rnE "$1" src --include=*.rs 2>/dev/null | wc -l | tr -d ' '; }
echo "   path '/:param'        : $(cnt '\.route\("[^"]*/:[A-Za-z_]')   (0.8 mein '/{param}')"
echo "   path '/*wildcard'     : $(cnt '\.route\("[^"]*/\*')            (0.8 mein '/{*rest}')"
echo "   #[async_trait]        : $(cnt 'async_trait')"
echo "   Option<..> extractor  : $(cnt 'Option<(Query|Path|Json|Extension|TypedHeader|Host)')"
echo "   axum::Server / Host   : $(cnt 'axum::Server|extract::Host|axum::extract::Host')"
echo "   total .route( / .nest(: $(cnt '\.(route|nest)\(')"
grep -rnE '\.route\("[^"]*/(:|\*)' src --include=*.rs | cut -c1-150 | head -12 | sed 's/^/   /'
grep -rnE 'async_trait|extract::Host|axum::Server|Option<(Query|Path|Json|Extension|TypedHeader)' src --include=*.rs | cut -c1-150 | head -12 | sed 's/^/   /'
echo "== 3) scratch copy par axum 0.8 + cargo check (kuch minute; production safe)"
rm -rf "$SCR"; mkdir -p "$SCR"; cp -a Cargo.toml Cargo.lock src "$SCR"/ 2>/dev/null; [ -f build.rs ] && cp -a build.rs "$SCR"/
cd "$SCR" || exit 2
AX="$(grep -nE '^axum[[:space:]]*=' Cargo.toml | head -1)"
if [ -z "$AX" ]; then echo "   axum line nahi mili Cargo.toml mein — ruk gaya"; exit 1; fi
sed -i -E 's/^(axum[[:space:]]*=[[:space:]]*)"[^"]*"/\1"0.8"/; s/^(axum[[:space:]]*=[[:space:]]*\{[^}]*version[[:space:]]*=[[:space:]]*)"[^"]*"/\1"0.8"/' Cargo.toml
echo "   scratch axum line: $(grep -E '^axum[[:space:]]*=' Cargo.toml)"
if ! CARGO_TARGET_DIR="$SCR/target" cargo update -p axum >/tmp/ax8-update.log 2>&1; then echo "   cargo update fail:"; tail -8 /tmp/ax8-update.log | sed 's/^/   /'; fi
grep -E "Updating|Adding|Removing" /tmp/ax8-update.log | head -12 | sed 's/^/   /'
CARGO_TARGET_DIR="$SCR/target" nice -n 10 cargo check >/tmp/ax8-check.log 2>&1; RC=$?
echo "   cargo check exit: $RC   errors: $(grep -c '^error' /tmp/ax8-check.log)   warnings: $(grep -c '^warning' /tmp/ax8-check.log)"
echo "== 4) errors (pehle 45 lines)"
grep -E "^error" -A5 /tmp/ax8-check.log | head -45 | cut -c1-170 | sed 's/^/   /'
echo "   poora log: /tmp/ax8-check.log   scratch: $SCR"
echo "== LIVE ko kuch nahi hua: $(curl -s -m 5 -o /dev/null -w '/rpc/health %{http_code}' http://127.0.0.1:3200/rpc/health)"
