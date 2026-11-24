# Desk SQL series: AD1, AD2, ... (his 21 Nov 2026 08:19 word; founder and awam keep the E series)
SCHEMA-FIRST LAW applies: before writing ADn read the schema that owns the tables (Desk tables are fadm_* ; the previous AD file; docs/claude/SQL-SCHEMA-FIRST-LAW-20NOV.md). First line of each file empty; each ADn has a CHECK and a selftest; desk_app role has grants on fadm_* only, ZERO on founder tables. Next free number = AD1 (nothing written yet). A Desk runner (ad-sql-run.sh) is written together with AD1.

## SQL file names are zero-padded since 23 Nov 05:0x PKT (his word: AD10 must sort after AD9): AD01..AD09b, AD10. Old docs saying AD1/AD7 mean AD01/AD07.


## ONE SERIES: AD (his 24 Nov 2026 07:47 order: the C series name is gone, every Admin Desk SQL is AD, in this ONE folder, forever)
AD21..AD26 = the files that used to be named CP1..CP6 (old CP1 = AD21, CP2 = AD22, CP3 = AD23, CP4 = AD24, CP5 = AD25, CP6 = AD26); checks in checks/AD21-check.sql .. AD26-check.sql.
WHICH DATABASE: AD01..AD20 run on the Desk's OWN database (ad-auto.sh / ad-sql-run.sh). AD21..AD26 run on the AWAM database (schema cp: read doors, consent, tenant registry) through scripts/cp-install.sh. Each of those six files carries the line "-- TARGET-DB: AWAM DATABASE" near its top, and ad-auto.sh and ad-sql-run.sh SKIP every file with that line, so a Desk run can never put them into the wrong database. A new AD file for the awam database must carry the same line.
AWAM and FOUNDER SQL stay in the E-series (docs/cursor-work/sql). Desk SQL is never in the E-series.
