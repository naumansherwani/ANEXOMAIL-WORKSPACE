#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL / ANEXOChat — RUST PRIMARY ENGINE auto-deploy (koi nano nahi)
#
#   cd /opt/anexomail-web && git pull && bash server/rust/deploy.sh
#
# Yeh script khud karti hai:
#   1. repo se main.rs + Cargo.toml -> /opt/anexomail-rust (purani file .bak)
#   2. .env KABHI touch nahi (secrets sirf server par)
#   3. cargo build --release
#   4. pm2 restart anexomail-rust --update-env + pm2 save
#   5. Caddy par /file/* aur /rpc/* -> 3200 hone ka check (site block repo se)
#   6. health + private observability print
# ============================================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="/opt/anexomail-rust"
STAMP="$(date +%s)"

if [ ! -d "$TARGET" ]; then
  echo "!! $TARGET nahi mila — Rust engine is server par install nahi hai."
  exit 1
fi

mkdir -p "$TARGET/src"

for f in main.rs; do
  [ -f "$TARGET/src/$f" ] && cp "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"
  cp "$REPO_DIR/$f" "$TARGET/src/$f"
  echo ">>> synced src/$f"
done

[ -f "$TARGET/Cargo.toml" ] && cp "$TARGET/Cargo.toml" "$TARGET/Cargo.toml.bak.$STAMP"
cp "$REPO_DIR/Cargo.toml" "$TARGET/Cargo.toml"
echo ">>> synced Cargo.toml (.env untouched)"

echo "--- cargo build --release ---"
cd "$TARGET" || exit 1
if ! cargo build --release; then
  echo "!! build fail — purani binary chal rahi hai, kuch restart nahi kiya."
  exit 1
fi

pm2 restart anexomail-rust --update-env >/dev/null 2>&1 || \
  pm2 start "$TARGET/target/release/anexomail-rust" --name anexomail-rust
pm2 save >/dev/null 2>&1

sleep 2
echo "--- live readings ---"
curl -s http://127.0.0.1:3200/rpc/health; echo
printf "private readiness :3600: "
curl -s http://127.0.0.1:3600/ready; echo
printf "file chunk path (401 expected without token): "
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:3200/file/chunk

cat <<'NOTE'

--- Caddy note (agar /file/* abhi route nahi hai) ---
anexomail.com ke site block mein Rust ko yeh do path chahiye:
  handle /rpc/* { reverse_proxy 127.0.0.1:3200 }
  handle /file/* { reverse_proxy 127.0.0.1:3200 }
5 GB chunked transfer ke liye is block mein:
  request_body { max_size 32MB }
NOTE
