// QC1e-D2 (20 Nov 2026): ":" shortcode typeahead for the compose message box. Plan: docs/claude/QC1E-D2-PLAN-20NOV.md.
// React 19 + TypeScript. WAI-ARIA 1.2 combobox (textarea + listbox). Pure logic in emoji_pure.ts. Data = the picker's bundled emojibase chunks, loaded on the first ":xx".
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useCallback, useDeferredValue, useEffect, useId, useMemo, useRef, useState } from "react";
import { acceptShortcode, loadList, loadTone, pushRecent, rankRecent, RECENT_KEY, shortcodeAt, shortcodeSearch, TONE_KEY, withTone, type Emoji, type Group } from "./emoji_pure";
import { loadData } from "./EmojiPicker";
import "./emoji.css";

type Data = { all: Emoji[]; groups: Group[] };
const rd = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const wr = (k: string, v: string) => { try { window.localStorage.setItem(k, v); } catch { /* storage may be blocked: the emoji is still inserted */ } };

export type Shortcode = {
  /** spread on the message textarea */
  bind: {
    onKeyDown: (e: React.KeyboardEvent<HTMLTextAreaElement>) => void; onKeyUp: () => void; onClick: () => void; onBlur: () => void;
    onCompositionStart: () => void; onCompositionEnd: () => void;
    "aria-autocomplete": "list"; "aria-expanded": boolean; "aria-controls"?: string; "aria-activedescendant"?: string;
  };
  listId: string; items: { e: Emoji; unicode: string; label: string }[]; active: number; open: boolean; pick: (i: number) => void; setActive: (i: number) => void;
};

export function useShortcode({ area, value, onChange }: { area: React.RefObject<HTMLTextAreaElement | null>; value: string; onChange: (v: string) => void }): Shortcode {
  const listId = useId(), [hit, setHit] = useState<{ start: number; query: string } | null>(null), [data, setData] = useState<Data | null>(null);
  const [active, setActive] = useState(0), [dismissed, setDismissed] = useState<string | null>(null), composing = useRef(false), loading = useRef(false);
  const look = useCallback(() => { const t = area.current; if (!t || composing.current) return; setHit(shortcodeAt(t.value, t.selectionStart ?? t.value.length)); }, [area]);
  useEffect(() => { look(); }, [value, look]);
  useEffect(() => { if (hit && !data && !loading.current) { loading.current = true; loadData().then(setData).catch(() => { loading.current = false; }); } }, [hit, data]);
  const q = useDeferredValue(hit?.query ?? "");
  const items = useMemo(() => {
    if (!hit || !data || dismissed === `${hit.start}:${hit.query}`) return [];
    const tone = loadTone(rd(TONE_KEY)), found = rankRecent(shortcodeSearch(data.all, data.groups, q, 24), loadList(rd(RECENT_KEY))).slice(0, 8);
    return found.map((e) => { const w = withTone(e, tone); return { e, unicode: w.unicode, label: w.label }; });
  }, [hit, data, q, dismissed]);
  useEffect(() => { setActive(0); }, [q, dismissed]);
  useEffect(() => { if (dismissed && (!hit || dismissed !== `${hit.start}:${hit.query}`)) setDismissed(null); }, [hit, dismissed]); // Escape hides only this exact ":name"; any other text brings the list back
  const open = items.length > 0;
  const pick = useCallback((i: number) => {
    const t = area.current, it = items[i]; if (!t || !it || !hit) return;
    const caret = t.selectionStart ?? value.length, r = acceptShortcode(value, hit.start, caret, it.unicode);
    wr(RECENT_KEY, JSON.stringify(pushRecent(loadList(rd(RECENT_KEY)), it.e.hexcode))); onChange(r.text); setHit(null);
    window.requestAnimationFrame(() => { t.focus(); t.setSelectionRange(r.caret, r.caret); });
  }, [area, items, hit, value, onChange]);
  const onKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (!open || e.nativeEvent.isComposing || composing.current) return;
    if (e.key === "ArrowDown") { e.preventDefault(); setActive((a) => (a + 1) % items.length); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setActive((a) => (a - 1 + items.length) % items.length); }
    else if ((e.key === "Enter" && !e.ctrlKey && !e.metaKey && !e.shiftKey) || (e.key === "Tab" && !e.shiftKey)) { e.preventDefault(); e.stopPropagation(); pick(active); }
    else if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); if (hit) setDismissed(`${hit.start}:${hit.query}`); }
  };
  return {
    bind: { onKeyDown, onKeyUp: look, onClick: look, onBlur: () => setDismissed(hit ? `${hit.start}:${hit.query}` : null), onCompositionStart: () => { composing.current = true; }, onCompositionEnd: () => { composing.current = false; look(); }, "aria-autocomplete": "list", "aria-expanded": open, "aria-controls": open ? listId : undefined, "aria-activedescendant": open ? `${listId}-${active}` : undefined },
    listId, items, active, open, pick, setActive,
  };
}

/** The list. Put it inside the .emo-over wrapper, next to EmojiDock. Motion = the same engine as the picker (motion/react): the list fades and rises 6 px (0.14 s), and the highlight is ONE shared-layout pill that springs from row to row. Reduced motion (the OS or the app's Animations setting) = no movement at all. */
export function EmojiShortcodeList({ sc }: { sc: Shortcode }) {
  const reduce = useReducedMotion(), hl = { type: "spring" as const, stiffness: 520, damping: 42, mass: 0.6 };
  return (
    <>
      <AnimatePresence initial={false}>
        {sc.open && (
          <motion.ul key="l" className="emo-sc" id={sc.listId} role="listbox" aria-label="Emoji suggestions" style={{ transformOrigin: "bottom left" }}
            initial={reduce ? false : { opacity: 0, y: 6, scale: 0.98 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={reduce ? { opacity: 0, transition: { duration: 0 } } : { opacity: 0, y: 4, scale: 0.98 }} transition={{ duration: 0.14, ease: [0.2, 0.8, 0.2, 1] }}>
            {sc.items.map((it, i) => (
              <li key={it.e.hexcode} id={`${sc.listId}-${i}`} role="option" aria-selected={i === sc.active} className="emo-sc-i" onMouseEnter={() => sc.setActive(i)} onMouseDown={(ev) => { ev.preventDefault(); sc.pick(i); }}>
                {i === sc.active && <motion.span layoutId={`${sc.listId}-hl`} className="emo-sc-hl" aria-hidden="true" transition={reduce ? { duration: 0 } : hl} />}
                <span className="emo-sc-g" aria-hidden="true">{it.unicode}</span><span className="emo-sc-n">{it.label}</span>
              </li>
            ))}
          </motion.ul>
        )}
      </AnimatePresence>
      {sc.open && <p className="sr" role="status" aria-live="polite">{sc.items.length} emoji suggestions</p>}
    </>
  );
}
