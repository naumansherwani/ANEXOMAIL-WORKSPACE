#!/bin/bash
# generate install.sh with real shas (run in repo)
M="src/components/app/mail/MailRail.tsx src/components/app/mail/ThreadList.tsx src/routes/app.mail.\$folder.\$threadId.tsx src/routes/app.mail.\$folder.tsx"
N="src/components/app/mail/AddressChip.tsx src/lib/mail-identity.ts wip/ui/mx-cinema.css"
PRE=""; for f in $M; do PRE="$PRE$(git show main:"$f" | sha256sum | cut -c1-64)  $f\n"; done
POST=""; for f in $N $M; do POST="$POST$(sha256sum "$f" | cut -c1-64)  $f\n"; done
python3 - "$PRE" "$POST" <<'PY'
import sys
pre, post = sys.argv[1], sys.argv[2]
t = open("wip/ui/install.tpl").read().replace("@@PRE@@", pre.replace("\\n","\n").strip()).replace("@@POST@@", post.replace("\\n","\n").strip())
open("wip/ui/install.sh","w").write(t)
PY
