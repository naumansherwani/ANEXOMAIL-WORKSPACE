import { useEffect, useState } from "react";
import { get } from "./api.js";

// Existing (today's app) features shown LIVE on the new page. Read-only: same-origin GET to the existing /api/founder/* routes with the same signed session.
// Interim until each feature's Rust endpoint ships (FC10: nothing new is added to the old routes). Real values only: missing = "Not measured" (Rule 63).
const human = (k) => String(k).replace(/_/g, " ").replace(/\b(gbp|mrr|arr|id|sla|dns|ai|crm|qa|p50|p95)\b/gi, (m) => m.toUpperCase()).replace(/^./, (c) => c.toUpperCase());
const isDate = (v) => typeof v === "string" && /^\d{4}-\d{2}-\d{2}T/.test(v);
function fmt(k, v) {
  if (v === null || v === undefined) return "Not measured";
  if (typeof v === "boolean") return v ? "Yes" : "No";
  if (typeof v === "number") {
    if (/gbp|revenue|spend|cost|cash|balance|mrr|arr/i.test(k) && !/count|seats|accounts/i.test(k)) return `£ ${(v === 0 ? 0 : v).toLocaleString("en-GB", { maximumFractionDigits: 2 })}`;
    if (/progress|rate|share|ratio|pct/i.test(k) && v <= 1 && v >= 0) return `${Math.round(v * 1000) / 10}%`;
    if (/_ts$|_ms$/.test(k) && v > 1e11) return new Date(v).toLocaleString("en-GB");
    return v.toLocaleString("en-GB", { maximumFractionDigits: 2 });
  }
  if (isDate(v)) return new Date(v).toLocaleString("en-GB");
  return String(v);
}
const isObj = (v) => v && typeof v === "object" && !Array.isArray(v);
const unwrap = (j) => { let x = j; for (let i = 0; i < 2; i++) if (isObj(x) && "data" in x && Object.keys(x).every((k) => ["data", "ok", "ts", "sig", "ok"].includes(k))) x = x.data; return x; };
const TITLE_KEYS = ["name", "title", "label", "org_name", "domain", "email", "slug", "key", "id"];

function Rows({ rows }) {
  const shown = rows.slice(0, 40);
  return (
    <div className="list">
      {shown.map((r, i) => {
        if (!isObj(r)) return <div className="rowcard" key={i}><div><b>{fmt("", r)}</b></div></div>;
        const tk = TITLE_KEYS.find((k) => typeof r[k] === "string" && r[k]) || Object.keys(r).find((k) => typeof r[k] === "string");
        const rest = Object.entries(r).filter(([k, v]) => k !== tk && v !== null && typeof v !== "object").slice(0, 6);
        return <div className="rowcard" key={i}><div><b>{tk ? r[tk] : `#${i + 1}`}</b><em>{rest.map(([k, v]) => `${human(k)}: ${fmt(k, v)}`).join(" · ") || " "}</em></div></div>;
      })}
      {rows.length > shown.length && <p className="dim small">+ {rows.length - shown.length} more rows</p>}
    </div>
  );
}

function Value({ v, name, depth = 0 }) {
  if (Array.isArray(v)) return v.length ? (v.every((x) => !isObj(x) && !Array.isArray(x)) ? <p className="dim">{v.map((x) => fmt("", x)).join(", ")}</p> : <Rows rows={v} />) : <p className="dim small">None</p>;
  if (isObj(v)) {
    const scalars = Object.entries(v).filter(([, x]) => !isObj(x) && !Array.isArray(x));
    const nested = Object.entries(v).filter(([, x]) => isObj(x) || Array.isArray(x));
    return (
      <>
        {scalars.length > 0 && <div className="tiles">{scalars.map(([k, x]) => <div className="tile" key={k}><span>{human(k)}</span><b className={x === null ? "lv-warn" : ""} style={{ fontSize: String(fmt(k, x)).length > 14 ? 16 : 24 }}>{fmt(k, x)}</b></div>)}</div>}
        {depth < 3 && nested.map(([k, x]) => <div key={k} className="sub"><h4>{human(k)}</h4><Value v={x} name={k} depth={depth + 1} /></div>)}
      </>
    );
  }
  return <div className="tiles"><div className="tile"><span>{human(name || "Value")}</span><b>{fmt(name || "", v)}</b></div></div>;
}

export function LiveFeature({ title, summary, path }) {
  const [st, setSt] = useState({ s: "load" });
  useEffect(() => {
    let off = false;
    get(path).then((j) => !off && setSt({ s: "ok", d: unwrap(j) })).catch((e) => !off && setSt({ s: "err", m: e.message }));
    return () => { off = true; };
  }, [path]);
  return (
    <section className="livecard">
      <header><h3>{title}</h3><span className="src">{path}</span></header>
      <p className="dim small">{summary}</p>
      {st.s === "load" && <p className="dim">Loading…</p>}
      {st.s === "err" && <p className="note">Could not load this one: {st.m}. The original page still works.</p>}
      {st.s === "ok" && (st.d === null || st.d === undefined || (isObj(st.d) && !Object.keys(st.d).length) ? <p className="dim">Nothing recorded yet.</p> : <Value v={st.d} name={title} />)}
    </section>
  );
}
