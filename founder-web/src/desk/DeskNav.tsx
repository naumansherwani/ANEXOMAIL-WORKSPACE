import type { MouseEvent, ReactNode } from "react";
/** ADMIN DESK D1 (22 Nov 2026): a real link (href, so keyboard, middle click and "open in new tab" work) that moves inside the one Desk page with the History API.
 *  The live stream stays open across pages (one source for a card number and its rows). Modified clicks fall through to the browser. */
export type Nav = (to: string) => void;
export function DeskLink({ to, nav, className, children, label, keys, badge }: { to: string; nav: Nav; className?: string; children: ReactNode; label?: string; keys?: string; badge?: boolean }) {
  const click = (e: MouseEvent<HTMLAnchorElement>) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    e.preventDefault(); nav(to);
  };
  // the white pop-up STAYS (his 22 Nov 08:07 word: "yeh white pop intact rahy"): native title shows the shortcut in the Claude style, e.g. "Open · Alt+Shift+A". No bordered badge on the cards any more.
  const hint = keys ? (typeof children === "string" ? children.replace(/\s*→\s*$/, "") : "Open") + " · " + keys : undefined;
  return <a href={to} className={className} onClick={click} aria-label={label} title={hint} aria-keyshortcuts={keys || undefined}>{children}</a>;
}
