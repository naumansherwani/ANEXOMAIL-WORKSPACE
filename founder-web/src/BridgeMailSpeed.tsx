import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import { PERF_STAGES, PERF_STAGE_LABEL, PERF_WINDOWS, compact, meterNote, pctRows, sloChip, type PerfDoor, type PerfMeter } from "./mail_pure";
import "./bridgemailspeed.css";

/** QPERF-3 (Bridge, additive): how fast the founder's mail is, per stage, p50 to p99.9, and whether the speed promise (SLO) is kept. Mounted by one line in Bridge.tsx; Scene3D.tsx, BridgeLanes.tsx and BridgeMailLedger.tsx are not touched.
 *  Numbers come from the E174 ledger through the signed door; a figure the server could not stand behind is "—" with the reason, never 0. */
export function BridgeMailSpeed() {
  const [w, setW] = useState<(typeof PERF_WINDOWS)[number]>("1h"), [d, setD] = useState<PerfDoor | null>(null), [m, setM] = useState<PerfMeter | null>(null), [conn, setConn] = useState<boolean | null>(null), [busy, setBusy] = useState(false);
  const load = useCallback(async (win: string) => { setBusy(true); try { const r = await api.perf(win); setConn(!!r); if (r) { setD(r.perf); setM(r.meter); } } catch { setConn(false); } setBusy(false); }, []);
  useEffect(() => { void load(w); const t = window.setInterval(() => void load(w), 30_000); return () => window.clearInterval(t); }, [w, load]);
  if (conn !== true || !d) return null;
  const note = meterNote(m), slo = (s: string) => d.slo.find((x) => x.stage === s);
  return (
    <section className="bms" aria-label="Mail speed">
      <header><h2>Mail speed</h2>
        <div className="bms-win" role="group" aria-label="Time window">{PERF_WINDOWS.map((x) => <button key={x} type="button" aria-pressed={x === w} className={x === w ? "on" : ""} onClick={() => setW(x)}>{x}</button>)}</div>
        <button type="button" className="dx-pill" disabled={busy} onClick={() => void load(w)}>{busy ? "…" : "Refresh"}</button></header>
      <p className="bms-note">Time from arrival to stored, sealed and scanned. Only durations are measured: no address, subject or sender. A figure shows “—” until there are enough mails to stand behind it.{note ? ` ${note}` : ""}</p>
      <div className="bms-grid">{PERF_STAGES.map((s) => { const c = sloChip(slo(s)), p = d.stages[s]; return (
        <article key={s} className="bms-card"><h3>{PERF_STAGE_LABEL[s]}<small>{p ? `${compact(p.n)} mails` : "—"}</small></h3>
          <span className={`bms-chip ${c.tone}`} role="status"><i aria-hidden="true" />{c.text}</span>
          <dl>{pctRows(p).map((r) => <div key={r.k} title={r.why ?? undefined}><dt>{r.label}</dt><dd className={r.why ? "na" : ""}>{r.value}</dd></div>)}</dl></article>); })}</div>
      <p className="bms-foot">Daily seals: {d.seals.count}{d.seals.head_day ? `, latest ${d.seals.head_day}` : ""}. Each closed day is hash-chained, so old numbers cannot be changed quietly.</p>
    </section>
  );
}
