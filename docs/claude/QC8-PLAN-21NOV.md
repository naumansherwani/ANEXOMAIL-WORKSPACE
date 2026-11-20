# QC8: SHORTCUTS AND ACCESSIBILITY FINAL PASS: PLAN (21 Nov 2026 03:20 PKT, his order 02:58: "QC8 shuru kero, plan and discuss do")
STATE: PLAN ONLY, NO CODE. Waits his answers to the 4 questions at the bottom. Founder side only. The cinematic UI is not restyled: additive code, focus and sound-of-screen-reader only (UI LAW: anything visible that is NEW is proposed to him first).

## What already exists (read in code 21 Nov, not guessed)
- founder-web/src/MailBox.tsx line 163-181: one window keydown handler. Keys: / search, r reply, a reply-all, f forward, j/k next/previous mail, c compose, g then a letter = folder (1.2 s chord), e / # move, s star, u unread, Esc close the mail. Guards: nothing fires while Compose is open (Q1b4), inside dialogs, or inside INPUT / TEXTAREA / contentEditable.
- Pure key map: founder-web/src/mail_keys.ts + mail_keys_pure.ts (golden tests in mail_keys_pure.test.ts).
- aria- attributes counted: MailBox 34, MailView 20, MailCompose 7, MailPresendBar 2, MailTimeline 4. Palette.tsx (Ctrl K) exists. MoreSheet closes on Esc.
- NOT found in code (to be proven by the audit step, not assumed): a "?" shortcut help sheet, a way to switch single-letter shortcuts off or remap them, focus return after Compose / dialogs close, aria-live announcements (sent, undone, error, scheduled), a keyboard path for the Undo bar and Presend bar, list semantics (listbox + roving tabindex) for the mail list, forced-colors / high-contrast check, 44 px touch targets check on every mail control.

## Technology (his law, nothing older): React 19 + TypeScript + Tailwind 4 + Radix (focus trap and focus return are Radix's job), Framer Motion only with reduced motion respected, pure TS key map with golden tests in bun. No new vendor. No server change, no SQL, no new listener. Test tools in MY sandbox only (axe-core, Playwright are not shipped to his site).

## Steps (each closes with proof; GREEN only after 390 / 820 / 1200+ in real Chrome)
1. AUDIT, read-only: a table of every mail control: reachable by keyboard? visible focus? accessible name? role? target size? contrast? Real Chrome keyboard walk (Tab order, Shift+Tab, Esc, Enter) + axe-core in the sandbox harness on the real built page. Output = the gap list, no code.
2. KEY MAP v2 (pure module + golden tests first): one table of every shortcut, per context (list, reading, compose, dialogs), conflict check against the browser and the screen reader, no key fires inside editable fields, Ctrl+Enter send, Esc order (close sheet, then dialog, then mail).
3. "?" HELP SHEET: a Radix dialog listing the shortcuts of the current screen (new visible panel: shown to him as a mock first).
4. FOCUS: after Compose / dialog / sheet closes, focus returns to the control that opened it; mail list becomes a real listbox with roving tabindex (arrow keys), the opened mail gets focus on open.
5. SCREEN READER: one polite live region for mail events (sent, undo available, scheduled, move, error, new mail), text in plain English, never the secret content.
6. SWITCH-OFF: single-letter shortcuts can be turned off or remapped in Settings (WCAG 2.1.4); stored as a founder setting through the existing settings door (no new SQL if the key registry already allows a free key; checked first).
7. CHECK: bun tests, tsc, vite build, rules-gate, axe-core 0 serious/critical, real-Chrome keyboard-only walk of: read, reply, compose, send, undo, move, search, switch-off. Then his install (founder-install) and my live look at 390 / 820 / 1200+.

## Questions for him (discuss)
1. Shortcuts: keep Gmail-style single letters (as now) AND add the "?" help sheet. Yes / no?
2. Switch-off/remap in Settings (needed for real accessibility; one new setting key). Yes / no?
3. Scope: mail screens + Palette first, whole founder app (Dashboard, Bridge, Settings) in a second pass. Or the whole app now?
4. Screen-reader text: English only (like the rest of the founder app). Yes / no?
