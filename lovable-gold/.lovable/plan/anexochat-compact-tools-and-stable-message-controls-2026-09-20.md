# ANEXOChat compact tools and stable message controls

## Scope
Only the existing ANEXOChat surface will change. Public ANEXOMAIL pages, AI workspace, founder workspace, backend routes, SQL, Rust, Caddy, plans, pricing, and authentication will not be touched.

## What will change
1. Replace the always-open **Tasks · Promises · Decisions** and **Workspace file engine** blocks above the conversation with one compact **+** control in the chat header/composer area.
2. Opening **+** will show the existing real features in a contained tools panel:
   - Task / Promise / Decision capture
   - File upload, transfer state, storage limits, stored versions, download, and file-safety results
3. Keep the tools panel closed by default so messages remain the main view. Closing it returns to the conversation without losing chat state.
4. Fix message actions so hovering or moving the pointer near a message never widens or stretches the message row:
   - keep the bubble width stable;
   - place actions in a fixed overlay anchored to the message;
   - move long provenance/device text behind the existing **More** action instead of injecting it into the row;
   - keep reaction choices compact and wrapping safely.
5. Apply the stable sizing pattern to shared ANEXOChat message controls at desktop and mobile widths, without adding a site-wide CSS override that could disturb mail, billing, AI, or founder pages.

## Existing project alignment
- Reuses the current `WorkStrip`, `FileTransfers`, `MessageStream`, and `MessageTruth` features; no duplicate or fake system is introduced.
- No API contract, database table, entitlement, upload/download, or call behavior changes.
- Business and Business Pro file permissions remain exactly as they are.
- Existing visual tokens and chat styling remain authoritative.

## Verification
- Check the chat with tools closed and open.
- Confirm all listed tools are reachable from **+**.
- Confirm message width does not change on hover, action clicks, reaction picker, or long device/provenance text.
- Check desktop and narrow/mobile layouts.
- Run the relevant formatting, lint, and type checks; report READY until deployed/live proof exists.
