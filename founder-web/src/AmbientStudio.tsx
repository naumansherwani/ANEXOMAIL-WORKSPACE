import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";
import { get } from "./api";
import { RowTools } from "./SettingsS2";
import { Button } from "@/components/ui/button";
import { catalogOk, effectiveRate, indexOf, paint, same, step, stepSizes, valid, type Catalog, type Recipe } from "./ambient";

// Ambient Studio — founder only (master order S1b, SQL E114). Move the cursor, use the arrow keys, the wheel or a swipe: the whole workspace atmosphere changes live,
// like cycling a car's ambient lights. Enter keeps the look (saved on the account, history + audit); Esc goes back to the saved one. The look is drawn by a CSS layer
// (always available, cheap); a GPU shader can replace it later without changing a recipe. Nothing here is a stored picture.
let CACHE: Catalog | null = null;
export function useCatalog(enabled: boolean): Catalog | null {
  const [c, setC] = useState<Catalog | null>(CACHE);
  useEffect(() => {
    if (!enabled || CACHE) return; let live = true;
    get("/founder/v1/ambient/catalog").then((r) => { const d = r.data?.data; if (live && catalogOk(d)) { CACHE = d; setC(d); } }).catch(() => {});
    return () => { live = false; };
  }, [enabled]);
  return c;
}

/** The atmosphere behind the workspace. Absent when no look was chosen (the existing aurora stays exactly as it was). */
export function AmbientLayer({ cat, recipe, motion }: { cat: Catalog; recipe: Recipe; motion: "full" | "reduced" | "none" }) {
  const p = paint(cat, recipe, motion);
  return <div className="amb" data-kind={p.kind} style={p.vars as CSSProperties} aria-hidden="true" />;
}

const nf = (n: number) => n.toLocaleString("en-GB");
type Save = (key: string, value: unknown, local?: () => void) => Promise<void>;

