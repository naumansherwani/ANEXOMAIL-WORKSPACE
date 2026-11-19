// QC1e (19 Nov 2026): the emoji picker of the compose window. React 19 + TypeScript + motion. Data = emojibase-data (Unicode 17), bundled and loaded lazily on first open: no network, no vendor.
// Pure logic is in emoji_pure.ts (bun-tested). Inserts at the caret of the message box. 44 px targets, keyboard (arrows, Enter, Escape), role=dialog + grid, reduced motion respected.
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { buildUr, inGroup, insertAt, loadList, loadTone, pushRecent, RECENT_KEY, search, TONE_KEY, TONES, withTone, type Emoji, type Group, type Tone, type UrIndex } from "./emoji_pure";
import "./emoji.css";

type Data = { all: Emoji[]; groups: Group[]; ur: UrIndex }; // ur = QC1e-D3 Urdu + Roman Urdu search words (own list, lazy chunk)
let cache: Promise<Data> | null = null;
export function loadData(): Promise<Data> {
  cache ??= Promise.all([import("emojibase-data/en/compact.json"), import("emojibase-data/en/messages.json"), import("./emoji_ur_data")]).then(([c, m, u]) => ({ all: (c.default as unknown as Emoji[]), groups: (m.default as unknown as { groups: Group[] }).groups, ur: buildUr(u.UR_DATA) }));
  return cache;
}
let vcache: Promise<Record<string, string[]>> | null = null;
export function loadVersions(): Promise<Record<string, string[]>> { vcache ??= import("emojibase-data/versions/emoji.json").then((m) => m.default as unknown as Record<string, string[]>); return vcache; }
const rd = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const wr = (k: string, v: string) => { try { window.localStorage.setItem(k, v); } catch { /* the picker works without storage */ } };
const GROUP_ICON: Record<string, string> = { "smileys-emotion": "😀", "people-body": "👋", "animals-nature": "🐻", "food-drink": "🍔", "travel-places": "✈️", activities: "⚽", objects: "💡", symbols: "❤️", flags: "🏁" };
const COLS = 8;

/** His order 19 Nov 14:23: the emoji button is the founder's own look (a square button beside Send, in the footer row), on founder AND awam. The picker opens DOCKED under the message box (in the page flow: never floating over To / Subject, never cut off). One shared module, two glues, separate gates. */
export type Dock = { open: boolean; toggle: () => void; close: () => void; btn: React.RefObject<HTMLButtonElement | null> };
export function useEmojiDock(): Dock {
  const [open, setOpen] = useState(false), btn = useRef<HTMLButtonElement>(null);
  const toggle = useCallback(() => setOpen((o) => !o), []);
  const close = useCallback(() => { setOpen(false); btn.current?.focus(); }, []);
  return { open, toggle, close, btn };
}
export function EmojiToggle({ dock, className = "mx-btn alt" }: { dock: Dock; className?: string }) {
  return (
    <button ref={dock.btn} type="button" className={`${className} emo-btn emo-toggle`} aria-haspopup="dialog" aria-expanded={dock.open} aria-label="Insert emoji" title="Emoji" onClick={dock.toggle}>
      <span aria-hidden="true">🙂</span>
    </button>
  );
}
export function EmojiDock({ dock, area, value, onChange }: { dock: Dock; area: React.RefObject<HTMLTextAreaElement | null>; value: string; onChange: (v: string) => void }) {
  const pick = useCallback((e: string) => {
    const t = area.current, s = t?.selectionStart ?? value.length, en = t?.selectionEnd ?? value.length;
    const r = insertAt(value, s, en, e); onChange(r.text);
    window.requestAnimationFrame(() => { if (t) { t.focus(); t.setSelectionRange(r.caret, r.caret); } });
  }, [area, value, onChange]);
  return <AnimatePresence initial={false}>{dock.open && <Picker key="p" onPick={pick} onClose={dock.close} />}</AnimatePresence>;
}

