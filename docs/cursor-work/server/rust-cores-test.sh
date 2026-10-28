#!/usr/bin/env bash
# Rust awam cores — unit tests (pure logic, no server touched, nothing installed, nothing restarted).
# Compiles each server/rust/*_core.rs on its own with `rustc --test` and runs it. Cores that need external crates are reported SKIP (the full engine build covers them).
# Usage (server): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-cores-test.sh) 2>&1 | tail -25
set -u
REPO="${REPO:-/opt/anexomail-web}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$REPO" archive origin/main server/rust 2>/dev/null | tar -x -C "$T" 2>/dev/null || cp -r "$REPO/server/rust" "$T/" 
cd "$T/server/rust" 2>/dev/null || cd "$T/rust" || { echo "!!! server/rust nahi mila"; exit 1; }
pass=0; fail=0; skip=0; tests=0
for f in *_core.rs; do
  n="${f%.rs}"
  if ! rustc --edition 2021 --test "$f" -o "$T/$n" >"$T/$n.log" 2>&1; then
    if grep -q "unresolved import\|can't find crate\|extern crate" "$T/$n.log"; then
      # cores that need crates run inside the crate that already builds them (jwt_core = founder crate, same code via #[path])
      FS="${FOUNDER_SRC:-/opt/anexomail-founder/src}"; command -v cargo >/dev/null 2>&1 || export PATH="$HOME/.cargo/bin:$PATH"
      if [ "$n" = "jwt_core" ] && [ -d "$FS" ]; then
        r="$(cd "$FS" && env -u NO_PROXY -u no_proxy cargo test --release jwt_core 2>&1 | grep "test result" | head -1)"
        p=$(echo "$r" | sed -E 's/.* ([0-9]+) passed.*/\1/'); if echo "$r" | grep -q " 0 failed" && [ "${p:-0}" -gt 0 ]; then echo "ok    $n  ($p tests, via founder crate)"; pass=$((pass+1)); tests=$((tests+p)); else echo "!!! FAIL $n (founder crate): $r"; fail=$((fail+1)); fi
      else echo "!!! FAIL $n: needs crates and no crate to run it"; fail=$((fail+1)); fi
    else echo "!!! FAIL compile $n"; tail -3 "$T/$n.log"; fail=$((fail+1)); fi
    continue
  fi
  out="$("$T/$n" 2>&1 | grep "test result")"
  p=$(echo "$out" | sed -E 's/.* ([0-9]+) passed.*/\1/'); 
  if echo "$out" | grep -q " 0 failed"; then echo "ok    $n  ($p tests)"; pass=$((pass+1)); tests=$((tests+p)); else echo "!!! FAIL $n: $out"; fail=$((fail+1)); fi
done
echo "== cores ok=$pass fail=$fail  tests passed=$tests"
[ "$fail" -eq 0 ] && echo "OK — Rust cores ke tests green" || echo "!!! FAIL — upar dekho"
