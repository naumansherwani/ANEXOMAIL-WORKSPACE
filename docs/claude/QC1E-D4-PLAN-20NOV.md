# QC1e D4: COMPANY EMOJI PACK (plan, written 20 Nov 2026 02:5x PKT, his order "D4 shuru kero discuss kero plan kero"; nothing built yet)
Rule: founder and awam are two gates (separate code, SQL, doors, pulls, ledgers). The pack is for the BUSINESS tiers of AWAM (a company's own logo / badges as emoji). Founder: only if he says yes (question 1).

## What it is
A company admin uploads small pictures (logo, badge, mascot) and gives each a name. In compose the company's members then find them in the picker (a "Company" tab) and by ":" typing (":acme"). In the mail the picture goes as an inline image; a mail program that blocks images shows the plain text ":acme:" instead (alt text).

## Technology (advance, no vendor)
- Rust (axum, Tokio) door: upload decodes the picture with a Rust image crate and RE-ENCODES it to a clean WebP (max 256 x 256, max 64 KB). Metadata and EXIF are dropped, magic bytes checked, animated and SVG refused (SVG = script risk). Hash (SHA-256) dedupes and names the file.
- SQL (above super advanced): table company_emoji (company_id, shortcode, sha256, bytes, w, h, alt, status, created_by, created_at) with FORCED row-level security per company, CHECK on shortcode shape (a-z 0-9 _ -, 2..24), unique per company, a per-tier quota enforced by trigger, append-only ledger table with a hash chain for every add / rename / remove, SQL selftest + CHECK file.
- Storage: bytes in Postgres (bytea, max 64 KB each, quota-capped) for now; moves to Hetzner Storage Box with Q3 (his Hetzner confirmation). ClamAV scan joins with Q3 as well (re-encode already removes the payload).
- Serving: same-origin immutable URL (ETag = sha256, long cache), CSP self-only stays; no third-party host.
- React 19 + TypeScript: "Company" tab in the picker, ":" list merges company emoji (image in the row, English alias as the name), pure module part (shortcode name rules, merge + rank) bun-tested; awam glue and founder glue separate.
- Sending: inline image needs a multipart/related (cid:) mail body. The mail builder gets that with QC2 (rich text) and Q3 (attachments). So: D4a now = library + admin + picker + ":" with the text fallback ":acme:" in the mail; D4b = real inline embedding after Q3 (Mon 23 Nov).
- Safety: only company owner / admin can add or remove (audit-ledger line each time); names like official / admin / support / system refused to stop impersonation; rate limit on uploads; every change is in the company's governance ledger.

## What I need from him (4 decisions)
1. Founder side also gets a pack (AnexoMail's own badges), or awam Business tiers only? (my advice: awam only now)
2. Quota per tier (his numbers). My default to start: Business 10, Premium 50, MAX 200 pictures.
3. Split D4a now + D4b after Q3 (my advice), or wait for the whole D4 until Q3?
4. Who may upload: owner + admin only (my advice), or any member?

## Order of work after his answers (same day)
1. Contract note in CURRENT.md, 2. SQL E-number + CHECK (his sql-run), 3. Rust door + tests, 4. pure TS module + tests, 5. awam glue + picker tab + ":" merge (awam gate, own pull, manifest entries for every new src file), 6. live Chrome look, 7. GREEN only WIRED: YES / REAL: YES / TECH-LAW CHECKED (+ his word).
