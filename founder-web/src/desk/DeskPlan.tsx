import { useEffect, useRef, useState } from "react";
import { deskLookup } from "./desk_kernel";
import { UNAVAILABLE_TEXT, type LookupState } from "./desk_lookup_pure";
import { PLAN_FIELDS, ageSecs, companyOk, featureDiff, freshnessWords, isStale, meters, paymentFlag, reasonOk, serviceView, MIN_REASON } from "./desk_plan_pure";

/** ADMIN DESK D5 (23 Nov 2026): the Plan context screen. The employee types a company and a reason first (the reason is written to the audit line before any data is read),
 *  then sees the plan, the real features, usage, service state and one payment flag. Every value comes from the kernel-verified lookup (Rule 52); if it cannot be trusted
 *  the screen says "Data unavailable" and shows NO old value. No money, no card, no invoice. */
const CSS = `
.dpl{display:grid;gap:14px;margin-top:6px}.dpl-form{display:grid;gap:10px;grid-template-columns:repeat(auto-fit,minmax(min(100%,16rem),1fr))}
.dpl label{display:grid;gap:6px;font-size:13px;color:var(--mute);min-width:0}.dpl input,.dpl textarea{min-height:44px;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--glass);color:inherit;font:inherit;min-width:0}
.dpl-reason{grid-column:1/-1}.dpl-go{min-height:44px;padding:0 20px;border-radius:12px;border:1px solid rgba(160,200,255,.5);background:rgba(120,170,255,.16);color:inherit;font:inherit;cursor:pointer}.dpl-go:disabled{opacity:.5;cursor:default}
.dpl-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,18rem),1fr))}.dpl-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dpl-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:500}.dpl-box[data-stale="true"]{opacity:.5}
.dpl-bar{height:10px;border-radius:6px;background:rgba(255,255,255,.1);overflow:hidden;margin:6px 0}.dpl-fill{height:100%;background:#7FB2FF;transition:width .4s}
.dpl-fill[data-m="near"]{background:#E8C34A}.dpl-fill[data-m="almost"],.dpl-fill[data-m="over"]{background:#FF8A5C}
.dpl-chip{display:inline-block;padding:2px 10px;border-radius:999px;border:1px solid var(--line);font-size:13px}.dpl-chip[data-l="good"]{border-color:#6FD08C}.dpl-chip[data-l="warn"]{border-color:#E8C34A}.dpl-chip[data-l="bad"]{border-color:#FF8A5C}
.dpl ul{margin:0;padding-left:18px}.dpl-fresh{font-size:13px;color:var(--mute)}
@media (prefers-reduced-motion:reduce){.dpl-fill{transition:none}}`;

const rid = () => (typeof crypto !== "undefined" && "randomUUID" in crypto ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2));
const val = (v: unknown) => (typeof v === "string" || typeof v === "number" ? String(v) : "Not known");

export function DeskPlan() {
  const [company, setCompany] = useState(""), [reason, setReason] = useState(""), [busy, setBusy] = useState(false);
  const [res, setRes] = useState<LookupState | null>(null), [now, setNow] = useState(() => Date.now() / 1000);
  const head = useRef<HTMLHeadingElement>(null);
  useEffect(() => { const t = setInterval(() => setNow(Date.now() / 1000), 1000); return () => clearInterval(t); }, []);
  const ok = companyOk(company) && reasonOk(reason) && !busy;
  async function go(e: { preventDefault(): void }) {
    e.preventDefault(); if (!ok) return;
    setRes(null); setBusy(true);                       // the old answer is gone the moment a new lookup starts
    const r = await deskLookup(company.trim(), reason.trim(), PLAN_FIELDS, rid());
    setRes(r); setBusy(false); setTimeout(() => head.current?.focus(), 0);
  }
  return (
    <div className="dpl"><style>{CSS}</style>
      <form className="dpl-form" onSubmit={(e) => void go(e)}>
        <label>Company reference<input value={company} onChange={(e) => setCompany(e.target.value)} autoComplete="off" spellCheck={false} /></label>
        <label className="dpl-reason">Why are you looking? (at least {MIN_REASON} characters, saved in the audit log before anything is shown)<textarea rows={2} value={reason} onChange={(e) => setReason(e.target.value)} /></label>
        <button type="submit" className="dpl-go" disabled={!ok}>{busy ? "Looking…" : "Look up plan"}</button>
      </form>
      {res?.state === "unavailable" && <p role="status" className="dpl-box"><b>{UNAVAILABLE_TEXT}</b><br />Nothing is shown, so nothing old can be mistaken for today's answer. Try again in a moment.</p>}
      {res?.state === "refused" && <p role="status" className="dpl-box"><b>Not allowed or paused</b><br />The Desk did not give this lookup. No data is shown.</p>}
      {res?.state === "data" && <Result f={res.fields} answeredAt={res.answeredAt} now={now} head={head} />}
    </div>
  );
}

function Result({ f, answeredAt, now, head }: { f: Record<string, unknown>; answeredAt: number; now: number; head: React.RefObject<HTMLHeadingElement | null> }) {
  const age = ageSecs(answeredAt, now), stale = isStale(age), sv = serviceView(f), pf = paymentFlag(f), fd = featureDiff(f);
  return (
    <div className="dpl">
      <h3 ref={head} tabIndex={-1} style={{ margin: 0, fontWeight: 600 }}>{val(f.package_id)} · version {val(f.package_version)}</h3>
      <p className="dpl-fresh" role="status" data-stale={stale}>{freshnessWords(age)}</p>
      <div className="dpl-grid" data-stale={stale}>
        <section className="dpl-box" data-stale={stale}><h3>Service</h3><span className="dpl-chip" data-l={sv.level}>{sv.words}</span>
          {sv.detail && <p>{sv.detail}</p>}{sv.since && <p>Since {sv.since}</p>}<p>Plan effective from {val(f.package_effective_from)}</p><p>Answer target: {val(f.sla_target)}</p>
          <p><b>{pf.words}</b>{pf.since ? ` since ${pf.since}` : ""}</p></section>
        <section className="dpl-box" data-stale={stale}><h3>Usage</h3>
          {meters(f).map((m) => (
            <div key={m.label}><b>{m.label}</b>: {m.used !== null ? m.used : "not known"}{m.limit !== null ? ` of ${m.limit}` : ""}{m.percent !== null ? ` (${m.percent}%)` : ""} · {m.words}
              {m.percent !== null && <div className="dpl-bar" role="progressbar" aria-label={m.label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.min(100, m.percent)}><div className="dpl-fill" data-m={m.mark} style={{ width: `${Math.min(100, m.percent)}%` }} /></div>}</div>
          ))}</section>
        <section className="dpl-box" data-stale={stale}><h3>Features</h3>
          <p>In the plan and switched on: {fd.both.length ? fd.both.join(", ") : "none"}</p>
          <p>In the plan but NOT switched on: {fd.includedNotEnabled.length ? fd.includedNotEnabled.join(", ") : "none"}</p>
          <p>Switched on but NOT in the plan: {fd.enabledNotIncluded.length ? fd.enabledNotIncluded.join(", ") : "none"}</p></section>
      </div>
    </div>
  );
}
