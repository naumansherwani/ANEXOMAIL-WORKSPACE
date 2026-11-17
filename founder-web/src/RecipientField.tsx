// QC1a (18 Nov 2026): one recipients row (To, Cc or Bcc) as address CHIPS. React 19 + TypeScript + Framer Motion, pure logic in recipients.ts.
// The form keeps ONE comma-joined string per row (so the sealed draft, the send door and the touch target are byte-for-byte unchanged); this component only edits that string.
// Accessibility (WAI-ARIA authoring practice for a list of removable items): the row is role=group with a name, the chips are a role=list, every chip has a Remove button with a name,
// the text box describes itself with the reasons line, and a polite live region says what happened. Keyboard: Enter , ; Space Tab or leaving the box makes a chip; Backspace selects then removes the last chip;
// Left/Right walk the chips; Delete removes; Enter edits; M or the menu key opens the chip menu. Pointer: double click edits, drag a chip onto another row. Touch: the chip menu (44 px targets).
import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { asChipText, DEBOUNCE_MS, suggest, type Contact } from "./book";
import { addText, chipsOf, initial, joinChips, label, looksComplete, removeChip, type Chip, type Field } from "./recipients";

export const DRAG_MIME = "application/x-anexo-chip";
const MAX_CHIPS = 100;

export type RowProps = {
  field: Field; value: string; onChange: (v: string) => void;
  taken: Record<string, Field>;                                   // every address already in To / Cc / Bcc
  onMove: (addr: string, raw: string, from: Field, to: Field) => void;
  onDragActive?: (on: boolean) => void;                           // the parent shows the Cc / Bcc rows while a chip is being dragged
  inputRef?: React.RefObject<HTMLInputElement | null>;
  trailing?: React.ReactNode; placeholder?: string; autoFocus?: boolean;
  book?: Contact[];                                               // QC1b: the opened address book (top 500); suggestions are filtered here while typing, no server call
  onBookAct?: (c: Contact, op: "forget" | "pin" | "unpin") => void;
};

const key = (c: Chip) => c.addr ?? c.raw;
const OTHERS: Record<Field, Field[]> = { To: ["Cc", "Bcc"], Cc: ["To", "Bcc"], Bcc: ["To", "Cc"] };