function Picker({ onPick, onClose }: { onPick: (e: string) => void; onClose: () => void }) {
  const reduce = useReducedMotion();
  const [data, setData] = useState<Data | null>(null), [failed, setFailed] = useState(false);
  const [q, setQ] = useState(""), [grp, setGrp] = useState(() => (loadList(rd(RECENT_KEY)).length ? -1 : 0)), [tone, setTone] = useState<Tone>(() => loadTone(rd(TONE_KEY))), [recent, setRecent] = useState<string[]>(() => loadList(rd(RECENT_KEY)));
  const [act, setAct] = useState(0), box = useRef<HTMLDivElement>(null), inp = useRef<HTMLInputElement>(null);
  useEffect(() => { let live = true; loadData().then((d) => { if (live) setData(d); }).catch(() => { if (live) setFailed(true); }); return () => { live = false; }; }, []);
  useEffect(() => { inp.current?.focus({ preventScroll: true }); const id = window.setTimeout(() => box.current?.scrollIntoView({ block: "nearest", behavior: "auto" }), 30); return () => window.clearTimeout(id); }, []); /* the picker opens fully in view, the compose panel scrolls to it */
  useEffect(() => { const h = (e: MouseEvent) => { const el = e.target as HTMLElement; if (el instanceof HTMLElement && (e.offsetX > el.clientWidth || e.offsetY > el.clientHeight) && (el.scrollHeight > el.clientHeight || el.scrollWidth > el.clientWidth)) return; /* a click on a scrollbar is not a click outside */ if (box.current && !box.current.contains(e.target as Node) && !(e.target as HTMLElement).closest(".emo-toggle")) onClose(); }; document.addEventListener("mousedown", h); return () => document.removeEventListener("mousedown", h); }, [onClose]);
  const groups = useMemo(() => (data?.groups ?? []).filter((g) => g.key !== "component"), [data]);
  const byHex = useMemo(() => new Map((data?.all ?? []).map((e) => [e.hexcode, e])), [data]);
  const list: Emoji[] = useMemo(() => {
    if (!data) return [];
    if (q.trim()) return search(data.all, data.groups, q, 120, data.ur);
    if (grp === -1) return recent.map((h) => byHex.get(h)).filter((e): e is Emoji => !!e);
    return inGroup(data.all, grp, data.groups);
  }, [data, q, grp, recent, byHex]);
  useEffect(() => { setAct(0); }, [q, grp]);
  const choose = (e: Emoji) => { const t = withTone(e, tone); onPick(t.unicode); const r = pushRecent(recent, e.hexcode); setRecent(r); wr(RECENT_KEY, JSON.stringify(r)); };
  const key = (ev: React.KeyboardEvent) => {
    if (ev.key === "Escape") { ev.preventDefault(); ev.stopPropagation(); onClose(); return; }
    if (!list.length) return;
    const move = (d: number) => { ev.preventDefault(); viaKey.current = true; setAct((a) => Math.max(0, Math.min(list.length - 1, a + d))); };
    if (ev.key === "ArrowRight") move(1); else if (ev.key === "ArrowLeft") move(-1); else if (ev.key === "ArrowDown") move(COLS); else if (ev.key === "ArrowUp") move(-COLS);
    else if (ev.key === "Enter") { ev.preventDefault(); const e = list[act]; if (e) choose(e); }
  };
  const viaKey = useRef(false);
  useEffect(() => { /* scroll ONLY the grid, and only for keyboard moves: scrollIntoView also scrolled the picker and the compose window, which looked like the picker closing */
    if (!viaKey.current) return; viaKey.current = false;
    const g = box.current?.querySelector<HTMLElement>(".emo-grid"), c = box.current?.querySelector<HTMLElement>(`[data-i="${act}"]`); if (!g || !c) return;
    const gb = g.getBoundingClientRect(), cb = c.getBoundingClientRect();
    if (cb.top < gb.top) g.scrollTop -= gb.top - cb.top; else if (cb.bottom > gb.bottom) g.scrollTop += cb.bottom - gb.bottom;
  }, [act, list]);
  const setT = (t: Tone) => { setTone(t); wr(TONE_KEY, t); };
  return (
    <motion.div ref={box} className="emo emo-dock" role="dialog" aria-label="Emoji picker" onKeyDown={key} initial={reduce ? false : { opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 6 }} transition={{ duration: 0.14 }}>
      <div className="emo-tabs" role="tablist" aria-label="Emoji groups">
        <button type="button" role="tab" aria-selected={grp === -1 && !q} aria-label="Recently used" title="Recently used" className="emo-tab" onClick={() => { setQ(""); setGrp(-1); }}><span aria-hidden="true">🕘</span></button>
        {groups.map((g) => <button key={g.key} type="button" role="tab" aria-selected={grp === g.order && !q} aria-label={g.message} title={g.message} className="emo-tab" onClick={() => { setQ(""); setGrp(g.order); }}><span aria-hidden="true">{GROUP_ICON[g.key] ?? "•"}</span></button>)}
      </div>
      <div className="emo-top">
        <input ref={inp} className="emo-q" type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search emoji" aria-label="Search emoji" autoComplete="off" />
        <button type="button" className="emo-x" aria-label="Close emoji picker" title="Close" onClick={onClose}><span aria-hidden="true">✕</span></button>
      </div>
      <div className="emo-sec">
        <h3 className="emo-h">{q.trim() ? "Search results" : grp === -1 ? "Recently used" : (groups.find((g) => g.order === grp)?.message ?? "")}</h3>
        <div className="emo-tone" role="radiogroup" aria-label="Skin tone">
          {TONES.map((t2, i) => <button key={t2 || "none"} type="button" role="radio" aria-checked={tone === t2} aria-label={t2 ? `${t2} skin tone` : "Default yellow"} className={`emo-sw s${i}`} onClick={() => setT(t2)} />)}
        </div>
      </div>
      <div className="emo-grid" role="grid" aria-label={q ? "Search results" : "Emoji"} aria-rowcount={Math.ceil(list.length / COLS)}>
        {failed && <p className="emo-msg" role="alert">The emoji list could not be loaded.</p>}
        {!data && !failed && <p className="emo-msg">Loading emoji…</p>}
        {data && !list.length && <p className="emo-msg">{q ? "No emoji found." : grp === -1 ? "Nothing used yet." : ""}</p>}
        {list.map((e, i) => { const t = withTone(e, tone); return <button key={e.hexcode} type="button" role="gridcell" data-i={i} tabIndex={i === act ? 0 : -1} aria-label={t.label} title={t.label} className={`emo-c${i === act ? " act" : ""}`} onMouseEnter={() => setAct(i)} onClick={() => choose(e)}>{t.unicode}</button>; })}
      </div>
      <p className="sr" aria-live="polite">{data ? `${list.length} emoji` : ""}</p>
    </motion.div>
  );
}
