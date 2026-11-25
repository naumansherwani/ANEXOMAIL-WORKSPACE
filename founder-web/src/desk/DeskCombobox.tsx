import { useEffect, useId, useMemo, useRef, useState } from "react";
import { filterItems, splitMatch, stepActive, type ComboItem } from "./desk_registry_pure";

/** ADMIN DESK B13 T4i (25 Nov 2026): the Desk's searchable list. WAI-ARIA APG combobox with a listbox popup: the button announces role=combobox, the search box in the popup owns focus and points at the lit row with aria-activedescendant,
 *  arrows / Home / End / Enter / Escape work, rows are 44 px, the match is lit in the Desk's own blue. Colours are the Desk's own tokens (var(--line), var(--glass), var(--mute)) and the Desk button blue; nothing new. Nothing is guessed:
 *  an empty result says so. The choice is always one of the items it was given. Same code on 390 / 820 / 1200+ (the popup is as wide as the field and scrolls inside itself). Reduced motion is respected. */
export const COMBO_CSS = `
.dcb{position:relative;min-width:0}.dcb-t{width:100%;min-height:44px;display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid var(--line);border-radius:12px;background:var(--glass);color:inherit;font:inherit;cursor:pointer;text-align:left;max-width:100%}
.dcb-t:disabled{opacity:.5;cursor:default}.dcb-t:focus-visible,.dcb-t[aria-expanded=true]{outline:2px solid #8FB8FF;outline-offset:3px}
.dcb-g{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.dcb-g.ph{color:var(--mute)}
.dcb-c{display:inline-grid;place-items:center;min-width:30px;height:22px;padding:0 7px;margin-right:8px;border-radius:7px;border:1px solid var(--line);background:rgba(120,170,255,.16);font-size:11px;font-weight:700;letter-spacing:.06em;color:#8FB8FF;white-space:nowrap}
.dcb-v{width:16px;height:16px;flex:none;opacity:.7;transition:transform .15s}.dcb-t[aria-expanded=true] .dcb-v{transform:rotate(180deg)}
.dcb-p{position:absolute;z-index:40;left:0;right:0;top:calc(100% + 8px);border:1px solid rgba(160,200,255,.5);border-radius:14px;background:#09122A;box-shadow:0 26px 60px -14px rgba(0,0,0,.7),0 0 0 1px rgba(160,200,255,.05) inset;overflow:hidden;animation:dcb-in .14s ease-out}
@keyframes dcb-in{from{opacity:0;transform:translateY(-4px) scale(.985)}to{opacity:1;transform:none}}@media (prefers-reduced-motion:reduce){.dcb-p{animation:none}.dcb-v{transition:none}}
.dcb-s{display:flex;align-items:center;gap:10px;padding:0 14px;border-bottom:1px solid var(--line);min-height:48px}.dcb-s svg{width:16px;height:16px;opacity:.6;flex:none}
.dbx .dcb-s input{flex:1;min-width:0;min-height:46px;padding:0;background:transparent;border:0;border-radius:0;outline:0;color:inherit;font:inherit}
.dcb-k{font-size:11px;color:var(--mute);border:1px solid var(--line);border-radius:6px;padding:2px 6px;flex:none}
.dcb-l{max-height:min(46vh,320px);overflow:auto;padding:6px;scrollbar-width:thin;scrollbar-color:rgba(160,200,255,.5) transparent}
.dcb-o{display:flex;align-items:center;min-height:44px;padding:6px 10px;border-radius:10px;cursor:pointer;font-size:14px;border:1px solid transparent;gap:0}
.dcb-o[aria-selected=true]{background:rgba(120,170,255,.16);border-color:rgba(160,200,255,.5)}
.dcb-n{flex:1;min-width:0}.dcb-n small{display:block;font-size:12px;color:var(--mute);margin-top:2px;line-height:1.4}.dcb-a{font-size:12px;color:var(--mute);font-variant-numeric:tabular-nums;flex:none;margin-left:10px}
.dcb-o mark{background:none;color:#8FB8FF;font-weight:700}.dcb-e{padding:22px 14px;text-align:center;color:var(--mute);font-size:13px}
.dcb-f{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap;padding:9px 14px;border-top:1px solid var(--line);font-size:11px;color:var(--mute)}
`;

