# QC8b b4 ANNOUNCEMENTS: plan, search points, code (his word 21 Nov 2026 05:14 PKT: "web research, plan likho, search ke points, codes advance")
TECHNOLOGY: Element.ariaNotify (Baseline 2026) with the existing one-polite-live-region fallback (keys_list.announce), TypeScript, NEW FILE a11y_sem.ts (b4 added inside, mounted via the same KeyLayer call). No old file touched, nothing visible changes.

## Search points (21 Nov 2026; MDN page READ, others titles only)
1. MDN Element.ariaNotify: ariaNotify(text, {priority:"normal"|"high"}); normal = like aria-live polite, high = interrupts. Baseline 2026, newly available since Sept 2026; older browsers lack it -> fallback region stays.
2. Only the MOST RECENT announcement is reliably spoken -> combine messages. This is why the batch walker says ONE "Done for N mails" at the end and its synthetic re-sent keys are NOT announced one by one (isTrusted check).
3. aria-live announcements take priority over ariaNotify; do not spam. Errors already use role="alert" in the app (SettingsS2, PolicyEditor, Vault ...), so b4 adds nothing there.
4. Permissions-Policy aria-notify can block the call silently -> fallback region covers it (announce() already does try/catch + region).
5. WCAG 4.1.3 Status Messages (AA): status messages must be programmatically determinable without focus. UndoBar already has role=status aria-live=polite.
Sources: developer.mozilla.org/docs/Web/API/Element/ariaNotify ; w3.org/WAI/WCAG22/Techniques/aria/ARIA22 ; developer.mozilla.org/docs/Web/Accessibility/ARIA/ARIA_Live_Regions ; sarasoueidan.com accessible notifications with ARIA live regions.

## Design
- After a REAL key press (isTrusted, no modifiers, not repeat) of e # s u on the open mail, switch ON, no compose/dialog, not typing: say "Archived" / "Moved to Trash" / "Marked unread".
- Star: counts the row's icon marks, waits 900 ms for the server answer, then says "Starred" or "Unstarred" (falls back to "Star changed" if the marks did not change).
- Never says mail content (no sender, subject).
## Proof
Sandbox Playwright (ariaNotify stubbed): e -> Archived, u -> Marked unread, synthetic # -> silent, s -> Starred, typing in an input -> silent, switch OFF -> silent. LIVE in his Chrome after his install; 390/820 open.
