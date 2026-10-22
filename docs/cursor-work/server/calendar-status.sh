#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY calendar status (23 Oct 2026, Nauman bhai ka sawal: "kitne green?"). Kuch badalta nahi, koi secret print nahi.
# Server SIRF deploy-layer dikha sakta hai: SQL ledger + DB objects + Rust health + web commit. "Live UI green" Chrome se dekha jata hai (roadmap mein).
# Chalana:  bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/calendar-status.sh)
set +e
[ -r /etc/anexomail/sync.env ] && . /etc/anexomail/sync.env 2>/dev/null
LED="${LEDGER:-/var/lib/anexomail/sql-applied.tsv}"
Q() { psql "$WORKING_URL" -X -At -c "$1" 2>/dev/null | head -1; }
hr() { printf '\n== %s ==\n' "$1"; }
applied() { [ -r "$LED" ] && grep -q "^$1[_.	]" "$LED" 2>/dev/null; }                 # E-file ledger mein
obj() { [ "$(Q "select to_regclass('public.$1') is not null or exists (select 1 from pg_proc where proname='$1')")" = "t" ]; }   # table ya function
OK=0; TOT=0
row() {  # row "#id" "naam" okflag
  TOT=$((TOT+1)); if [ "$3" = 1 ]; then OK=$((OK+1)); printf '  %-5s %-44s DEPLOYED\n' "$1" "$2"; else printf '  %-5s %-44s ** NAHI / adhura **\n' "$1" "$2"; fi; }
b() { if "$@"; then echo 1; else echo 0; fi; }

hr "Calendar — 13 hisse (sahi ginti: #4a/#4b/#4c alag)"
row "#0"  "layout (sirf web)"                          1
row "#1"  "hours / OOO / rang   (E57 E58)"             "$(b applied E58)"
row "#2"  "booking page         (E59)"                 "$(b applied E59)"
row "#3"  "iMIP reply           (E60)"                 "$(b applied E60)"
row "#4a" "pins (web + prefs E57)"                     "$(b applied E57)"
row "#4b" "overlay / team       (E62)"                 "$(b applied E62)"
row "#4c" "ICS subscribe        (E73)"                 "$( [ "$(b applied E73)" = 1 ] && b obj calendar_subscriptions || echo 0 )"
row "#5"  "event files          (E74)"                 "$( [ "$(b applied E74)" = 1 ] && b obj calendar_event_files || echo 0 )"
row "#9"  "outcome / goal       (E63)"                 "$(b applied E63)"
row "#10" "history search       (E64)"                 "$(b applied E64)"
row "#6"  "CalDAV  — abhi bana nahi"                   0
row "#7"  "Google sync — abhi bana nahi"               0
row "#8"  "Rooms — abhi bana nahi"                     0
echo; echo "  Server par DEPLOYED: $OK / $TOT  (live UI check alag: CALENDAR-ROADMAP.md)"

hr "World clock / baqi calendar SQL"
row "W1" "world clocks (E61)"      "$(b applied E61)"
row "—"  "recurrence (E56)"        "$(b applied E56)"
row "—"  "home city key (E75)"     "$(b applied E75)"
row "—"  "account wall (E76)"      "$( [ "$(b applied E76)" = 1 ] && b obj account_class || echo 0 )"

hr "Rust + Web"
printf '  rust /rpc/health: %s\n' "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3200/rpc/health)"
W=/opt/anexomail-web
# web == repo saboot: HEAD nahi (pull.sh HEAD nahi hilata), src/ ki har file ka git-blob sha origin/main se (pull.sh jaisa)
same=0; differ=0; missing=0; dl=()
while IFS= read -r -d '' rec; do
  meta="${rec%%$'\t'*}"; path="${rec#*$'\t'}"; want="${meta##* }"
  if [ ! -f "$W/$path" ]; then missing=$((missing + 1)); dl+=("MISSING $path"); continue; fi
  if [ "$(git -C "$W" hash-object -- "$W/$path" 2>/dev/null </dev/null)" = "$want" ]; then same=$((same + 1)); else differ=$((differ + 1)); dl+=("DIFF    $path"); fi
done < <(git -C "$W" ls-tree -r -z origin/main -- src </dev/null 2>/dev/null)
echo "  web src/ vs repo (origin/main): same=$same differ=$differ missing=$missing"
if [ "${#dl[@]}" -gt 0 ]; then printf '    %s\n' "${dl[@]:0:15}"; fi
echo; echo "Nata: 'DEPLOYED' = SQL/web server par maujood. Poora GREEN = DEPLOYED + Chrome mein live dekha."
