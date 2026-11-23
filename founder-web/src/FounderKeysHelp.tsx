// FOUNDER Keys sheet (Ctrl+/): lists every founder key. New file, mounted by one line in App.tsx; the look is the Palette's (class "pal"), nothing restyled.
import { useEffect, useRef } from "react";
import { founderKeyLabel } from "./founder_keys";
export function FounderKeysHelp({ items, onClose }: { items: { id: string; name: string }[]; onClose: () => void }) {
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => { const back = document.activeElement as HTMLElement | null; box.current?.focus(); return () => back?.focus?.(); }, []);
  return (
    <div className="palwrap" onPointerDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="pal" role="dialog" aria-modal="true" aria-label="Keyboard shortcuts" ref={box} tabIndex={-1} onKeyDown={(e) => { if (e.key === "Escape") { e.preventDefault(); onClose(); } }}>
        <ul>
          {items.map((x) => <li key={x.id}><span>{x.name}</span><kbd>{founderKeyLabel(x.id) || "-"}</kbd></li>)}
          <li><span>Search every page</span><kbd>Ctrl+K</kbd></li><li><span>Walk the sidebar</span><kbd>Alt+Shift+Up / Down</kbd></li><li><span>Close</span><kbd>Esc</kbd></li>
        </ul>
      </div>
    </div>
  );
}
