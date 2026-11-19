// QC1e-D2 (20 Nov 2026): ":" shortcode typeahead for the compose message box. Plan: docs/claude/QC1E-D2-PLAN-20NOV.md.
// React 19 + TypeScript. WAI-ARIA 1.2 combobox (textarea + listbox). Pure logic in emoji_pure.ts. Data = the picker's bundled emojibase chunks, loaded on the first ":xx".
import { useCallback, useDeferredValue, useEffect, useId, useMemo, useRef, useState } from "react";
import { acceptShortcode, loadList, loadTone, pushRecent, rankRecent, RECENT_KEY, shortcodeAt, shortcodeSearch, TONE_KEY, withTone, type Emoji, type Group, type UrIndex } from "./emoji_pure";
import { loadData } from "./EmojiPicker";
import { CompanyImg, useCompanyPack } from "./CompanyEmoji";
import { asEmoji, codeOf, isCompany, matchPack } from "./company_emoji_pure";
import "./emoji.css";

type Data = { all: Emoji[]; groups: Group[]; ur: UrIndex };
const rd = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const wr = (k: string, v: string) => { try { window.localStorage.setItem(k, v); } catch { /* storage may be blocked: the emoji is still inserted */ } };

export type Shortcode = {
  /** QC1e-D4A (awam only): sha-256 of each company picture, so the list can draw it */
  coSha: Map<string, string>;
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
  const pack = useCompanyPack(), coSha = useMemo(() => new Map(pack.items.map((c) => [c.shortcode, c.sha256] as const)), [pack.items]), hasCo = pack.available && pack.quota.enabled;
  const [active, setActive] = useState(0), [dismissed, setDismissed] = useState<string | null>(null), composing = useRef(false), loading = useRef(false);
  const look = useCallback(() => { const t = area.current; if (!t || composing.current) return; setHit(shortcodeAt(t.value, t.selectionStart ?? t.value.length)); }, [area]);
  useEffect(() => { look(); }, [value, look]);
  useEffect(() => { if (hit && !data && !loading.current) { loading.current = true; loadData().then(setData).catch(() => { loading.current = false; }); } }, [hit, data]);
  const q = useDeferredValue(hit?.query ?? "");
  const items = useMemo(() => {
    if (!hit || !data || dismissed === `${hit.start}:${hit.query}`) return [];
    const tone = loadTone(rd(TONE_KEY)), found = rankRecent(shortcodeSearch(data.all, data.groups, q, 24, data.ur), loadList(rd(RECENT_KEY))).slice(0, 8);
    const co = hasCo ? matchPack(pack.items, q, 4).map(asEmoji) : []; // company emoji first: ':ac' finds :acme: before the Unicode ones
    return [...co, ...found].slice(0, 8).map((e) => { const w = withTone(e, tone); return { e, unicode: w.unicode, label: w.label }; });
  }, [hit, data, q, dismissed, pack.items, hasCo]);
  useEffect(() => { setActive(0); }, [q, dismissed]);
  useEffect(() => { if (dismissed && (!hit || dismissed !== `${hit.start}:${hit.query}`)) setDismissed(null); }, [hit, dismissed]); // Escape hides only this exact ":name"; any other text brings the list back
  const open = items.length > 0;
  const pick = useCallback((i: number) => {
    const t = area.current, it = items[i]; if (!t || !it || !hit) return;
    const caret = t.selectionStart ?? value.length, r = acceptShortcode(value, hit.start, caret, it.unicode);
    if (!isCompany(it.e)) wr(RECENT_KEY, JSON.stringify(pushRecent(loadList(rd(RECENT_KEY)), it.e.hexcode))); onChange(r.text); setHit(null);
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
    listId, items, active, open, pick, setActive, coSha,
  };
}

/** The list. Put it inside the .emo-over wrapper, next to EmojiDock. */
export function EmojiShortcodeList({ sc }: { sc: Shortcode }) {
  if (!sc.open) return null;
  return (
    <>
      <ul className="emo-sc" id={sc.listId} role="listbox" aria-label="Emoji suggestions">
        {sc.items.map((it, i) => (
          <li key={it.e.hexcode} id={`${sc.listId}-${i}`} role="option" aria-selected={i === sc.active} className={i === sc.active ? "emo-sc-i on" : "emo-sc-i"} onMouseEnter={() => sc.setActive(i)} onMouseDown={(ev) => { ev.preventDefault(); sc.pick(i); }}>
            <span className="emo-sc-g" aria-hidden="true">{isCompany(it.e) ? <CompanyImg code={codeOf(it.e)} sha={sc.coSha.get(codeOf(it.e)) ?? ""} alt={it.label} size={22} /> : it.unicode}</span><span className="emo-sc-n">{it.label}</span>
          </li>
        ))}
      </ul>
      <p className="sr" role="status" aria-live="polite">{sc.items.length} emoji suggestions</p>
    </>
  );
}
