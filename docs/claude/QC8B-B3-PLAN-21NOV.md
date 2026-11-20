# QC8b b3 FOCUS RETURN: plan, search points, code (his word 21 Nov 2026 04:55 PKT: "b3 shuru kero, plan repo main, search ke points likho")
TECHNOLOGY: TYPESCRIPT + MUTATIONOBSERVER + focusout (capture) + HTMLElement.focus({preventScroll}), NEW FILE a11y_sem.ts only (already mounted by KeyLayer). No old file touched, nothing visible changes.

## Problem
When Compose or the reader closes, the element that had focus is removed and focus falls to <body>: a keyboard / screen-reader user loses their place (WCAG 2.4.3 Focus Order, 3.2.x predictable). 

## Search points (web search 21 Nov 2026, titles + summaries only, full pages NOT read; sources listed)
1. Native <dialog> showModal() returns focus to the opener on close by itself: our "?" sheet already gets this, nothing to write.
2. inert attribute: background of a modal can be made unreachable; considered for the reader, NOT in b3 (separate haan, it changes tab behaviour).
3. focusgroup (Chrome, Open UI explainer, Intent to Ship): arrow-key roving inside a list by attribute. Support across browsers unclear -> NOT used; our existing j/k + Up/Down overlay already covers it.
4. Navigation API focusReset: about page navigations, not row return -> not used.
Sources: developer.chrome.com/blog/focusgroup-rfc ; open-ui.org/components/scoped-focusgroup.explainer ; groups.google.com Blink-dev Intent to Ship Focusgroup.

## Design (works in every browser)
- focusout (capture) remembers the element that lost focus.
- After each DOM change (same MutationObserver as b2): if that element is gone AND focus is on <body> -> focus the row that was open (class "on"), else the first row. Otherwise never touches focus (clicking elsewhere keeps its target).
## Proof
Sandbox Playwright: compose removed -> focus on the open row "b"; focusing another control afterwards stays there. LIVE proof in his Chrome after his install (open mail, Esc, check document.activeElement). 390/820 must also be seen (Rule 34).
