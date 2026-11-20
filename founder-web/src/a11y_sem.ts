// QC8b b2: screen-reader semantics, added as ATTRIBUTES ONLY on elements the mail page already renders.
// No node is inserted, no class changes, nothing visible changes. Existing files are untouched.
// Technology: TypeScript + MutationObserver (one observer, re-applied when React re-renders).
const SET: Array<[string, Array<[string, string]>]> = [
  // The wordmark is the page's one heading, spoken as "Mail" (level 1).
  [".mbx .mbx-brand b", [["role", "heading"], ["aria-level", "1"], ["aria-label", "Mail"]]],
  // A plain div with aria-label is ignored by screen readers; a group makes the label real.
  [".mbx .mbx-list", [["role", "group"]]],
  // The coloured dot already carries aria-label="unread"; an <i> has no role, so it was never spoken.
  [".mbx .mbx-dot", [["role", "img"]]],
];

/** Sets each attribute only when it differs, so the observer settles (no loop). */
function put(el: Element, name: string, value: string): void {
  if (el.getAttribute(name) !== value) el.setAttribute(name, value);
}

/** Applies every rule to the given root. Pure DOM, safe to call repeatedly. */
export function applySemantics(root: ParentNode): void {
  for (const [sel, attrs] of SET) root.querySelectorAll(sel).forEach((el) => attrs.forEach(([n, v]) => put(el, n, v)));
  // The open mail is the current item of the list (same marker the eye sees: class "on").
  root.querySelectorAll(".mbx .mbx-r").forEach((el) => {
    if (el.classList.contains("on")) put(el, "aria-current", "true");
    else if (el.hasAttribute("aria-current")) el.removeAttribute("aria-current");
  });
}

// QC8b b3: when the focused element is removed (compose or reader closes, focus falls to <body>),
// focus goes back to the mail row that was open, else the first row. Never steals focus otherwise.
let lost: EventTarget | null = null;
let lastRow: Element | null = null;
export function restoreFocus(doc: Document): void {
  const cur = doc.querySelector(".mbx .mbx-r.on"); if (cur) lastRow = cur;
  if (!lost || (lost as Element).isConnected) return;
  const a = doc.activeElement; if (a && a !== doc.body) { lost = null; return; }
  const row = (lastRow && lastRow.isConnected ? lastRow : doc.querySelector(".mbx .mbx-r")) as HTMLElement | null;
  lost = null; row?.focus({ preventScroll: true });
}

let started = false;
/** Starts once: applies now and again after every change under the body (class and child changes). */
export function trackSemantics(): void {
  if (started || typeof document === "undefined") return;
  started = true;
  let queued = false;
  const run = () => { queued = false; applySemantics(document); restoreFocus(document); };
  document.addEventListener("focusout", (e) => { lost = e.target; }, true);
  const mo = new MutationObserver(() => { if (!queued) { queued = true; queueMicrotask(run); } });
  mo.observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ["class"] });
  run();
}
