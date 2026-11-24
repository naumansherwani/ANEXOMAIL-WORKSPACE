# Desk SQL series: AD1, AD2, ... (his 21 Nov 2026 08:19 word; founder and awam keep the E series)
SCHEMA-FIRST LAW applies: before writing ADn read the schema that owns the tables (Desk tables are fadm_* ; the previous AD file; docs/claude/SQL-SCHEMA-FIRST-LAW-20NOV.md). First line of each file empty; each ADn has a CHECK and a selftest; desk_app role has grants on fadm_* only, ZERO on founder tables. Next free number = AD1 (nothing written yet). A Desk runner (ad-sql-run.sh) is written together with AD1.

## SQL file names are zero-padded since 23 Nov 05:0x PKT (his word: AD10 must sort after AD9): AD01..AD09b, AD10. Old docs saying AD1/AD7 mean AD01/AD07.


## CONTROL PLANE SQL (CP1..CP6) LIVES HERE TOO (his 24 Nov 2026 07:42 order: every Admin Desk SQL in the admin desk sql folder)
CP1.sql ... CP6.sql and checks/CP1-check.sql ... CP6-check.sql (the awam-database side of the Desk: cp schema, read doors, consent inbox, tenant registry) moved here from control-plane/sql. The installer (scripts/cp-install.sh) reads them from admin-desk/sql/. AWAM and FOUNDER SQL stay in the E-series (docs/cursor-work/sql); the Desk SQL (AD and CP) is never in the E-series.
