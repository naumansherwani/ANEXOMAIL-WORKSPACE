#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY workspace API check (17 Oct 2026, Admin → Members/Teams audit). Kuch badalta nahi, koi secret print nahi.
# Sawal: Admin → Members / Teams / Invitations pages ye endpoints bulate hain:
#   GET /api/workspace/members, PATCH+DELETE /api/workspace/members/:id, GET+POST+DELETE /api/workspace/invitations,
#   GET+POST+DELETE /api/workspace/teams
# Repo ke Brain (`server/routes/workspace.ts`) mein sirf 4 route hain: POST /personal, POST /organisations,
# PATCH /active-organisation, POST /invitations. Baqi kahin nahi mile (Rust source repo mein nahi). Yeh script live sach dikhata hai.
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/workspace-api-check.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }

hr "1. live Brain: workspace.ts ki sha + registered routes (repo se milao)"
for f in $(find /opt/anexomail -name workspace.ts -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -3); do
  echo "$f  sha256[:16]=$(sha256sum "$f" | cut -c1-16)  lines=$(wc -l < "$f")"
  grep -nE 'workspaceRouter\.(get|post|put|patch|delete)\(' "$f" | cut -c1-120
done
echo "repo (origin/main) server/routes/workspace.ts sha256[:16]=$(git -C /opt/anexomail-web show origin/main:server/routes/workspace.ts 2>/dev/null | sha256sum | cut -c1-16)"

hr "2. bina login ke GET probe (401 = route maujood + auth maangta hai; 404 = route hai hi nahi). Control = nonsense path"
for base in "http://127.0.0.1:3100" "http://127.0.0.1:3200" "https://anexomail.com"; do
  echo "-- $base"
  for path in /api/workspace/members /api/workspace/teams /api/workspace/invitations /api/workspace/zz-control-nope; do
    printf '   %-40s ' "$path"; curl -s -o /dev/null -m 6 -w '%{http_code}\n' "$base$path"
  done
done
echo "(members/teams ka code control jaisa 404 hai => endpoint maujood hi nahi => Admin Members/Teams page live mein error dikhata hai)"

hr "3. Rust source mein workspace members/teams/invitations (sirf file:line, matn nahi)"
grep -rn --include=*.rs -E 'workspace/(members|teams|invitations)|"/workspace' /opt/anexomail-rust/src 2>/dev/null | cut -c1-140 | head -12
echo "(khali = Rust mein bhi nahi)"

hr "4. Caddy: /api/workspace ka raasta"
grep -n -B1 -A3 -E 'workspace|handle /api' /etc/caddy/Caddyfile 2>/dev/null | cut -c1-140 | head -30

hr "5. database: members/teams/invitations ke tables + ginti (sirf ginti, content nahi)"
if [ -r /etc/anexomail/sync.env ]; then
  ( . /etc/anexomail/sync.env 2>/dev/null
    echo "-- tables jinke naam mein team/invit/member hai:"
    psql "$WORKING_URL" -Atc "select table_schema||'.'||table_name from information_schema.tables where table_schema in ('public') and (table_name ilike '%team%' or table_name ilike '%invit%' or table_name ilike '%member%') order by 1;" 2>&1 | head -20
    echo "-- ginti:"
    psql "$WORKING_URL" -Atc "
      select 'account_org_members', count(*), count(distinct org_id) from public.account_org_members
      union all select 'org_members', count(*), count(distinct org_id) from public.org_members;" 2>&1 | head -6
    echo "-- trigger jo auth.users par chalta ho (invite accept par org se jodne wala?):"
    psql "$WORKING_URL" -Atc "select tgname from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='auth' and c.relname='users' and not t.tgisinternal;" 2>&1 | head -8
  )
else
  echo "/etc/anexomail/sync.env nahi mila"
fi

echo
echo "== done (read-only) =="
