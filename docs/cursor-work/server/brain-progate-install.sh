#!/usr/bin/env bash
# ANEXOMAIL — Brain (Bun :3100) fallback: Pro gate Bun par bhi (27 Oct 2026 loophole fix). Koi SQL nahi. Rust/Web ko haath nahi.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-progate-install.sh)
# Loophole: Rust par Pro gate tha, lekin Bun /api/work/* (tasks, notes, promises, follow-through) + /api/calendar/events/:id/outcome +
# /api/mail/handoff* par plan check NAHI tha — Basic user seedha Bun ko bula kar Pro feature chala sakta tha.
# Surgical patch (live files repo se alag ho sakti hain): sirf guard( -> proGuard( + helper; handoff.ts mein requireUser par plan check.
# Backup + bun build pre-flight + health + restore-on-fail. Dobara chalana safe ("Pehle se lagi hai").
set -uo pipefail
SRC="${BRAIN_SRC:-/opt/anexomail/src}"; R="$SRC/routes"; CAL="$R/calendar.ts"; HO="$R/handoff.ts"
BUN="$(command -v bun || echo /root/.bun/bin/bun)"; B="/root/anexomail-backups/brain-progate-$(date +%Y%m%d-%H%M%S)"
for f in "$CAL" "$HO" "$SRC/lib/plan.ts"; do [ -f "$f" ] || { echo "FAIL: $f nahi mili"; exit 2; }; done
grep -q "function isBasic" "$CAL" || { echo "FAIL: live calendar.ts mein isBasic nahi — pehle brain-pro-install.sh chalayen"; exit 2; }
if grep -q "function proGuard" "$CAL" && grep -q "Draft handoff between devices" "$HO"; then echo "Pehle se lagi hai."; exit 0; fi
mkdir -p "$B"; cp -p "$CAL" "$B/calendar.ts"; cp -p "$HO" "$B/handoff.ts"
python3 - "$CAL" "$HO" <<'PY' || { cp -p "$B/calendar.ts" "$CAL"; cp -p "$B/handoff.ts" "$HO"; echo "FAIL: patch point nahi mila — kuch nahi badla"; exit 3; }
import re,sys
cal,ho=sys.argv[1],sys.argv[2]
s=open(cal).read()
if "function proGuard" not in s:
    helper='''
/** Pro+ guard (Work: tasks, promises, notes, follow-through, meeting outcome). Rust workx primary; yeh Bun fallback ka wahi gate — plan na mile to Basic. */
function proGuard(handler: (c: any, req: any, res: any) => Promise<any>) {
  return guard(async (c, req, res) => {
    if (await isBasic(c))
      return res.status(403).json({ error: { code: "feature_not_available", message: "Tasks, notes, promises and meeting outcomes are a Pro+ feature." } });
    await handler(c, req, res);
  });
}
'''
    m=re.search(r'function guard\(.*?\n\}\n',s,re.S)
    if not m: sys.exit(1)
    s=s[:m.end()]+helper+s[m.end():]
    n=[0]
    def rep(m):
        p=m.group(2)
        if p.startswith('/work') or p.endswith('/outcome'):
            n[0]+=1; return m.group(1)+p+m.group(3)+'proGuard('
        return m.group(0)
    s=re.sub(r'(calendar\.(?:get|post|patch|put|delete)\(\s*")([^"]+)("\s*,\s*)guard\(',rep,s)
    if n[0]<8: sys.exit(1)
    open(cal,'w').write(s)
h=open(ho).read()
if "Draft handoff between devices" not in h:
    if 'from "../lib/plan"' not in h:
        h=h.replace('from "@supabase/supabase-js";','from "@supabase/supabase-js";\nimport { resolvePlan } from "../lib/plan";',1)
    m=re.search(r'\n  return data\.user\.id;\n\}',h)
    if not m: sys.exit(1)
    blk='''
  // Pro+ gate (Rust mail.handoff.* jaisa) — /devices/seen sab plans ko khula (heartbeat), baaqi handoff Pro+. Plan na mile to Basic.
  if (!String(req.path || "").startsWith("/devices/seen")) {
    let plan = "basic";
    try { plan = await resolvePlan(data.user.id, String(data.user.email || "")); } catch { /* Basic */ }
    if (plan === "basic") {
      res.status(403).json({ error: "feature_not_available", plan, message: "Draft handoff between devices is a Pro+ feature." });
      return null;
    }
  }'''
    h=h[:m.start()]+blk+h[m.start():]
    open(ho,'w').write(h)
PY
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in "$CAL" "$HO"; do "$BUN" build "$f" --target=bun --external '*' --outfile "$T/o.js" >"$T/l" 2>&1 || { cat "$T/l"; cp -p "$B/calendar.ts" "$CAL"; cp -p "$B/handoff.ts" "$HO"; echo "!! build FAIL — purani wapas"; exit 1; }; done
pm2 restart anexomail-leo --update-env >/dev/null 2>&1 && pm2 save >/dev/null 2>&1; sleep 7
H="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/health)"
C="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/work/tasks)"
D="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3100/api/mail/handoff)"
echo "Brain health $H (200) · /api/work/tasks bina login $C (401) · /api/mail/handoff bina login $D (401)"
if [ "$H" != "200" ] || [ "$C" != "401" ] || [ "$D" != "401" ]; then cp -p "$B/calendar.ts" "$CAL"; cp -p "$B/handoff.ts" "$HO"; pm2 restart anexomail-leo --update-env >/dev/null 2>&1; echo "!! check FAIL — purani files wapas"; exit 1; fi
pm2 status anexomail-leo | head -6
echo "DONE: Bun par Pro gate. backup $B. Ab basic-gate-probe (BUN work/tasks, handoff = Basic 403, Pro 200)."