export function RecipientField({ field, value, onChange, taken, onMove, onDragActive, inputRef, trailing, placeholder, book, onBookAct }: RowProps) {
  const reduceHook = useReducedMotion(), calm = !!reduceHook || (typeof document !== "undefined" && document.documentElement.dataset.motion !== "full");
  const uid = useId(), own = useRef<HTMLInputElement>(null), box = inputRef ?? own;
  const [text, setText] = useState(""), [sel, setSel] = useState(-1), [menu, setMenu] = useState(-1), [live, setLive] = useState(""), [note, setNote] = useState(""), [over, setOver] = useState(false);
  const chips = useMemo(() => chipsOf(value), [value]);
  // QC1b suggestions: filtered from the opened book after a 150 ms pause, from 2 characters, never an address that is already in a row, 8 at most
  const [dq, setDq] = useState(""), [act, setAct] = useState(-1), [shut, setShut] = useState(false);
  useEffect(() => { const t = window.setTimeout(() => { setDq(text); setAct(-1); setShut(false); }, DEBOUNCE_MS); return () => window.clearTimeout(t); }, [text]);
  const hits = useMemo(() => (book && book.length ? suggest(book, dq, taken, Date.now()) : []), [book, dq, taken]);
  const showSug = hits.length > 0 && !shut && text.trim().length >= 2;
  const pick = (i: number) => { const h = hits[i]; if (!h) return; if (commit(asChipText(h.c))) { setText(""); setDq(""); setAct(-1); } };
  const refs = useRef<(HTMLLIElement | null)[]>([]);
  const bad = chips.filter((c) => !c.addr);
  const tell = useCallback((m: string) => { setLive(""); window.setTimeout(() => setLive(m), 20); }, []);

  useEffect(() => { if (sel >= 0 && sel < chips.length) refs.current[sel]?.focus(); }, [sel, chips.length]);
  useEffect(() => { if (menu < 0) return; const off = (e: Event) => { const t = e.target as Node; if (!(t instanceof Node) || !document.getElementById(`${uid}-menu`)?.contains(t)) setMenu(-1); }; document.addEventListener("pointerdown", off); return () => document.removeEventListener("pointerdown", off); }, [menu, uid]);

  /** Turn typed or pasted text into chips. Refusals are shown and said aloud. */
  const commit = useCallback((raw: string): boolean => {
    if (!raw.trim()) return false;
    const r = addText(chips, raw, field, taken);
    const room = MAX_CHIPS - chips.length; let added = r.added;
    let next = r.chips;
    if (added.length > room) { next = r.chips.slice(0, chips.length + Math.max(0, room)); added = added.slice(0, Math.max(0, room)); setNote(`At most ${MAX_CHIPS} recipients in one row`); }
    else setNote(r.skipped.length ? r.skipped.map((s) => `${s.piece}: ${s.reason}`).join(" · ") : "");
    if (next !== chips && added.length) onChange(joinChips(next));
    const okN = added.filter((c) => c.addr).length, badN = added.length - okN;
    tell([okN ? `Added ${okN === 1 ? added.find((c) => c.addr)!.addr : okN + " addresses"} to ${field}` : "", badN ? `${badN} not valid` : "", r.skipped.length ? r.skipped.map((s) => `${s.piece} ${s.reason}`).join(", ") : ""].filter(Boolean).join(". "));
    return added.length > 0 || r.skipped.length > 0;
  }, [chips, field, taken, onChange, tell]);

  const drop = (i: number) => { const c = chips[i]; if (!c) return; onChange(joinChips(removeChip(chips, key(c)))); tell(`Removed ${label(c)} from ${field}`); setSel(-1); setMenu(-1); box.current?.focus(); };
  const edit = (i: number) => { const c = chips[i]; if (!c) return; onChange(joinChips(removeChip(chips, key(c)))); setText(c.raw); setSel(-1); setMenu(-1); window.setTimeout(() => { box.current?.focus(); box.current?.select(); }, 0); };
  const move = (i: number, to: Field) => { const c = chips[i]; if (!c || !c.addr) return; onMove(c.addr, c.raw, field, to); setMenu(-1); setSel(-1); tell(`Moved ${label(c)} to ${to}`); };

  function onKey(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.nativeEvent.isComposing) return;                         // an IME is still choosing characters
    const k = e.key;
    if (showSug && k === "ArrowDown") { e.preventDefault(); setAct((a) => (a + 1) % hits.length); return; }
    if (showSug && k === "ArrowUp") { e.preventDefault(); setAct((a) => (a <= 0 ? hits.length - 1 : a - 1)); return; }
    if (showSug && act >= 0 && (k === "Enter" || k === "Tab")) { e.preventDefault(); pick(act); return; }
    if (showSug && k === "Escape") { e.stopPropagation(); setShut(true); return; }
    if (k === "Enter" || k === "," || k === ";") { if (text.trim()) { e.preventDefault(); if (commit(text)) setText(""); } else if (k !== "Enter") e.preventDefault(); return; }
    if (k === " " && looksComplete(text)) { e.preventDefault(); if (commit(text)) setText(""); return; }
    if (k === "Backspace" && !text && chips.length) { e.preventDefault(); if (sel === chips.length - 1) drop(sel); else setSel(chips.length - 1); return; }
    if (k === "ArrowLeft" && !text && chips.length && (e.currentTarget.selectionStart ?? 0) === 0) { e.preventDefault(); setSel(chips.length - 1); return; }
    if (k === "Escape" && (text || note)) { e.stopPropagation(); setText(""); setNote(""); }
  }
  function onChipKey(e: React.KeyboardEvent<HTMLLIElement>, i: number) {
    const k = e.key;
    if (k === "ArrowLeft") { e.preventDefault(); setSel(Math.max(0, i - 1)); }
    else if (k === "ArrowRight") { e.preventDefault(); if (i >= chips.length - 1) { setSel(-1); box.current?.focus(); } else setSel(i + 1); }
    else if (k === "Delete" || k === "Backspace") { e.preventDefault(); drop(i); }
    else if (k === "Enter") { e.preventDefault(); edit(i); }
    else if (k === "m" || k === "M" || k === "ContextMenu" || (k === "F10" && e.shiftKey)) { e.preventDefault(); setMenu(menu === i ? -1 : i); }
    else if (k === "Escape") { e.stopPropagation(); if (menu >= 0) setMenu(-1); else { setSel(-1); box.current?.focus(); } }
    else if (k === "Home") { e.preventDefault(); setSel(0); } else if (k === "End") { e.preventDefault(); setSel(chips.length - 1); }
  }
  function flush() { if (text.trim() && commit(text)) setText(""); }
  function onText(v: string) { if (/[,;\n\r]/.test(v)) { if (commit(v)) { setText(""); return; } } setText(v); if (note) setNote(""); }
  function onPaste(e: React.ClipboardEvent<HTMLInputElement>) { const t = e.clipboardData.getData("text"); if (!t) return; e.preventDefault(); if (commit(text + t)) setText(""); }

  const dropProps = {
    onDragOver: (e: React.DragEvent) => { if (e.dataTransfer.types.includes(DRAG_MIME)) { e.preventDefault(); e.dataTransfer.dropEffect = "move"; setOver(true); } },
    onDragLeave: () => setOver(false),
    onDrop: (e: React.DragEvent) => {
      setOver(false); const raw = e.dataTransfer.getData(DRAG_MIME); if (!raw) return; e.preventDefault();
      try { const d = JSON.parse(raw) as { addr: string; raw: string; from: Field }; if (d.from !== field && d.addr) onMove(d.addr, d.raw, d.from, field); } catch { /* not ours */ }
    },
  };
  const spring = calm ? { duration: 0 } : { type: "spring" as const, stiffness: 520, damping: 34, mass: 0.7 };

  return (
    <div className={`mc-f rf${over ? " rf-over" : ""}${bad.length ? " rf-has-bad" : ""}`} role="group" aria-label={`${field} recipients`} data-field={field} {...dropProps}
         onClick={(e) => { if (e.target === e.currentTarget || (e.target as HTMLElement).classList.contains("rf-chips")) { setSel(-1); box.current?.focus(); } }}>
      <span aria-hidden="true">{field}</span>
      <div className="rf-body">
        <ul className="rf-chips" role="list" aria-label={`${field}: ${chips.length} ${chips.length === 1 ? "recipient" : "recipients"}`}>
          <AnimatePresence initial={false} mode="popLayout">
            {chips.map((c, i) => (
              <motion.li key={key(c)} layout={!calm ? "position" : false} initial={calm ? false : { opacity: 0, scale: 0.86 }} animate={{ opacity: 1, scale: 1 }} exit={calm ? { opacity: 0 } : { opacity: 0, scale: 0.86 }} transition={spring}
                ref={(el) => { refs.current[i] = el; }} className={`rf-li${sel === i ? " sel" : ""}`} role="listitem" tabIndex={sel === i ? 0 : -1}
                aria-label={c.addr ? `${label(c)}${c.name ? ", " + c.addr : ""}` : `${c.raw}, not valid: ${c.reason}`} aria-invalid={c.addr ? undefined : true}
                onFocus={() => setSel(i)} onKeyDown={(e) => onChipKey(e, i)} onDoubleClick={() => edit(i)}>
                <div className={`rf-chip${c.addr ? "" : " bad"}`} title={c.addr ? c.addr : `${c.raw}: ${c.reason}`} draggable={!!c.addr}
                  onDragStart={(e) => { if (!c.addr) return; e.dataTransfer.setData(DRAG_MIME, JSON.stringify({ addr: c.addr, raw: c.raw, from: field })); e.dataTransfer.setData("text/plain", c.addr); e.dataTransfer.effectAllowed = "move"; onDragActive?.(true); }}
                  onDragEnd={() => onDragActive?.(false)}>
                <i className="rf-dot" aria-hidden="true">{c.addr ? initial(c) : "!"}</i>
                <span className="rf-txt">{label(c)}</span>
                <button type="button" className="rf-act" aria-haspopup="menu" aria-expanded={menu === i} aria-label={`Options for ${label(c)}`} tabIndex={-1} onClick={(e) => { e.stopPropagation(); setSel(i); setMenu(menu === i ? -1 : i); }}>⋯</button>
                <button type="button" className="rf-x" aria-label={`Remove ${label(c)}`} tabIndex={-1} onClick={(e) => { e.stopPropagation(); drop(i); }}>×</button>
                </div>
                {menu === i && (
                  <div className="rf-menu" id={`${uid}-menu`} role="menu" aria-label={`${label(c)}`} onKeyDown={(e) => { if (e.key === "Escape") { e.stopPropagation(); setMenu(-1); refs.current[i]?.focus(); } }}>
                    {c.addr && OTHERS[field].map((f) => <button key={f} type="button" role="menuitem" autoFocus={f === OTHERS[field][0]} onClick={() => move(i, f)}>Move to {f}</button>)}
                    <button type="button" role="menuitem" onClick={() => edit(i)}>Edit</button>
                    <button type="button" role="menuitem" className="danger" onClick={() => drop(i)}>Remove</button>
                  </div>
                )}
              </motion.li>
            ))}
          </AnimatePresence>
          <li className="rf-in" role="presentation">
            <input ref={box} value={text} onChange={(e) => onText(e.target.value)} onKeyDown={onKey} onPaste={onPaste} onBlur={flush}
              placeholder={chips.length ? "" : (placeholder ?? "name@example.com")} autoComplete="off" autoCapitalize="none" autoCorrect="off" spellCheck={false} inputMode="email" enterKeyHint="next"
              role="combobox" aria-expanded={showSug} aria-controls={`${uid}-sug`} aria-autocomplete="list" aria-activedescendant={showSug && act >= 0 ? `${uid}-s${act}` : undefined}
              aria-label={`Add to ${field}`} aria-describedby={bad.length || note ? `${uid}-why` : undefined} />
          </li>
        </ul>
        {(bad.length > 0 || note) && (
          <p className="rf-why" id={`${uid}-why`}>
            {bad.map((c) => <span key={c.raw} className="b">{c.raw}: {c.reason}</span>)}
            {note && <span className="n">{note}</span>}
          </p>
        )}
      </div>
      {trailing}
      {showSug && (
        <ul className="rf-sug" id={`${uid}-sug`} role="listbox" aria-label={`Suggestions for ${field}`}>
          {hits.map((h, i) => (
            <li key={h.c.id} id={`${uid}-s${i}`} role="option" aria-selected={act === i} className={`rf-opt${act === i ? " on" : ""}`}
                onMouseDown={(e) => { e.preventDefault(); pick(i); }} onMouseEnter={() => setAct(i)}>
              <i className="rf-dot" aria-hidden="true">{(h.c.name || h.c.addr).replace(/[^\p{L}\p{N}]/gu, "").charAt(0).toUpperCase() || "?"}</i>
              <span className="rf-ot"><b>{h.c.name || h.c.addr}</b>{h.c.name && <small>{h.c.addr}</small>}</span>
              {onBookAct && <button type="button" className="rf-pinb" tabIndex={-1} aria-label={h.c.pinned ? `Unpin ${h.c.name || h.c.addr}` : `Pin ${h.c.name || h.c.addr} to the top`} onMouseDown={(e) => { e.preventDefault(); e.stopPropagation(); onBookAct(h.c, h.c.pinned ? "unpin" : "pin"); }}>{h.c.pinned ? "★" : "☆"}</button>}
              {onBookAct && <button type="button" className="rf-forget" tabIndex={-1} aria-label={`Remove ${h.c.name || h.c.addr} from suggestions`} onMouseDown={(e) => { e.preventDefault(); e.stopPropagation(); onBookAct(h.c, "forget"); }}>×</button>}
            </li>
          ))}
        </ul>
      )}
      <span className="sr" role="status" aria-live="polite">{live}</span>
    </div>
  );
}
