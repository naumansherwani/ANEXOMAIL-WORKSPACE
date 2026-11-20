# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https://it.cornell.edu/gsuite/choose-plain-or-formatted-text-gmail-google-workspace); ProseMirror forum XSS in prosemirror-view, GHSA-c8x8-7fp4-3x9w, fixed in 1.42.3 (https://discuss.prosemirror.net/t/xss-vulnerability-found-in-prosemirror-view/9067). Search result lists on Tiptap paste handling and Gmail plain text were not all opened.
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after Q3, from HIS OWN server only (no third party), as a small CID/hosted image.
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
4. Plain-text mode = per mail, NOT remembered (Gmail: per message, default stays formatted). Switching to plain text drops formatting and cannot be brought back, so ask "formatting will be removed" before switching.
POINTS, NAMED QC2-1 to QC2-7 (NOT the awam D4A 'P' points; build and prove in this order, all inside ONE founder phase):
P1 contract in tech-contracts/CURRENT.md (technology first). P2 SQL (next free number read from the ledger): signatures + snippets, forced RLS, sealed columns, hash-chain ledger, selftest + CHECK, sandbox PG17 proof. P3 Rust: ammonia allow-list, multipart/alternative (text/plain + HTML), DKIM over both, signature + snippet doors (signed, rate limited, 8 s timeouts), cargo tests. P4 browser: Tiptap 3 restricted schema, paste rules, toolbar (44 px, above keyboard), plain-text switch with warning, signature per From, snippet menu + unfilled-placeholder warning, kernel RPC only, bun tests. P5 his ONE sql-run + ONE founder-install. P6 my live Chrome 390 / 820 / 1200+, paste from Word, unfilled placeholder, plain-text switch. P7 ledger + blueprint + CURRENT.md, GREEN.

# QC2 (FOUNDER): RICH TEXT EDITOR (Tiptap 3), SIGNATURES, SNIPPETS. PLAN FOR DISCUSSION, 20 Nov 2026 05:3x PKT. His order 05:27: QC2 is ONE phase, no sub-phases, GREEN only when all of it is WIRED + REAL. Nothing built yet.
Research already done: docs/claude/COMPOSE-RESEARCH-17NOV.md section 1 (Tiptap 3 chosen: restricted ProseMirror schema, first-class HTML, ~130 KB gzip, same as Lexical; Lexical = fallback if Android IME / paste / undo proof fails).

## What exists today (checked in repo)
- Compose body = plain `<textarea>` (founder-web/src/MailCompose.tsx line 115). No rich text, no signature, no snippet.
- Founder Rust MIME builder (fmail_mime.rs, fmail_out.rs) sends text; HTML out is not built. No Rust `ammonia` in the founder crates yet. No signature/snippet SQL (next free SQL number to be read from the ledger before writing).

## The 5 parts (one phase, built and proven together, in this order)
1. **Editor:** Tiptap 3 with a restricted schema: paragraph, hard break, bold, italic, underline, link, bullet and ordered list, quote, code. Toolbar above the keyboard on phone (44 px), same code on 390 / 820 / 1200+. Emoji from QC1e keeps working. Plain-text mode toggle.
2. **Paste clean:** Word or web paste cannot bring other tags, styles, images or scripts (schema + custom paste rules).
3. **Server wall (Rust):** `ammonia` allow-list on send, links get rel=noopener, no remote images; the mail always carries a text/plain part (alternative) next to the HTML; DKIM signs both. Technology: Rust + Tokio + axum, MIME alternative via fmail_mime.
4. **Signatures per From address:** stored sealed (fmail_seal, AAD = mailbox), SQL table with forced RLS + hash-chain ledger line on change, default per From, inserted below the reply quote, editable in Settings and in compose. Door signed, kernel RPC (WebTransport/HTTP/3).
5. **Snippets `/name` with variables** ({first_name}, {my_name}, {date}): same sealed store + RLS, slash menu in the editor, variables filled from the chip / People book (QC1).

## Technology contract (written FIRST in tech-contracts/CURRENT.md before any code)
Rust Tokio Axum doors + WASM kernel RPC (no raw fetch), PostgreSQL forced RLS + hash-chained ledger + selftest + CHECK, React 19 + TypeScript + Tiptap 3 (ProseMirror), Tailwind 4, Radix/shadcn, Framer Motion; AES-256-GCM sealing of signatures and snippets; HTTP/3 only. No Bun/Node in runtime, no WebSocket.

## Order of work
contract in CURRENT.md -> SQL (+ selftest + CHECK, pglite/PG17 proof in sandbox) -> Rust (ammonia, alternative part, signature/snippet doors, cargo tests) -> browser (Tiptap, paste rules, toolbar, signature + snippet UI, bun tests) -> his ONE sql-run + ONE founder-install line -> my live Chrome (390 / 820 / 1200+, Android-like IME check, paste from Word) -> GREEN only WIRED: YES / REAL: YES / TECH-LAW CHECKED.

## Questions for him (answer before code)
1. Does an old mail he replies to / forwards keep its own HTML (QC4 later), or is QC2 only for what he writes? (default: only what he writes)
2. Signature: plain text + links only, or may it hold his logo image? (default: text + links only; image waits for Q3 attachments/inline CID)
3. Snippet variables: the three above enough? (default yes)
4. Plain-text mode: per mail, remembered per From address? (default per mail)
