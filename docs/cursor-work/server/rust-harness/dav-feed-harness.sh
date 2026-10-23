#!/usr/bin/env bash
# dav_glue ka asli feed handler, nakli backend ke saath (sandbox/scratch par; server/production ko haath nahi). cargo --offline ya online dono.
# Chalana: bash docs/cursor-work/server/rust-harness/dav-feed-harness.sh      (repo ke andar se)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$HERE/../../../../server/rust" && pwd)"
T="${TMPDIR:-/tmp}/dav-feed-harness"
rm -rf "$T"; mkdir -p "$T/src"
cp "$HERE/dav-feed.Cargo.toml" "$T/Cargo.toml"
sed "s#@R@#$R#g" "$HERE/dav-feed-main.rs" > "$T/src/main.rs"
cd "$T"
OFF="--offline"; [ "${ONLINE:-0}" = "1" ] && OFF=""
CARGO_TARGET_DIR="$T/target" cargo run $OFF 2>&1 | grep -E "^(BIG|GET|HEAD|POST|PUT|DELETE|PROPFIND|REPORT|OPTIONS|wrong|unknown|bad|basic|ALL|error|warning)" || true
