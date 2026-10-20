# G38 attachments — local test kit (sandbox; server par kuch nahi chalta)
- `stubs.sql` + `E48_sql_test.sql` : E48 ke 37 SQL checks (local Postgres, db `e48`). `reset.sh` db banata hai.
- `mockpg.py` : Supabase ki nakal — `/auth/v1/user` + `/rest/v1/rpc/*` ko seedha local Postgres (E48 functions) par chalata hai.
- `runrust.sh` : asli crate (`attach_core/glue` judi hui) ka debug binary chalata hai; `e2e.sh` 37 checks (upload/dedup/virus/exe/traversal/download/tamper).
Natija 20 Oct 2026: SQL 37/37, Rust e2e 37/37, core unit 12/12.
- Mount test: `ATTACH_MOUNT=/tmp` (ya ATTACH_DIR kisi aise folder par jo asli mount nahi) => Rust 503 `storage_unavailable`; `ATTACH_MOUNT=none` sirf test ke liye check band karta hai. Live par kabhi `none` mat lagana.
- UI test (Playwright, scratchpad `attachui/`) repo mein nahi: Attach button, .exe/8 MB client refuse, EICAR/disguised PE server refuse, schedule payload `attachment_ids`, thread download bytes barabar — 1440/820/390 ALL OK.
- G38b: `stub_ingest.sql` (nakli mail_ingest), `E50_sql_test.sql` (19), `e2e_inbound.sh` (20; BIN=asli anexomail-deliver binary; mockpg + mockclamd chalu). Installer sim: PATH stubs (cargo/runuser/id/install/systemctl/findmnt) + nakli origin repo.
