import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "./Brand.jsx";

// Ctrl/⌘+K: jump to any page. Only real destinations — every row opens an existing page.
export function Palette({ items, onPick, onClose }) {
  const [q, setQ] = useState(""), [i, setI] = useState(0), box = useRef(null);
  const list = useMemo(() => { const s = q.trim().toLowerCase(); return s ? items.filter((x) => `${x.name} ${x.group}`.toLowerCase().includes(s)) : items; }, [q, items]);
  useEffect(() => { box.current?.focus(); }, []);
  useEffect(() => { setI(0); }, [q]);
  useEffect(() => { document.querySelector(".pal li.on")?.scrollIntoView({ block: "nearest" }); }, [i]);
  const key = (e) => {
    if (e.key === "Escape") onClose();
    else if (e.key === "ArrowDown") { e.preventDefault(); setI((n) => Math.min(list.length - 1, n + 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setI((n) => Math.max(0, n - 1)); }
    else if (e.key === "Enter" && list[i]) { e.preventDefault(); onPick(list[i]); }
  };
  return (
    <div className="palwrap" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="pal" role="dialog" aria-modal="true" aria-label="Search pages" onKeyDown={key}>
        <input ref={box} value={q} onChange={(e) => setQ(e.target.value)} placeholder="Go to a page…" aria-label="Search pages" role="combobox" aria-expanded="true" aria-controls="pal-list" autoComplete="off" />
        <ul id="pal-list" role="listbox">
          {list.length === 0 ? <li className="none">Nothing matches “{q}”. Try a page name like Finance or Settings.</li> :
            list.map((x, n) => <li key={x.id} role="option" aria-selected={n === i} className={n === i ? "on" : ""} onMouseMove={() => setI(n)} onClick={() => onPick(x)}><Icon k={x.icon} /><span>{x.name}</span><em>{x.group}</em></li>)}
        </ul>
        <div className="palfoot"><span><kbd>↑</kbd><kbd>↓</kbd> move</span><span><kbd>Enter</kbd> open</span><span><kbd>Esc</kbd> close</span></div>
      </div>
    </div>
  );
}