export function AmbientStudio({ saved, favs, cat, preview, setPreview, motion, save, busy, onHistory }: {
  saved: Recipe | null; favs: Recipe[]; cat: Catalog | null; preview: Recipe | null; setPreview: (r: Recipe | null) => void; motion: "full" | "reduced" | "none"; save: Save; busy: boolean; onHistory: (k: string) => void;
}) {
  const dial = useRef<HTMLDivElement>(null), acc = useRef({ x: 0, y: 0 }), [note, setNote] = useState("");
  const base = cat ? (saved && valid(cat, saved) ? saved : cat.default) : null;
  const cur = preview ?? base;
  const move = useCallback((d: number) => { if (!cat || !cur) return; setPreview(step(cat, cur, d)); }, [cat, cur, setPreview]);
  useEffect(() => () => setPreview(null), [setPreview]); // leaving the tab drops an unsaved preview
  useEffect(() => { // wheel needs a non-passive listener so the page does not scroll while you scrub
    const el = dial.current; if (!el) return;
    const w = (e: WheelEvent) => { e.preventDefault(); move(e.shiftKey ? (e.deltaY > 0 ? 1 : -1) * stepSizes(cat!).pattern : e.deltaY > 0 ? 1 : -1); };
    el.addEventListener("wheel", w, { passive: false }); return () => el.removeEventListener("wheel", w);
  }, [move, cat]);
  if (!cat || !cur) return <section className="panel"><div className="panelhead"><h2>Ambient Studio</h2><p className="dim">Loading the look catalog from the database…</p></div></section>;
  const sz = stepSizes(cat), n = indexOf(cat, cur), pal = cat.palettes[cur.palette], pat = cat.patterns[cur.pattern], dirty = !same(cur, base!);
  const isFav = favs.some((f) => same(f, cur));
  const onMove = (e: React.PointerEvent) => { // cursor forward = next look, back = previous (every 26 px); up/down = next/previous pattern (every 44 px)
    acc.current.x += e.movementX; acc.current.y += e.movementY; let d = 0;
    while (acc.current.x >= 26) { acc.current.x -= 26; d += 1; } while (acc.current.x <= -26) { acc.current.x += 26; d -= 1; }
    while (acc.current.y >= 44) { acc.current.y -= 44; d += sz.pattern; } while (acc.current.y <= -44) { acc.current.y += 44; d -= sz.pattern; }
    if (d) move(d);
  };
  const key = (e: React.KeyboardEvent) => {
    const k = e.key, m: Record<string, number> = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: sz.pattern, ArrowUp: -sz.pattern, PageDown: sz.speed, PageUp: -sz.speed };
    if (k in m) { e.preventDefault(); move(m[k]); } else if (k === "Enter") { e.preventDefault(); void keep(); } else if (k === "Escape") { e.preventDefault(); setPreview(null); }
  };
  const keep = async () => { await save("appearance.ambient", cur, () => {}); setPreview(null); };
  const surprise = async () => {
    const b = new Uint32Array(2); crypto.getRandomValues(b); const entropy = (b[0] % 1_000_000) * 1_000_000 + (b[1] % 1_000_000);
    try { const r = await get(`/founder/v1/ambient/surprise?n=${entropy}`); const d = r.data?.data; if (valid(cat, d)) setPreview(d); else setNote("The database did not answer."); }
    catch { setNote("The database did not answer."); }
  };
  const toggleFav = () => {
    const next = isFav ? favs.filter((f) => !same(f, cur)) : [...favs, cur];
    if (next.length > cat.max_favourites) { setNote(`You can keep ${cat.max_favourites} favourites. Remove one first.`); return; }
    setNote(""); void save("appearance.ambient_favs", next);
  };
  const tweak = (k: keyof Recipe, v: number) => setPreview({ ...cur, [k]: v });
  return (
    <section className="panel ambstudio">
      <div className="panelhead"><h2>Ambient Studio</h2>
        <p className="dim">Move your cursor across the dial — forward and back — to cycle the whole workspace atmosphere, like the ambient lights in a car. Up and down changes the pattern. Enter keeps a look, Esc goes back.</p></div>
      <div ref={dial} className="ambdial" tabIndex={0} role="slider" aria-label="Ambient look" aria-valuemin={0} aria-valuemax={cat.total - 1} aria-valuenow={n} aria-valuetext={`${pal.name}, ${pat.name}`}
        onPointerMove={onMove} onKeyDown={key} style={{ background: `linear-gradient(90deg, ${pal.stops[0]}, ${pal.stops[1]}, ${pal.stops[2]})` }}>
        <div className="ambname"><b>{pal.name}</b><span>{pat.name}</span></div>
        <div className="ambnum">Look {nf(n + 1)} of {nf(cat.total)}</div>
      </div>
      <div className="ambrow">
        <Button variant="ghost" size="mini" onClick={() => move(-1)} aria-label="Previous look">◀ Previous</Button>
        <Button variant="ghost" size="mini" onClick={() => move(1)} aria-label="Next look">Next ▶</Button>
        <Button variant="ghost" size="mini" onClick={surprise}>Surprise me</Button>
        <Button variant="ghost" size="mini" aria-pressed={isFav} onClick={toggleFav} disabled={busy}>{isFav ? "♥ Favourite" : "♡ Add to favourites"}</Button>
        <span className="grow" />
        {dirty && <Button variant="ghost" size="mini" onClick={() => setPreview(null)}>Back to saved</Button>}
        <Button size="mini" disabled={busy || !dirty} onClick={() => void keep()}>Keep this look</Button>
      </div>
      <div className="ambtweak">
        <label>Palette<select value={cur.palette} onChange={(e) => tweak("palette", +e.target.value)}>{cat.palettes.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
        <label>Pattern<select value={cur.pattern} onChange={(e) => tweak("pattern", +e.target.value)}>{cat.patterns.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
        <label>Speed {cat.speeds[cur.speed].factor}×<input type="range" min={0} max={cat.speeds.length - 1} value={cur.speed} onChange={(e) => tweak("speed", +e.target.value)} /></label>
        <label>Intensity {cat.intensities[cur.intensity].percent}%<input type="range" min={0} max={cat.intensities.length - 1} value={cur.intensity} onChange={(e) => tweak("intensity", +e.target.value)} /></label>
        <label>Blend<select value={cur.blend} onChange={(e) => tweak("blend", +e.target.value)}>{cat.blends.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
        <label>Variation<button type="button" className="ghost mini" onClick={() => tweak("seed", (cur.seed + 1) % cat.seeds)}>Another ({nf(cur.seed + 1)} of {nf(cat.seeds)})</button></label>
      </div>
      <p className="dim small">{pat.note} Flashes at most {effectiveRate(cat, cur)} a second — never more than 2, at any speed.{motion !== "full" ? " Motion is reduced on this device, so looks show as a calm, steady wash." : ""}</p>
      {favs.length > 0 && <div className="ambfavs" aria-label="Favourite looks">{favs.map((f, i) => {
        const p = cat.palettes[f.palette]; return <button key={i} type="button" className={`ambchip ${same(f, cur) ? "on" : ""}`} title={`${p.name} · ${cat.patterns[f.pattern].name}`} onClick={() => setPreview(f)}
          style={{ background: `linear-gradient(135deg, ${p.stops[0]}, ${p.stops[2]})` }} aria-label={`${p.name}, ${cat.patterns[f.pattern].name}`} />; })}</div>}
      {note && <div className="toast warn" role="status">{note}</div>}
      <RowTools k="appearance.ambient" onHistory={onHistory} />
      <RowTools k="appearance.ambient_favs" onHistory={onHistory} />
      {saved && <div className="setrow last"><div><b>Back to the default look</b><p className="dim">Removes your chosen look; the original aurora returns.</p></div>
        <Button variant="ghost" size="mini" disabled={busy} onClick={() => { void save("appearance.ambient", null); setPreview(null); }}>Use default</Button></div>}
    </section>
  );
}
