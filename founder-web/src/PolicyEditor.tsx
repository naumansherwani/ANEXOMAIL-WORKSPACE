import { useState } from "react";
import { changeText, changed, draftOf, LIMITS, validate, type Begun, type Draft } from "./policy_change";
import { confirm, prepare } from "./policy_flow";
import { span, type Policy } from "./sessions_pure";

// D2b-5: the policy card's editor. Three steps, all in words: (1) edit + say why, (2) read exactly what will change, (3) touch the key.
// Nothing here changes anything by itself: the server holds the payload and only a fresh passkey touch applies it.
type Phase = "edit" | "review" | "touch" | "done";
const NUM: { k: "maxLive" | "failLimit" | "flapLimit" | "staleAfterS" | "idleS" | "absoluteS"; label: string; help: string }[] = [
  { k: "maxLive", label: "Live sessions allowed", help: "Opening one more closes the oldest." },
  { k: "failLimit", label: "Failed signatures before closing", help: "A run of bad signatures closes the session." },
  { k: "flapLimit", label: "Network changes in 10 minutes", help: "Many changes look like a shared session." },
  { k: "staleAfterS", label: "Quiet seconds before “stale”", help: "Shown as stale on the board." },
  { k: "idleS", label: "Idle limit (seconds)", help: "A session unused this long ends." },
  { k: "absoluteS", label: "Absolute limit (seconds)", help: "No session lives longer than this." },
];

export function PolicyEditor({ p, onDone }: { p: Policy; onDone: () => void }) {
  const [phase, setPhase] = useState<Phase>("edit"), [d, setD] = useState<Draft>(() => draftOf(p)), [reason, setReason] = useState("");
  const [begun, setBegun] = useState<Begun | null>(null), [busy, setBusy] = useState(false), [err, setErr] = useState("");
  const problem = validate(d, reason, p), dirty = changed(d, p);
  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => { setD((x) => ({ ...x, [k]: v })); setErr(""); };

  async function review() {
    if (problem || busy) return;
    setBusy(true); setErr("");
    try { const r = await prepare(d, reason); if (r.ok) { setBegun(r.begun); setPhase("review"); } else setErr(r.error); }
    catch (e) { setErr((e as Error).message || "The server did not answer"); }
    setBusy(false);
  }
  async function touch() {
    if (!begun || busy) return;
    setBusy(true); setErr(""); setPhase("touch");
    try { const r = await confirm(begun); if (r.ok) { setPhase("done"); onDone(); } else { setErr(r.error); setPhase("review"); } }
    catch (e) { setErr((e as Error).message || "The server did not answer"); setPhase("review"); }
    setBusy(false);
  }

  if (phase === "done") return <div className="dv-edit" role="status"><p className="dv-ok"><i aria-hidden="true">✓</i> Policy changed. It applies to every session on its very next request.</p></div>;
  if (phase === "review" || phase === "touch") {
    return (
      <div className="dv-edit" aria-label="Review the policy change">
        <h3 className="dv-h3">Check exactly what will change</h3>
        <ul className="dv-changes">{begun?.changes.map((c) => <li key={c.field}>{changeText(c)}</li>)}</ul>
        <p className="dim small">Reason: {begun?.reason}</p>
        <p className="dim small">Your key signs this exact list. If anything differs, the key is never touched.</p>
        {err && <p className="err" role="alert">{err}</p>}
        <div className="dv-actions">
          <button type="button" className="dv-btn" disabled={busy} onClick={() => void touch()}>{phase === "touch" ? "Waiting for your key…" : "Touch my key to apply"}</button>
          <button type="button" className="dv-btn ghost" disabled={busy} onClick={() => { setPhase("edit"); setBegun(null); }}>Back</button>
        </div>
      </div>
    );
  }
  return (
    <form className="dv-edit" aria-label="Change the session policy" onSubmit={(e) => { e.preventDefault(); void review(); }}>
      <h3 className="dv-h3">Change the policy</h3>
      <div className="dv-field">
        <label htmlFor="pe-geo">Location lock</label>
        <select id="pe-geo" value={d.geoMode} onChange={(e) => set("geoMode", e.target.value as Draft["geoMode"])}>
          <option value="off">Off</option><option value="observe">Observe only (record, never block)</option><option value="enforce">Enforce (block outside the list)</option>
        </select>
      </div>
      <div className="dv-field">
        <label htmlFor="pe-cc">Allowed countries (two-letter codes, comma separated)</label>
        <input id="pe-cc" value={d.countries} onChange={(e) => set("countries", e.target.value)} placeholder="PK, GB" autoCapitalize="characters" autoComplete="off" spellCheck={false} />
        <small>Enforce is refused if your current country is not in the list.</small>
      </div>
      <div className="dv-field">
        <label htmlFor="pe-sp">When a browser lies about itself</label>
        <select id="pe-sp" value={d.spoofAction} onChange={(e) => set("spoofAction", e.target.value as Draft["spoofAction"])}><option value="alert">Alert only</option><option value="block">Block it</option></select>
      </div>
      <div className="dv-field">
        <label htmlFor="pe-fa">When the network keeps changing</label>
        <select id="pe-fa" value={d.flapAction} onChange={(e) => set("flapAction", e.target.value as Draft["flapAction"])}><option value="alert">Alert only</option><option value="revoke">Close the session</option></select>
      </div>
      {NUM.map((f) => (
        <div className="dv-field" key={f.k}>
          <label htmlFor={`pe-${f.k}`}>{f.label}</label>
          <input id={`pe-${f.k}`} type="number" inputMode="numeric" min={LIMITS[f.k][0]} max={LIMITS[f.k][1]} value={d[f.k]} onChange={(e) => set(f.k, Number(e.target.value))} />
          <small>{f.help} {f.k.endsWith("S") && Number.isFinite(d[f.k]) ? <b className="dv-eq">= {span(d[f.k])}</b> : null} <span className="dv-rng">({LIMITS[f.k][0]}–{LIMITS[f.k][1]})</span></small>
        </div>
      ))}
      <div className="dv-field">
        <label htmlFor="pe-why">Why are you changing it? (kept in the ledger)</label>
        <input id="pe-why" value={reason} maxLength={200} onChange={(e) => { setReason(e.target.value); setErr(""); }} placeholder="e.g. travelling to the UK next week" autoComplete="off" />
      </div>
      {(err || (dirty && problem)) && <p className="err" role="alert">{err || problem}</p>}
      <div className="dv-actions">
        <button type="submit" className="dv-btn" disabled={busy || !!problem}>{busy ? "Checking…" : "Review the change"}</button>
        <button type="button" className="dv-btn ghost" onClick={onDone}>Cancel</button>
      </div>
    </form>
  );
}
