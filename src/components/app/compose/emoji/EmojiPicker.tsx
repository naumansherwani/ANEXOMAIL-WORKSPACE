// QC1e (19 Nov 2026): the emoji picker of the compose window. React 19 + TypeScript + motion. Data = emojibase-data (Unicode 17), bundled and loaded lazily on first open: no network, no vendor.
// Pure logic is in emoji_pure.ts (bun-tested). Inserts at the caret of the message box. 44 px targets, keyboard (arrows, Enter, Escape), role=dialog + grid, reduced motion respected.
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { inGroup, insertAt, loadList, loadTone, pushRecent, RECENT_KEY, search, TONE_KEY, TONES, withTone, type Emoji, type Group, type Tone } from "./emoji_pure";
import "./emoji.css";

type Data = { all: Emoji[]; groups: Group[] };
let cache: Promise<Data> | null = null;
export function loadData(): Promise<Data> {
  cache ??= Promise.all([import("emojibase-data/en/compact.json"), import("emojibase-data/en/messages.json")]).then(([c, m]) => ({ all: (c.default as unknown as Emoji[]), groups: (m.default as unknown as { groups: Group[] }).groups }));
  return cache;
}
let vcache: Promise<Record<string, string[]>> | null = null;
export function loadVersions(): Promise<Record<string, string[]>> { vcache ??= import("emojibase-data/versions/emoji.json").then((m) => m.default as unknown as Record<string, string[]>); return vcache; }
const rd = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const wr = (k: string, v: string) => { try { window.localStorage.setItem(k, v); } catch { /* the picker works without storage */ } };
const GROUP_ICON: Record<string, string> = { "smileys-emotion": "😀", "people-body": "👋", "animals-nature": "🐻", "food-drink": "🍔", "travel-places": "✈️", activities: "⚽", objects: "💡", symbols: "❤️", flags: "🏁" };
const COLS = 8;

export function EmojiButton({ area, value, onChange }: { area: React.RefObject<HTMLTextAreaElement | null>; value: string; onChange: (v: string) => void }) {
  const [open, setOpen] = useState(false), btn = useRef<HTMLButtonElement>(null);
  const pick = useCallback((e: string) => {
    const t = area.current, s = t?.selectionStart ?? value.length, en = t?.selectionEnd ?? value.length;
    const r = insertAt(value, s, en, e); onChange(r.text);
    window.requestAnimationFrame(() => { if (t) { t.focus(); t.setSelectionRange(r.caret, r.caret); } });
  }, [area, value, onChange]);
  const close = useCallback(() => { setOpen(false); btn.current?.focus(); }, []);
  return (
    <span className="emo-anchor">
      <button ref={btn} type="button" className="emo-btn" aria-haspopup="dialog" aria-expanded={open} aria-label="Insert emoji" onClick={() => setOpen((o) => !o)}>
        <span aria-hidden="true">🙂</span>
      </button>
      <AnimatePresence>{open && <Picker key="p" onPick={pick} onClose={close} />}</AnimatePresence>
    </span>
  );
}

function Picker({ onPick, onClose }: { onPick: (e: string) => void; onClose: () => void }) {
  const reduce = useReducedMotion();
  const [data, setData] = useState<Data | null>(null), [failed, setFailed] = useState(false);
  const [q, setQ] = useState(""), [grp, setGrp] = useState(0), [tone, setTone] = useState<Tone>(() => loadTone(rd(TONE_KEY))), [recent, setRecent] = useState<string[]>(() => loadList(rd(RECENT_KEY)));
  const [act, setAct] = useState(0), box = useRef<HTMLDivElement>(null), inp = useRef<HTMLInputElement>(null);
  useEffect(() => { let live = true; loadData().then((d) => { if (live) setData(d); }).catch(() => { if (live) setFailed(true); }); return () => { live = false; }; }, []);
  useEffect(() => { inp.current?.focus(); }, []);
  useEffect(() => { const h = (e: MouseEvent) => { if (box.current && !box.current.contains(e.target as Node) && !(e.target as HTMLElement).closest(".emo-anchor")) onClose(); }; document.addEventListener("mousedown", h); return () => document.removeEventListener("mousedown", h); }, [onClose]);
  const groups = useMemo(() => (data?.groups ?? []).filter((g) => g.key !== "component"), [data]);
  const byHex = useMemo(() => new Map((data?.all ?? []).map((e) => [e.hexcode, e])), [data]);
  const list: Emoji[] = useMemo(() => {
    if (!data) return [];
    if (q.trim()) return search(data.all, data.groups, q);
    if (grp === -1) return recent.map((h) => byHex.get(h)).filter((e): e is Emoji => !!e);
    return inGroup(data.all, grp, data.groups);
  }, [data, q, grp, recent, byHex]);
  useEffect(() => { setAct(0); }, [q, grp]);
  const choose = (e: Emoji) => { const t = withTone(e, tone); onPick(t.unicode); const r = pushRecent(recent, e.hexcode); setRecent(r); wr(RECENT_KEY, JSON.stringify(r)); };
  const key = (ev: React.KeyboardEvent) => {
    if (ev.key === "Escape") { ev.preventDefault(); ev.stopPropagation(); onClose(); return; }
    if (!list.length) return;
    const move = (d: number) => { ev.preventDefault(); setAct((a) => Math.max(0, Math.min(list.length - 1, a + d))); };
    if (ev.key === "ArrowRight") move(1); else if (ev.key === "ArrowLeft") move(-1); else if (ev.key === "ArrowDown") move(COLS); else if (ev.key === "ArrowUp") move(-COLS);
    else if (ev.key === "Enter") { ev.preventDefault(); const e = list[act]; if (e) choose(e); }
  };
  useEffect(() => { box.current?.querySelector<HTMLElement>(`[data-i="${act}"]`)?.scrollIntoView({ block: "nearest" }); }, [act, list]);
  const setT = (t: Tone) => { setTone(t); wr(TONE_KEY, t); };
  return (
    <motion.div ref={box} className="emo" role="dialog" aria-label="Emoji picker" onKeyDown={key} initial={reduce ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 8 }} transition={{ duration: 0.14 }}>
      <input ref={inp} className="emo-q" type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search emoji" aria-label="Search emoji" autoComplete="off" />
      <div className="emo-tabs" role="tablist" aria-label="Emoji groups">
        <button type="button" role="tab" aria-selected={grp === -1 && !q} aria-label="Recently used" className="emo-tab" onClick={() => { setQ(""); setGrp(-1); }}><span aria-hidden="true">🕘</span></button>
        {groups.map((g) => <button key={g.key} type="button" role="tab" aria-selected={grp === g.order && !q} aria-label={g.message} className="emo-tab" onClick={() => { setQ(""); setGrp(g.order); }}><span aria-hidden="true">{GROUP_ICON[g.key] ?? "•"}</span></button>)}
      </div>
      <div className="emo-tone" role="radiogroup" aria-label="Skin tone">
        {TONES.map((t, i) => <button key={t || "none"} type="button" role="radio" aria-checked={tone === t} aria-label={t ? `${t} skin tone` : "Default yellow"} className={`emo-sw s${i}`} onClick={() => setT(t)} />)}
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
