import type { MouseEvent, ReactNode } from "react";
/** ADMIN DESK D1 (22 Nov 2026): a real link (href, so keyboard, middle click and "open in new tab" work) that moves inside the one Desk page with the History API.
 *  The live stream stays open across pages (one source for a card number and its rows). Modified clicks fall through to the browser. */
export type Nav = (to: string) => void;
export function DeskLink({ to, nav, className, children, label, keys, badge }: { to: string; nav: Nav; className?: string; children: ReactNode; label?: string; keys?: string; badge?: boolean }) {
  const click = (e: MouseEvent<HTMLAnchorElement>) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    e.preventDefault(); nav(to);
  };
  const hint = keys ? `Shortcut: ${keys}` : undefined;
  return <a href={to} className={className} onClick={click} aria-label={label} title={hint} aria-keyshortcuts={keys ? keys.replace(/G then /i, "g ").toLowerCase() : undefined}>{children}{badge && keys && <kbd className="dkbd" aria-hidden="true">{keys}</kbd>}</a>;
}
