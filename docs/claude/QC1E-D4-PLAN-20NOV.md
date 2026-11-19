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

---
## D4A BUILD PLAN POINTS, AWAM ONLY (20 Nov 2026 03:35 PKT, his order 03:02: "web research se codes help lo, phir repo main plan points likho")

### Research findings (what decided the technology)
1. **Re-encode crate = `image-webp` (image-rs, pure Rust).** Source: https://github.com/image-rs/image-webp. Facts: encoder is LOSSLESS ONLY, decoder reads lossy + lossless + alpha + animation, README says no `unsafe` in crate or deps, no C library. Consequence: no libwebp C code on his server (fits Rust-only law), but output is lossless, so the 64 KB cap is met by downscaling (256 -> 192 -> 128 px steps), never by lossy quality. Flat logos and badges (the real use) are small in lossless WebP.
2. **Decode side:** `image` crate with ONLY features png, jpeg, gif(first frame refused if animated), webp; no default features. SVG = refused (script risk), animated GIF/WebP/APNG = refused. Adding the crate is an opt-in module like "mig" in rust-engine-install.sh (crate-adding precedent).
3. **OWASP File Upload Cheat Sheet** (https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html), applied one by one: do not trust client Content-Type (we sniff magic bytes); decode + re-encode to ONE allowed format and strip all metadata (we do, WebP only); re-encode alone does not remove every threat, so resource limits + restricted formats + up-to-date library; max upload size; random server-side name (we never use the user's filename: key = sha256); only authenticated users with the right permission (owner/admin); store away from webroot (bytes in Postgres, Hetzner Storage Box with Q3); virus scan (ClamAV with Q3).
4. **Market reference (Discord support article 360041139231):** emoji < 256 KB, up to 128x128 shown at 32x32, JPEG/PNG/GIF/WEBP accepted, name >= 2 chars letters/numbers/underscore, 50 slots, upload is a role permission ("Create Expressions") and edit/remove another ("Manage Expressions"). Ours is stricter and simpler: <= 64 KB, <= 256 px source, owner+admin only, shortcode a-z0-9_- 2..24.

### Plan points (in build order, each closes with proof)
P1 SQL E193 + CHECK_E193 (DONE written 03:25, lint OK, 726 lines; NOT run yet): table, quota trigger, hash-chain ledger, doors, posture, selftest.
P2 Rust core `emoji_pack_core.rs` (pure std, unit tests): shortcode rules (same as SQL), reserved list (same as SQL), input limits (upload <= 512 KB, header w/h <= 4096 BEFORE decode, no animation, no SVG), magic-byte sniff, size ladder 256/192/128, output checks (RIFF....WEBP, <= 65536 bytes), sha256.
P3 Rust glue `emoji_pack_glue.rs`: procs `emoji.pack.list` (any org member), `emoji.pack.get` (member, returns bytes + ETag = sha, immutable cache), `emoji.pack.add` / `emoji.pack.remove` / `emoji.pack.alt` (owner/admin, auth_user + SQL door re-checks role), `emoji.pack.quota`. Uses crate::sb_rpc. Module wired in rust-engine-install.sh as opt-in (new crate), probe per proc, restore-on-fail.
P4 TS pure module `company_emoji_pure.ts` (+ bun tests): name rules mirror, merge of company items into picker groups and ":" list (company first, English alias name), text fallback `:acme:`.
P5 React awam: picker "Company" tab (image rows, 44 px touch targets, no sideways scroll), ":" list merge, admin screen (Settings > Company emoji: upload, preview, alt, remove, quota bar "7 / 10"); CSP self-only (images same-origin, no data: needed beyond existing).
P6 DEPLOY-MANIFEST entries for every new awam src file (manifest-sync.py <file>), lane-sync, rules-gate.
P7 His commands as SEPARATE numbered one-liners: 1 sql-run E193, 2 rust-engine-install (module emoji), 3 awam pull.sh. Founder install NOT needed (awam-only phase).
P8 Live Chrome look at laptop, ledger chain verify through CHECK_E193; GREEN only WIRED: YES / REAL: YES / TECH-LAW CHECKED. 390/820 looks stay after the Q series (his word).
D4B (separate, after Q3, Mon 23 Nov): real inline cid image inside the mail body (multipart/related) + Hetzner Storage Box + ClamAV scan of every upload.

### Open risks written down
- E193 not run anywhere yet (no local Postgres): first real run = his sql-run; fix by editing the same file if it fails.
- `org_plan_of` returns the owner's entitlement plan; real plan strings for Premium/MAX must match `%premium%` / `%max%` (selftest prints `plan_seen`).
- Lossless WebP of a photo-like picture may not fit 64 KB even at 128 px: then the door answers "too detailed, use a simple logo" (never silently lossy).
