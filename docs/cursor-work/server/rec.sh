#!/bin/bash
# HANDOFF TOOL (kept in the repo so a compaction cannot lose it). His 13 Nov 18:59 word: NO Co-Authored-By / noreply line in commits.
# usage: bash docs/cursor-work/server/rec.sh "<ledger line>" "<resume line>" "<commit subject>"
set -e
cd /home/claude/anexomail-workspace
python3 - "$1" "$2" <<'P'
import sys
line="\n- "+sys.argv[1]+"\n"
for p in ['docs/cursor-work/founder/founder-commands.md','docs/claude/DONE-DO-NOT-REPEAT.md','docs/cursor-work/DONE-DO-NOT-REPEAT.md','docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md','docs/claude/founder/PULL-COMMANDS.md','docs/cursor-work/server/PULL-COMMANDS.md','docs/claude/tech-contracts/CURRENT.md']:
    s=open(p).read(); open(p,'w').write(s.rstrip('\n')+"\n"+line)
L=open('docs/claude/RESUME-POINT.md').read().split('\n'); L.insert(2,"- "+sys.argv[1]); open('docs/claude/RESUME-POINT.md','w').write('\n'.join(L))
c=open('CLAUDE.md').read().split('\n'); c[0]="> ## >>> RESUME HERE: "+sys.argv[2]+" (rules-read.py, RESUME-POINT.md line 3, FOUNDER-MAILBOX-REAL-BUILD-PLAN-13NOV.md) <<<"; open('CLAUDE.md','w').write('\n'.join(c))
P
git add -A; for i in 1 2; do python3 lanes/lane-sync.py >/dev/null; git add -A; done
python3 docs/cursor-work/server/manifest-verify.py | awk '/PURANI/{print $2}' | xargs -r python3 docs/cursor-work/server/manifest-sync.py >/dev/null
python3 lanes/lane-sync.py >/dev/null
python3 docs/cursor-work/server/folder-rule-sync.py >/dev/null 2>&1 || true
python3 docs/cursor-work/server/manifest-verify.py | awk '/PURANI/{print $2}' | xargs -r python3 docs/cursor-work/server/manifest-sync.py >/dev/null
python3 docs/cursor-work/server/rules-read.py >/dev/null 2>&1
git add -A
python3 docs/cursor-work/server/rules-gate.py --staged 2>&1 | grep -v "^warn" | tail -3
git commit -q -m "$3

Phase: Q
Tech: Rust + Tokio + Axum, AES-256-GCM + ML-KEM-768 sealing, passkey touch gates, PostgreSQL RLS, React 19 + Framer Motion"
git push -q origin HEAD 2>&1 | grep -v moved | grep -v "github.com" | head -2
git log --oneline | head -1