export function DeskCombobox({ label, items, value, onPick, placeholder, emptyWords, disabled = false }: { label: string; items: readonly ComboItem[]; value: string | null; onPick: (key: string) => void; placeholder: string; emptyWords: string; disabled?: boolean }) {
  const [open, setOpen] = useState(false), [q, setQ] = useState(""), [act, setAct] = useState(0);
  const id = useId(), root = useRef<HTMLDivElement>(null), btn = useRef<HTMLButtonElement>(null), inp = useRef<HTMLInputElement>(null);
  const list = useMemo(() => filterItems(items, q), [items, q]);
  const cur = items.find((i) => i.key === value) ?? null;
  useEffect(() => { setAct(list.length ? 0 : -1); }, [q, items]);   // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (open) inp.current?.focus(); }, [open]);
  useEffect(() => {
    if (!open) return;
    const away = (e: PointerEvent) => { if (root.current && !root.current.contains(e.target as Node)) close(false); };
    document.addEventListener("pointerdown", away); return () => document.removeEventListener("pointerdown", away);
  }, [open]);   // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (open && act >= 0) document.getElementById(`${id}o${act}`)?.scrollIntoView({ block: "nearest" }); }, [act, open, id]);
  function close(refocus: boolean) { setOpen(false); setQ(""); if (refocus) btn.current?.focus(); }
  function choose(i: ComboItem | undefined) { if (!i) return; onPick(i.key); close(true); }
  function key(e: React.KeyboardEvent) {
    if (e.key === "ArrowDown") { e.preventDefault(); setAct(stepActive(act, 1, list.length)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setAct(stepActive(act, -1, list.length)); }
    else if (e.key === "Home") { e.preventDefault(); setAct(list.length ? 0 : -1); }
    else if (e.key === "End") { e.preventDefault(); setAct(list.length - 1); }
    else if (e.key === "Enter") { e.preventDefault(); choose(list[act]); }
    else if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); close(true); }
    else if (e.key === "Tab") close(false);
  }
  const mark = (t: string) => { const [a, m, b] = splitMatch(t, q); return m ? <>{a}<mark>{m}</mark>{b}</> : <>{t}</>; };
  return (
    <div className="dcb" ref={root}>
      <button ref={btn} type="button" className="dcb-t" role="combobox" aria-haspopup="listbox" aria-expanded={open} aria-controls={`${id}l`} aria-label={label} disabled={disabled}
        onClick={() => setOpen(!open)} onKeyDown={(e) => { if (!open && (e.key === "ArrowDown" || e.key === "Enter" || e.key === " ")) { e.preventDefault(); setOpen(true); } }}>
        <span className={cur ? "dcb-g" : "dcb-g ph"}>{cur ? <>{cur.hint && <span className="dcb-c">{cur.hint}</span>}{cur.label}</> : placeholder}</span>
        <svg className="dcb-v" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><path d="M5 8l5 5 5-5" /></svg>
      </button>
      {open && <div className="dcb-p">
        <div className="dcb-s">
          <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><circle cx="9" cy="9" r="5.5" /><path d="M13.5 13.5L17 17" /></svg>
          <input ref={inp} type="text" role="searchbox" aria-label={`Search: ${label}`} aria-controls={`${id}l`} aria-activedescendant={act >= 0 ? `${id}o${act}` : undefined} autoComplete="off" spellCheck={false} placeholder="Type to search" value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={key} />
          <span className="dcb-k" aria-hidden="true">Esc</span>
        </div>
        <div className="dcb-l" id={`${id}l`} role="listbox" aria-label={label}>
          {list.length === 0 ? <div className="dcb-e" role="status">{emptyWords} Nothing is guessed.</div> : list.map((i, n) =>
            <div key={i.key} id={`${id}o${n}`} className="dcb-o" role="option" aria-selected={n === act} onMouseMove={() => n !== act && setAct(n)} onClick={() => choose(i)}>
              {i.hint && <span className="dcb-c">{i.hint}</span>}
              <span className="dcb-n">{mark(i.label)}{i.note && <small>{i.note}</small>}</span>
              {i.key === value && <svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="#8FB8FF" strokeWidth="2.4" aria-hidden="true"><path d="M4 10.5l4 4 8-9" /></svg>}
            </div>)}
        </div>
        <div className="dcb-f"><span>↑ ↓ to move · Enter to choose</span><span>{list.length} of {items.length}</span></div>
      </div>}
    </div>
  );
}
