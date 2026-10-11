#!/bin/bash
# E15-B: Rust company-domain arms -> /opt/anexomail-rust (backup, build, restart; build fail = purani binary chalti rehti hai)
export PAGER=cat
F=/opt/anexomail-rust/src/main.rs
D=/tmp/e15rs
B=https://raw.githubusercontent.com/naumansherwani/ANEXOMAIL-WORKSPACE/wip/e15-rust/wip/e15rs
mkdir -p $D && for f in helpers.rs arms.rs apply.py; do curl -fsSL $B/$f -o $D/$f || { echo "DOWNLOAD_FAIL $f"; exit 1; }; done
echo "HELPERS_SHA=$(sha256sum $D/helpers.rs | cut -c1-64)"
echo "ARMS_SHA=$(sha256sum $D/arms.rs | cut -c1-64)"
echo "APPLY_SHA=$(sha256sum $D/apply.py | cut -c1-64)"
[ "$(sha256sum $D/helpers.rs | cut -c1-64)" = "d06fe801aec8bb6c6cf72be410ad055e1b70d9f34a819c4e1ed6cb884df8cbe4" ] && [ "$(sha256sum $D/arms.rs | cut -c1-64)" = "d960f17a47e3f3db7679173ad40276a128d0cf155f26b90bf98796717925bb2b" ] && [ "$(sha256sum $D/apply.py | cut -c1-64)" = "629c99a255e2bf3b255fb8350e66e79b1dc08233d4cf84b589bf4f3267e7df45" ] || { echo "SHA_MISMATCH - ruk jao"; exit 1; }
cp -a $F $F.bak-e15 && echo BACKUP_OK
python3 $D/apply.py $F $D || { cp -a $F.bak-e15 $F; echo "PATCH_FAIL -> backup wapas"; exit 1; }
cd /opt/anexomail-rust && if cargo build --release 2>&1 | tail -25 | tee /tmp/e15-build.log | grep -qE "^error"; then
  cp -a $F.bak-e15 $F; echo "BUILD_FAIL -> backup wapas, purani binary chal rahi hai"; grep -E "^error" -A6 /tmp/e15-build.log | head -40; exit 1
fi
echo BUILD_OK
pm2 restart anexomail-rust --update-env >/dev/null && pm2 save >/dev/null; sleep 3
curl -s http://127.0.0.1:3200/rpc/health | cut -c1-120; echo
