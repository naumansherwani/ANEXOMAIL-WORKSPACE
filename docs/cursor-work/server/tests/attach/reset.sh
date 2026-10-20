set -e
P="psql -h /var/run/postgresql -U postgres -q"
$P -c "drop database if exists e48" -c "create database e48" 2>/dev/null
$P -d e48 -v ON_ERROR_STOP=1 -f stubs.sql >/dev/null 2>&1
$P -d e48 -v ON_ERROR_STOP=1 -f /home/claude/anexomail-workspace/docs/cursor-work/sql/E48_outgoing_attachments.sql >/dev/null 2>&1
$P -d e48 -v ON_ERROR_STOP=1 -f seed.sql
