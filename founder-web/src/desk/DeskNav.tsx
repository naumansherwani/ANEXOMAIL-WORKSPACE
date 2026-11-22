import type { MouseEvent, ReactNode } from "react";
/** ADMIN DESK D1 (22 Nov 2026): a real link (href, so keyboard, middle click and "open in new tab" work) that moves inside the one Desk page with the History API.
 *  The live stream stays open across pages (one source for a card number and its rows). Modified clicks fall through to the browser. */
export type Nav = (to: string) => void;
export function DeskLink({ to, nav, className, children, label }: { to: string; nav: Nav; className?: string; children: ReactNode; label?: string }) {
  const click = (e: MouseEvent<HTMLAnchorElement>) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    e.preventDefault(); nav(to);
  };
  return <a href={to} className={className} onClick={click} aria-label={label}>{children}</a>;
}
