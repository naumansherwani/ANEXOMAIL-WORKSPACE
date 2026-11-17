import { useEffect, useMemo, useRef } from "react";
import { Icon } from "./Brand";
import type { NavItem } from "./Palette";

// Phone "More": a bottom sheet with every page as a big tile (48 px+ targets, thumb zone), grouped. The tab bar keeps 5 destinations; the rest live here.
export function MoreSheet({ items, current, onPick, onClose }: { items: NavItem[]; current: string; onPick: (x: NavItem) => void; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => { ref.current?.focus(); const k = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); }; window.addEventListener("keydown", k); return () => window.removeEventListener("keydown", k); }, [onClose]);
  const groups = useMemo(() => { const m = new Map<string, NavItem[]>(); for (const x of items) m.set(x.group, [...(m.get(x.group) ?? []), x]); return [...m.entries()]; }, [items]);
  return (
    <div className="msw" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="msh" role="dialog" aria-modal="true" aria-label="All pages" tabIndex={-1} ref={ref}>
        <div className="msg" aria-hidden="true" />
        <div className="msbar"><b>All pages</b><button type="button" onClick={onClose} aria-label="Close">×</button></div>
        {groups.map(([g, xs]) => (
          <section key={g}><h3>{g}</h3>
            <div className="msgrid">{xs.map((x) => <button key={x.id} type="button" className={x.view === current ? "on" : ""} aria-current={x.view === current ? "page" : undefined} onClick={() => onPick(x)}><Icon k={x.icon} /><span>{x.name}</span></button>)}</div>
          </section>))}
      </div>
    </div>
  );
}
