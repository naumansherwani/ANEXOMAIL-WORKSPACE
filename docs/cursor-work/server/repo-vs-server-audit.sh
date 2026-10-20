#!/usr/bin/env bash
# A1 — repo vs server READ-ONLY audit. Kuch badalta nahi, koi secret nahi chhapta.
# Chalana: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/repo-vs-server-audit.sh)
# Output: /root/audit-A1.txt (ya OUT=...) — poora yahan bhi chhapta hai; Claude ko bhej dein.
set -u
REPO="${REPO:-/opt/anexomail-web}"
BRAIN="${BRAIN:-/opt/anexomail/src}"
OUT="${OUT:-/root/audit-A1.txt}"
git -C "$REPO" fetch -q origin main 2>/dev/null
{
echo "A1 audit $(date -u +%FT%TZ)  repo=$(git -C "$REPO" rev-parse --short origin/main)"

echo; echo "== 1) Brain: live $BRAIN vs repo server/ (sha256; sirf farq)"
if [ -d "$BRAIN" ]; then
  ( cd "$BRAIN" && find . -type f \( -name '*.ts' -o -name '*.json' \) ! -path './node_modules/*' ! -name '*.bak*' | sort ) | while read -r f; do
    f="${f#./}"
    live=$(sha256sum "$BRAIN/$f" | cut -c1-16)
    repo=$(git -C "$REPO" show "origin/main:server/$f" 2>/dev/null | sha256sum | cut -c1-16)
    if ! git -C "$REPO" cat-file -e "origin/main:server/$f" 2>/dev/null; then echo "SERVER-ONLY  $f"
    elif [ "$live" != "$repo" ]; then echo "DIFFERS      $f"; fi
  done
  echo "(repo mein hai par server par nahi:)"
  git -C "$REPO" ls-tree -r --name-only origin/main server/ | grep -E '\.ts$' | grep -v test | sed 's#^server/##' | while read -r f; do [ -f "$BRAIN/$f" ] || echo "REPO-ONLY    $f"; done
else echo "Brain dir nahi mila: $BRAIN"; fi

echo; echo "== 2) Rust engine: live source vs repo server/rust"
RS=$(ls -d /opt/anexomail-rust/src /opt/anexomail/rust/src /root/anexomail-rust/src 2>/dev/null | head -1)
if [ -n "$RS" ]; then
  for f in "$RS"/*.rs "$RS"/bin/*.rs; do [ -f "$f" ] || continue; b=$(basename "$f")
    if git -C "$REPO" cat-file -e "origin/main:server/rust/$b" 2>/dev/null; then
      [ "$(sha256sum <"$f"|cut -c1-16)" = "$(git -C "$REPO" show origin/main:server/rust/$b|sha256sum|cut -c1-16)" ] || echo "DIFFERS     $b"
    else echo "SERVER-ONLY $b"; fi; done
else echo "Rust src dir nahi mila (installer ka TARGET dekhein)"; fi

echo; echo "== 3) SQL: live functions/tables (public) jinka naam kisi repo E-file mein nahi"
if [ -r /etc/anexomail/sync.env ]; then
  . /etc/anexomail/sync.env
  SQLS=$(git -C "$REPO" ls-tree -r --name-only origin/main docs/cursor-work/sql/ | while read -r f; do git -C "$REPO" show "origin/main:$f"; done)
  psql "$WORKING_URL" -Atc "select 'fn '||p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' union all select 'tbl '||tablename from pg_tables where schemaname='public' union all select 'policy '||tablename||'.'||policyname from pg_policies where schemaname='public' order by 1" 2>&1 | while read -r kind name; do
    n="${name##*.}"; echo "$SQLS" | grep -qiF -- "$n" || echo "NOT-IN-REPO  $kind $name"; done
else echo "sync.env nahi padh paya"; fi

echo; echo "== 4) Caddy / Postfix / Dovecot (secret-free): sirf sha + line count"
for f in /etc/caddy/Caddyfile /etc/postfix/main.cf /etc/postfix/master.cf /etc/dovecot/dovecot.conf /etc/opendkim.conf; do
  [ -f "$f" ] && echo "$(sha256sum "$f"|cut -c1-16)  $(wc -l <"$f") lines  $f"; done
echo "(repo mein inki copy:)"; git -C "$REPO" ls-tree -r --name-only origin/main | grep -Ei 'caddyfile|postfix|dovecot|opendkim' | head

echo; echo "== 5) systemd units/timers jo 'anexomail' naam ke hain vs repo"
for u in /etc/systemd/system/anexomail*.service /etc/systemd/system/anexomail*.timer /etc/systemd/system/*anexo*.{service,timer}; do
  [ -f "$u" ] || continue; b=$(basename "$u")
  git -C "$REPO" ls-tree -r --name-only origin/main | grep -q "/$b$" && echo "in-repo   $b" || echo "NOT-IN-REPO $b"; done | sort -u
echo "-- timers:"; systemctl list-timers --all --no-legend 2>/dev/null | grep -i anexo | awk '{print $NF}'

echo; echo "== 6) cron (secret chhupa kar)"
{ crontab -l 2>/dev/null; cat /etc/cron.d/* 2>/dev/null; } | grep -v '^#' | grep -i 'anexo\|/opt/' | sed -E 's/(PASSWORD|TOKEN|KEY|SECRET)=[^ ]+/\1=[REDACTED]/Ig'

echo; echo "== 7) pm2: sirf naam, script, env KEY ke naam (value kabhi nahi)"
pm2 jlist 2>/dev/null | python3 -c "
import json,sys
for p in json.load(sys.stdin):
    e=p.get('pm2_env',{})
    ks=sorted(k for k in e.get('env',{}) if k.isupper() and k.startswith(('ANEXO','SUPABASE','POLAR','SMTP','CLAM','WT_','RUST','MAIL','BRAIN')))
    print(p['name'], e.get('pm_exec_path'), 'envkeys=',','.join(ks))
"
echo; echo "== 8) Brain/Rust ke andar secrets ke naam repo mein hain? (sirf naam)"
grep -ho 'process\.env\.[A-Z_]\+' -r "$BRAIN" 2>/dev/null | sort -u | head -60
echo; echo "DONE A1"
} 2>&1 | tee "$OUT"
echo; echo "Saved: $OUT"
