#!/usr/bin/env bash
# Run after `vite build` (sandbox only; the server never builds). The Rust server (tower-http precompressed_gzip) sends X.js.gz when the browser accepts gzip.
set -euo pipefail
cd "$(dirname "$0")/dist"
# Tell /early.js which hashed worker file is the kernel worker (idempotent), so the kernel starts at page parse, not after the main bundle.
python3 - <<'PY'
import glob, re
w = sorted(glob.glob("assets/kernel.worker-*.js"))
if not w: raise SystemExit("precompress: kernel worker file not found")
s = open("index.html").read()
s = re.sub(r'<meta name="kernel-worker"[^>]*>\n?', "", s)
s = s.replace("<head>", '<head>\n<meta name="kernel-worker" content="/_cc/' + w[0] + '">', 1)
open("index.html", "w").write(s)
print("kernel-worker meta ->", w[0])
PY
for f in assets/*.js assets/*.css; do gzip -9 -n -k -f "$f"; done
ls -la assets | awk '{print $5, $9}' | grep -v woff
