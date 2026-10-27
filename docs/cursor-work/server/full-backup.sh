#!/usr/bin/env bash
# ANEXOMAIL — POORA SERVER BACKUP (READ-ONLY live par: sirf COPY karta hai, kuch badalta/restart nahi karta). Kuch bhi ho, yahan se sab wapas aata hai.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/full-backup.sh)
# Kya copy: (1) Polar engine /opt/polar-rust-payment (src, wal, .env — backup folder chmod 700; target/ chhod kar, wo dobara ban jata hai + sirf binary),
# (2) Rust engine /opt/anexomail-rust (src + Cargo + chalti binary), (3) Brain /opt/anexomail/src + anexochat, (4) web /opt/anexomail-web ka git HEAD sha,
# (5) pm2 dump + env, (6) Caddy, /etc/anexomail, Postfix main.cf, clamd.conf, (7) SQL ledger. Secret kisi bhi screen par print NAHI hota.
# Wapas: backup folder mein RESTORE.sh banta hai (file-file, restart pehle poochhe bina nahi: sirf --apply par). Polar :3400 ko RESTORE sirf founder ki "haan" par.
set -uo pipefail
STAMP="$(date +%Y%m%d-%H%M%S)"; B="/root/anexomail-backups/full-$STAMP"
umask 077; mkdir -p "$B"; chmod 700 "$B"
cp_dir() { # src dest [excludes...]
  local s="$1" d="$2"; shift 2
  [ -e "$s" ] || { echo "   (nahi mila, chhoda: $s)"; return 0; }
  mkdir -p "$d"
  local ex=(); for e in "$@"; do ex+=(--exclude="$e"); done
  tar -C "$(dirname "$s")" "${ex[@]}" -cf - "$(basename "$s")" | tar -C "$d" -xf -
  echo "   OK $s -> $d  ($(du -sh "$d" 2>/dev/null | cut -f1))"
}
cp_file() { [ -e "$1" ] && { mkdir -p "$2"; cp -p "$1" "$2/" && echo "   OK $1"; } || echo "   (nahi mila, chhoda: $1)"; }
echo "== 1) Polar engine (NO-TOUCH: sirf padhna/copy)"
cp_dir /opt/polar-rust-payment "$B/polar" target
[ -x /opt/polar-rust-payment/target/release/polar-rust-payment ] && cp -p /opt/polar-rust-payment/target/release/polar-rust-payment "$B/polar/polar-rust-payment.bin" && echo "   OK polar binary"
echo "== 2) Rust engine :3200"
cp_dir /opt/anexomail-rust "$B/rust" target
[ -x /opt/anexomail-rust/target/release/anexomail-rust ] && cp -p /opt/anexomail-rust/target/release/anexomail-rust "$B/rust/anexomail-rust.bin" && echo "   OK rust binary"
echo "== 3) Brain (Bun) + chat"
cp_dir /opt/anexomail/src "$B/brain" node_modules
cp_dir /opt/anexochat "$B/chat" node_modules
echo "== 4) Web git sha"
git -C /opt/anexomail-web rev-parse HEAD > "$B/web-HEAD.txt" 2>/dev/null && echo "   OK web HEAD $(cut -c1-8 "$B/web-HEAD.txt")"
echo "== 5) pm2 + config"
mkdir -p "$B/pm2"; pm2 save >/dev/null 2>&1; cp_file /root/.pm2/dump.pm2 "$B/pm2"
pm2 jlist 2>/dev/null | python3 -c 'import sys,json
try:
  for p in json.load(sys.stdin): print(p["name"],p["pm2_env"]["status"],p["pm2_env"].get("pm_exec_path",""))
except Exception: pass' > "$B/pm2/processes.txt" 2>/dev/null
cp_dir /etc/anexomail "$B/etc-anexomail"
cp_dir /etc/caddy "$B/caddy"
cp_file /etc/postfix/main.cf "$B/postfix"
cp_file /etc/clamav/clamd.conf "$B/clamav"
cp_file /var/lib/anexomail/sql-applied.tsv "$B/sql"
echo "== 6) RESTORE.sh"
cat > "$B/RESTORE.sh" <<RS
#!/usr/bin/env bash
# Is backup se wapas: bash $B/RESTORE.sh <hissa> --apply   (bina --apply sirf dikhata hai). Hissa: rust | brain | polar | caddy | all-but-polar
set -uo pipefail
B="$B"; PART="\${1:-}"; APPLY="\${2:-}"
run() { if [ "\$APPLY" = "--apply" ]; then "\$@"; else echo "DRY: \$*"; fi; }
case "\$PART" in
  rust)  run pm2 stop anexomail-rust; run cp -p "\$B/rust/anexomail-rust.bin" /opt/anexomail-rust/target/release/anexomail-rust; run cp -p "\$B/rust/anexomail-rust/src/"*.rs /opt/anexomail-rust/src/; run pm2 restart anexomail-rust ;;
  brain) run cp -rp "\$B/brain/src/." /opt/anexomail/src/; run pm2 restart anexomail-leo ;;
  polar) echo "POLAR: sirf founder ki haan par."; run pm2 stop polar-rust-payment; run cp -p "\$B/polar/polar-rust-payment.bin" /opt/polar-rust-payment/target/release/polar-rust-payment; run cp -p "\$B/polar/polar-rust-payment/.env" /opt/polar-rust-payment/.env; run pm2 restart polar-rust-payment ;;
  caddy) run cp -rp "\$B/caddy/caddy/." /etc/caddy/; run systemctl reload caddy ;;
  all-but-polar) bash "\$0" rust "\$APPLY"; bash "\$0" brain "\$APPLY"; bash "\$0" caddy "\$APPLY" ;;
  *) echo "hissa likhein: rust | brain | polar | caddy | all-but-polar [--apply]"; exit 2 ;;
esac
RS
chmod 700 "$B/RESTORE.sh"
echo; echo "DONE: backup $B  ($(du -sh "$B" | cut -f1)). Dry-run: bash $B/RESTORE.sh all-but-polar"
