HOW TO USE THIS DOCS SYSTEM (read this first, every time)

The problem this solves:
Claude sessions no longer auto-compact. A new session has ZERO memory of
past work unless you give it context. Copy-pasting a huge chat every time
is slow, lossy, and error-prone.

The fix: 3 living files instead of one giant chat.
This project keeps THREE short files in docs/claude chat history context/.

- 01_ARCHITECTURE.md = facts that rarely change (folder layout, which
  process is LIVE, deploy commands, tech stack)
- 02_STATUS.md = current state of every feature (done/in progress/broken)
- 03_CHANGELOG.md = running log, one line per real change, newest at top

THE PROTOCOL:

At the START of a new Claude chat, run this and paste the output:
cat "/opt/ANEXOMAIL-WORKSPACE/docs/claude chat history context/01_ARCHITECTURE.md" "/opt/ANEXOMAIL-WORKSPACE/docs/claude chat history context/02_STATUS.md" "/opt/ANEXOMAIL-WORKSPACE/docs/claude chat history context/03_CHANGELOG.md"

At the END of a session, tell Claude: "is session ka context docs mein likho"

To push updates to GitHub:
cd /opt/ANEXOMAIL-WORKSPACE
git add docs/
git commit -m "docs: update status/changelog"
git push origin main
