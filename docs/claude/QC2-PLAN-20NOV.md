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
