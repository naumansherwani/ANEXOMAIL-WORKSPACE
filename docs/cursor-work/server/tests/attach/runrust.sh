#!/bin/bash
cd "$(dirname "$0")/../fullchk"
export SUPABASE4_URL=http://127.0.0.1:4010 SUPABASE4_SERVICE_ROLE_KEY=svc CLAMD_ADDR=127.0.0.1:3311
export ATTACH_DIR="${1:-$(pwd)/../e48/attach-root}"
echo $$ > ../e48/rust.pid
exec ./target/debug/anexomail-rust
