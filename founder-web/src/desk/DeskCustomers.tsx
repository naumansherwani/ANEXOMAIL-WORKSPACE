import { useEffect, useRef, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { changedPlans, parsePlanDigest, planKey } from "./desk_plans_pure";
import { FACTS, NONE_FACTS, SOURCE_NOTE, STAR_NOTE, UNKNOWN_FACTS, type PlanKey } from "./desk_packages_pure";
import { growthWords, headline, isSmall, NOT_YOURS, NOTE, overLimitWords, PKGS, PKG_ALL, PKG_WORDS, parseCustomers, share, SMALL, sortedSignals, STATE_WORDS, STATES, TREND_WORDS, type Customers } from "./desk_customers_pure";

/** ADMIN DESK 1m-4, card B9 (Customers and Plans), 23 Nov 2026. One read-only door; the Control Plane answer is signed and the kernel verifies the whole reply (Rule 52). A person who may not open a customer gets "This is for people who may open a customer";
 *  an answer that cannot be trusted shows "Data unavailable". Counts only: no company name, no e-mail, no person. Ice-blue marks, no red. A group under five companies says "Small group". */
const CSS = `
.dcu{display:grid;gap:14px;margin-top:6px}.dcu-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dcu-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.dcu small{color:var(--mute)}
.dcu-top{display:flex;flex-wrap:wrap;gap:18px;align-items:center}.dcu-n{font-size:44px;line-height:1}.dcu-sp{flex:1 1 11rem;min-width:0}
.dcu-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(7.5rem,1fr));gap:10px;margin-top:12px}.dcu-stat{padding:10px 12px;border:1px solid var(--line);border-radius:12px;min-width:0}.dcu-stat b{display:block;font-size:22px}
.dcu-cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(16rem,1fr));gap:14px}
.dcu-row{display:grid;grid-template-columns:minmax(7rem,12rem) minmax(0,1fr) auto;gap:10px;align-items:center;min-height:32px}.dcu-bar{height:8px;border-radius:99px;background:rgba(143,184,255,.14);overflow:hidden}.dcu-bar i{display:block;height:100%;background:#8FB8FF;border-radius:99px}
.dcu-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dcu-s{padding:12px 14px;min-height:44px;border:1px solid var(--line);border-radius:12px;min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 12px;align-items:center}
.dcu-plan{display:grid;grid-template-columns:minmax(7rem,12rem) minmax(0,1fr) auto;gap:10px;align-items:center;min-height:44px;width:100%;padding:4px 8px;border:1px solid transparent;border-radius:10px;background:none;color:inherit;font:inherit;text-align:left;cursor:pointer}.dcu-plan:hover,.dcu-plan:focus-visible{border-color:#8FB8FF;outline:none}.dcu-back{min-height:44px;padding:8px 14px;border:1px solid var(--line);border-radius:10px;background:none;color:inherit;font:inherit;cursor:pointer}.dcu-facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(11rem,1fr));gap:10px}
.dcu-s[data-hot=y]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}`;

function Line({ v, label }: { v: (number | null)[]; label: string }) {
  const W = 160, H = 34, step = W / (v.length - 1), max = Math.max(1, ...v.map((n) => n ?? 0)), segs: string[] = []; let cur: string[] = [];
  v.forEach((n, i) => { if (n === null) { if (cur.length) segs.push(cur.join(" ")); cur = []; } else cur.push(`${(i * step).toFixed(1)},${(H - 3 - (n / max) * (H - 6)).toFixed(1)}`); }); if (cur.length) segs.push(cur.join(" "));
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label={label} preserveAspectRatio="none">
    {segs.map((p, i) => (p.includes(" ") ? <polyline key={i} points={p} fill="none" stroke="#8FB8FF" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /> : <circle key={i} cx={p.split(",")[0]} cy={p.split(",")[1]} r="1.8" fill="#8FB8FF" />))}
  </svg>;
}
function Split({ rows, whole }: { rows: { k: string; label: string; n: number }[]; whole: number }) {
  return <div>{rows.map((r) => (
    <div key={r.k} className="dcu-row"><span>{r.label}</span><span className="dcu-bar" aria-hidden="true"><i style={{ width: `${isSmall(r.n) ? 0 : share(r.n, whole)}%` }} /></span><b>{isSmall(r.n) ? SMALL : r.n}</b></div>))}</div>;
}
function PlanDetail({ k, c, onBack }: { k: (typeof PKG_ALL)[number]; c: Customers["census"]; onBack: () => void }) {
  const d = c.by_package[k], f = (PKGS as readonly string[]).includes(k) ? FACTS[k as PlanKey] : null;
  const rows = (o: Record<string, number>, w: (x: string) => string) => Object.keys(o).map((x) => ({ k: x, label: w(x), n: o[x] }));
  return <>
    <section className="dcu-box"><button className="dcu-back" onClick={onBack}>← Back to customers overview</button>
      <h3 style={{ marginTop: 14 }}>{PKG_WORDS[k]}</h3>
      <div className="dcu-stats">
        <div className="dcu-stat"><b>{d.companies}</b><small>{d.companies === 1 ? "company" : "companies"}</small></div>
        <div className="dcu-stat"><b>{d.seats_in_use}</b><small>seats in use</small></div>
        <div className="dcu-stat"><b>{d.storage_90}</b><small>at 90 percent storage or more</small></div>
        <div className="dcu-stat"><b>{c.over_limit[k] ?? 0}</b><small>above the seat promise</small></div>
      </div></section>
    <section className="dcu-box"><h3>What this plan is</h3>
      {f ? <><div className="dcu-facts">
        <div className="dcu-stat"><small>Price</small><b style={{ fontSize: 15 }}>{f.price}</b></div><div className="dcu-stat"><small>Users</small><b style={{ fontSize: 15 }}>{f.users}</b></div>
        <div className="dcu-stat"><small>Shared storage</small><b style={{ fontSize: 15 }}>{f.storage}</b></div><div className="dcu-stat"><small>Email attachment</small><b style={{ fontSize: 15 }}>{f.attachment}</b></div>
        <div className="dcu-stat"><small>Chat file</small><b style={{ fontSize: 15 }}>{f.chat_file}</b></div><div className="dcu-stat"><small>Outbound transfer</small><b style={{ fontSize: 15 }}>{f.transfer}</b></div></div>
        <ul style={{ margin: "12px 0 0", paddingLeft: 18 }}>{f.features.map((x) => <li key={x}>{x}</li>)}</ul>
        <p style={{ margin: "10px 0 0" }}><small>{SOURCE_NOTE}{f.unverified ? ` ${STAR_NOTE}` : ""}</small></p></>
        : <p style={{ margin: 0 }}>{k === "none" ? NONE_FACTS.about : UNKNOWN_FACTS.about}</p>}
    </section>
    <div className="dcu-cols">
      <section className="dcu-box"><h3>Service state</h3><Split whole={d.companies} rows={STATES.map((x) => ({ k: x, label: STATE_WORDS[x], n: d.states[x] }))} /></section>
      <section className="dcu-box"><h3>Size</h3><Split whole={d.companies} rows={rows(d.size_bands, (x) => `${x} ${x === "1" ? "seat" : "seats"}`)} /></section>
      <section className="dcu-box"><h3>Billing</h3><Split whole={d.companies} rows={rows(d.intervals, (x) => ({ month: "Monthly", year: "Yearly", none: "No interval" } as Record<string, string>)[x])} /></section>
    </div>
    <section className="dcu-box"><small>{NOTE}</small></section></>;
}
export function DeskCustomers({ plansFrame }: { plansFrame?: unknown } = {}) {
  const [sel, setSel] = useState<(typeof PKG_ALL)[number] | null>(null), [news, setNews] = useState<string[]>([]), [tick, setTick] = useState(0), seen = useRef<ReturnType<typeof parsePlanDigest>>(null), [v, setV] = useState<Customers | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/customers/census", {}).then((r) => {
      if (!live) return;
      if (r.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = r.status === 200 ? parseCustomers(r.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 60000);
    return () => { live = false; clearInterval(t); };
  }, [tick]);
  // B9c: a plan release arrives on the live plans track (signed, kernel-verified); the screen re-reads by itself and says which plan changed
  const pk = planKey(parsePlanDigest(plansFrame));
  useEffect(() => {
    const now = parsePlanDigest(plansFrame); if (!now) return;
    const was = seen.current; seen.current = now;
    if (was && planKey(was) !== planKey(now)) { setNews(changedPlans(was, now).map((k) => PKG_WORDS[k as keyof typeof PKG_WORDS] ?? k)); setTick((x) => x + 1); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pk]);
  const c = v?.census;
  return (
    <div className="dcu"><style>{CSS}</style>
      {news.length > 0 && <section className="dcu-box" role="status"><b>Plans updated just now:</b> {news.join(", ")}. The numbers below were re-read.</section>}
      {no && <section className="dcu-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b> The company counts are shown only to people who may open a customer.</p></section>}
      {!no && bad && <section className="dcu-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The numbers could not be verified, so none are shown.</p></section>}
      {!no && !bad && v === null && <section className="dcu-box"><small>Loading…</small></section>}
      {v && c && sel && <PlanDetail k={sel} c={c} onBack={() => setSel(null)} />}
      {v && c && !sel && <>
        <section className="dcu-box"><h3>Companies</h3>
          <div className="dcu-top"><span className="dcu-n">{c.companies}</span><span>{headline(c)}<br /><small>{TREND_WORDS[v.trend]}</small></span>
            <div className="dcu-sp"><Line v={v.spark} label="Companies over the last 24 hours; gaps mean nobody had this screen open that hour" /><small>Last 24 hours</small></div></div>
          <div className="dcu-stats">
            <div className="dcu-stat"><b>{c.states.active}</b><small>active</small></div>
            <div className="dcu-stat"><b>{c.states.trialing}</b><small>in trial</small></div>
            <div className="dcu-stat"><b>{c.renewals_7d}</b><small>renew in 7 days</small></div>
            <div className="dcu-stat"><b>{c.ended_30d}</b><small>ended in 30 days</small></div>
          </div>
        </section>
        <div className="dcu-cols">
          <section className="dcu-box"><h3>Plans</h3>
            <div>{PKG_ALL.filter((k) => c.packages[k] > 0 || (PKGS as readonly string[]).includes(k) || k === "none").map((k) => (
              <button key={k} className="dcu-plan" onClick={() => setSel(k)} aria-label={`${PKG_WORDS[k]}: ${c.packages[k]} companies. Open the plan details`}><span>{PKG_WORDS[k]}</span><span className="dcu-bar" aria-hidden="true"><i style={{ width: `${isSmall(c.packages[k]) ? 0 : share(c.packages[k], c.companies)}%` }} /></span><b>{isSmall(c.packages[k]) ? SMALL : c.packages[k]}</b></button>))}</div>
            <p style={{ margin: "8px 0 0" }}><small>Tap a plan to see what it is and who is on it.</small></p>
            {overLimitWords(c.over_limit).map((w) => <p key={w} style={{ margin: "8px 0 0" }}><small>{w}</small></p>)}
          </section>
          <section className="dcu-box"><h3>Service state</h3>
            <Split whole={c.companies} rows={STATES.map((k) => ({ k, label: STATE_WORDS[k], n: c.states[k] }))} />
          </section>
          <section className="dcu-box"><h3>Size</h3>
            <Split whole={c.companies} rows={Object.keys(c.size_bands).map((k) => ({ k, label: `${k} ${k === "1" ? "seat" : "seats"}`, n: c.size_bands[k] }))} />
          </section>
          <section className="dcu-box"><h3>Last 12 months</h3>
            <Line v={c.growth_12m} label="Companies at the end of each of the last twelve months" /><p style={{ margin: "6px 0 0" }}><small>{growthWords(c.growth_12m)}</small></p>
          </section>
        </div>
        <section className="dcu-box"><h3>Needs attention</h3>
          <ul className="dcu-list">{sortedSignals(c.signals).map((s) => (
            <li key={s.key} className="dcu-s" data-hot={s.count > 0 ? "y" : "n"}><span><b>{s.label}</b>{s.runbook && <><br /><small>Runbook: {s.runbook}</small></>}</span><b>{s.count}</b></li>))}</ul>
          <p style={{ margin: "10px 0 0" }}><small>{NOTE}</small></p>
        </section></>}
    </div>
  );
}
