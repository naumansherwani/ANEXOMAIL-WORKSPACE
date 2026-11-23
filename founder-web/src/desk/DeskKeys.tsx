// ADMIN DESK 1m-keys: the Ctrl+K palette (every rail folder by name) and the Ctrl+/ Keys sheet. React 19 + TypeScript, pure logic in desk_keys.ts.
// WCAG 2.1.1: every folder also stays one click away in the rail. Dialog = role dialog, aria-modal; list = combobox + listbox; Esc closes and focus returns.
import { useEffect, useRef, useState } from "react";
import { searchItems, type Item } from "./desk_keys";

export type KeyItem = Item & { keys: string };
const CSS = `
.dkb-back{position:fixed;inset:0;z-index:60;background:rgba(5,9,16,.62);display:flex;align-items:flex-start;justify-content:center;padding:max(12vh,24px) 16px 16px}
.dkb-box{width:min(560px,100%);max-height:min(70vh,640px);display:flex;flex-direction:column;background:#0E1626;border:1px solid rgba(143,184,255,.35);border-radius:16px;box-shadow:0 24px 80px rgba(0,0,0,.55);color:#E8EEF9;font-family:inherit}
.dkb-h{margin:0;padding:16px 18px 6px;font-size:15px;font-weight:600}
.dkb-in{margin:8px 14px 10px;min-height:44px;border-radius:12px;border:1px solid rgba(143,184,255,.4);background:rgba(143,184,255,.07);color:inherit;font:inherit;font-size:15px;padding:0 14px}
.dkb-in:focus-visible{outline:2px solid #BFD6FF;outline-offset:2px}
.dkb-list{list-style:none;margin:0;padding:0 8px 10px;overflow-y:auto;scrollbar-width:thin}
.dkb-it{display:flex;align-items:center;justify-content:space-between;gap:12px;min-height:44px;padding:0 12px;border-radius:10px;cursor:pointer;font-size:14px}
.dkb-it[aria-selected=true]{background:rgba(111,166,242,.2);color:#fff}
.dkb-k{font-size:12px;color:#8FB8FF;white-space:nowrap}
.dkb-empty{padding:14px 18px;font-size:13px;color:#9AA7BD}
.dkb-foot{padding:0 18px 14px;font-size:12px;color:#9AA7BD}
@media (forced-colors:active){.dkb-box{border:2px solid CanvasText}.dkb-it[aria-selected=true]{outline:2px solid Highlight}}
`;
export function DeskKeys({ mode, items, onGo, onClose }: { mode: "palette" | "help"; items: KeyItem[]; onGo: (id: string) => void; onClose: () => void }) {
  const [q, setQ] = useState(""), [sel, setSel] = useState(0), inp = useRef<HTMLInputElement>(null), box = useRef<HTMLDivElement>(null);
  const shown = mode === "palette" ? searchItems(items, q) as KeyItem[] : items;
  useEffect(() => { const back = document.activeElement as HTMLElement | null; (mode === "palette" ? inp.current : box.current)?.focus(); return () => back?.focus?.(); }, [mode]);
  useEffect(() => { setSel(0); }, [q]);
  useEffect(() => { document.getElementById(`dkb-o-${sel}`)?.scrollIntoView({ block: "nearest" }); }, [sel]);
  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") { e.preventDefault(); onClose(); return; }
    if (mode !== "palette") return;
    if (e.key === "ArrowDown") { e.preventDefault(); setSel((s) => Math.min(shown.length - 1, s + 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setSel((s) => Math.max(0, s - 1)); }
    else if (e.key === "Enter") { e.preventDefault(); const it = shown[sel]; if (it) onGo(it.id); }
  };
  return (
    <div className="dkb-back" onPointerDown={(e) => { if (e.target === e.currentTarget) onClose(); }}><style>{CSS}</style>
      <div className="dkb-box" role="dialog" aria-modal="true" aria-label={mode === "palette" ? "Go to a folder" : "Keyboard shortcuts"} ref={box} tabIndex={-1} onKeyDown={onKey}>
        <p className="dkb-h" role="heading" aria-level={1}>{mode === "palette" ? "Go to a folder" : "Keyboard shortcuts"}</p>
        {mode === "palette" && <input ref={inp} className="dkb-in" role="combobox" aria-expanded="true" aria-controls="dkb-lb" aria-activedescendant={shown.length ? `dkb-o-${sel}` : undefined} aria-label="Type a folder name" placeholder="Type a folder name" value={q} onChange={(e) => setQ(e.target.value)} autoComplete="off" spellCheck={false} />}
        {shown.length === 0 ? <p className="dkb-empty">No folder matches.</p> : (
          <ul className="dkb-list" id="dkb-lb" role={mode === "palette" ? "listbox" : "list"} aria-label="Folders">
            {shown.map((it, i) => (
              <li key={it.id} id={`dkb-o-${i}`} className="dkb-it" role={mode === "palette" ? "option" : undefined} aria-selected={mode === "palette" ? i === sel : undefined} onPointerMove={() => mode === "palette" && setSel(i)} onClick={() => onGo(it.id)}>
                <span>{it.label}</span><span className="dkb-k">{it.keys}</span>
              </li>
            ))}
          </ul>
        )}
        <p className="dkb-foot">{mode === "palette" ? "Enter opens, Esc closes. Ctrl+/ lists every key." : "Ctrl+K search · Ctrl+D Dashboard · Alt+Shift+Up / Down walk the rail · Esc closes."}</p>
      </div>
    </div>
  );
}
