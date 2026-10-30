import { useEffect, useState } from "react";
import { fmtDateTime } from "./city";
import { get, post, type WriteResult } from "./api";

// A server action from GET /founder/v1/actions (registry in E102/E103).
export type FounderAction = { key: string; deck: string; title: string; summary: string; danger: "low" | "medium" | "high"; enabled: boolean };
type ActionsData = { connected: boolean; note?: string; actions: FounderAction[] };
type AuditEntry = { seq: number; action: string; reason: string; ts_ms: number };
type AuditData = { connected: boolean; note?: string; chain_ok: boolean; first_bad_seq?: number; head?: { seq: number; hash: string }; entries: AuditEntry[] };

export const DECKS: [string, string, string][] = [
  ["people", "People", "F4"], ["mail_desk", "Mail Desk", "F5"], ["release", "Release", "F3"],
  ["move_in", "Move-In", "F3"], ["systems", "Systems", "F6"], ["control", "Control", "F8"],
];
const DANGER: Record<string, string> = { low: "LOW", medium: "MEDIUM", high: "HIGH RISK" };

// Two-tap: tap 1 opens the action and asks for a reason; tap 2 confirms. Every attempt is written to the audit chain by the server.
function Sheet({ action, onClose, onDone }: { action: FounderAction; onClose: () => void; onDone?: () => void }) {
  const [why, setWhy] = useState(""), [busy, setBusy] = useState(false), [res, setRes] = useState<WriteResult | null>(null);
  const ok = why.trim().length >= 8;
  const go = async () => {
    setBusy(true);
    try { const r = await post("/founder/v1/action", { key: action.key, reason: why }); setRes(r); onDone?.(); }
    catch (x) { setRes({ status: 0, body: { error: (x as Error).message } }); }
    finally { setBusy(false); }
  };
  return (
    <div className="overlay" role="dialog" aria-modal="true" aria-label={action.title} onKeyDown={(e) => e.key === "Escape" && onClose()}>
      <div className="sheet">
        <div className={`kicker ${action.danger === "high" ? "lv-fail" : "lv-warn"}`}>TAP 1 / 2 · {DANGER[action.danger]}</div>
        <h2>{action.title}</h2>
        <p className="dim">{action.summary}</p>
        {!action.enabled && <div className="note">The executor is not enabled yet (F8). Your attempt is still recorded in the audit chain.</div>}
        <label>Reason (required, recorded in the audit log)<textarea rows={3} value={why} onChange={(e) => setWhy(e.target.value)} autoFocus /></label>
        {res && <div className={res.status === 409 ? "note" : "err"} role="status">{res.body?.error || `HTTP ${res.status}`}{res.body?.audit && <div className="src">audit #{res.body.audit.seq} · hash {String(res.body.audit.hash).slice(0, 12)}…</div>}</div>}
        <div className="row">
          <button className="ghost" onClick={onClose}>Close</button>
          <button disabled={!ok || busy || !!res} onClick={go}>{busy ? "…" : "Tap 2: confirm"}</button>
        </div>
      </div>
    </div>
  );
}

// Last real server answer, shown instantly while a fresh one loads (no mock data: it is the previous /actions reply).
let lastActions: ActionsData | null = null;

export function Deck({ deck }: { deck: string }) {
  const [d, setD] = useState<ActionsData | null>(lastActions), [sel, setSel] = useState<FounderAction | null>(null), [tick, setTick] = useState(0);
  useEffect(() => { get<ActionsData>("/founder/v1/actions").then((r) => { lastActions = r.data; setD(r.data); }).catch(() => setD({ connected: false, note: "Could not load", actions: [] })); }, [tick]);
  const info = DECKS.find((x) => x[0] === deck) ?? [deck, deck, ""];
  const list = d?.connected ? d.actions.filter((a: FounderAction) => a.deck === deck) : [];
  return (
    <section className="card wide">
      <h2>{info[1].toUpperCase()} · LIVE ACTIONS (one-click, audited)</h2>
      {!d && <div className="dim">…</div>}
      {d && !d.connected && <div className="note">{d.note}</div>}
      {d?.connected && !list.length && <div className="dim">No actions in this deck yet.</div>}
      <ul className="acts">{list.map((a) => (
        <li key={a.key}><div><b>{a.title}</b><em>{a.summary}</em></div>
          <span className={`pill lv-${a.danger === "high" ? "fail" : a.danger === "medium" ? "warn" : "ok"}`}>{DANGER[a.danger]}</span>
          <button className="mini" onClick={() => setSel(a)}>Tap 1</button></li>))}</ul>
      <div className="src">These actions exist in the server registry today. Tap 1 opens the reason sheet; the executor is switched on in F8.</div>
      {sel && <Sheet action={sel} onClose={() => setSel(null)} onDone={() => setTick((t) => t + 1)} />}
    </section>
  );
}

export function Audit() {
  const [d, setD] = useState<AuditData | null>(null);
  useEffect(() => { get<AuditData>("/founder/v1/audit").then((r) => { setD(r.data); }).catch(() => setD({ connected: false, note: "Could not load", chain_ok: false, entries: [] })); }, []);
  return (
    <section className="card wide">
      <h2>AUDIT CHAIN</h2>
      {!d && <div className="dim">…</div>}
      {d && !d.connected && <div className="note">{d.note}</div>}
      {d?.connected && <>
        <div className={`big lv-${d.chain_ok ? "ok" : "fail"}`}>{d.chain_ok ? "INTACT" : `BROKEN at seq ${d.first_bad_seq}`}</div>
        <div className="src">head #{d.head?.seq} · {String(d.head?.hash).slice(0, 16)}… (the database recomputes the whole chain every time)</div>
        <ul className="acts">{d.entries.map((e: AuditEntry) => <li key={e.seq}><div><b>#{e.seq} {e.action}</b><em>{e.reason}</em></div><span className="src">{fmtDateTime(e.ts_ms)}</span></li>)}</ul>
        {!d.entries.length && <div className="dim">No entries yet.</div>}</>}
    </section>
  );
}
