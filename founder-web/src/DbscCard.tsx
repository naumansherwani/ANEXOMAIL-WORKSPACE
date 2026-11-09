import { ago, view, type DbscStatus } from "./dbsc_pure";

/** The card itself: pure presentation of one status answer (the layout harness renders it with sample states). */
export function DbscCard({ s }: { s: DbscStatus }) {
  const v = view(s), devs = s.devices ?? [];
  return <section className="panel" aria-label="Device-bound sessions">
    <div className="panelhead"><h2>Device-bound sessions</h2>
      <p className="dim">The login is tied to a key inside this computer's secure chip. {s.limit ?? ""}</p></div>
    <div className="setrow"><div><b>{v.headline}</b><p className="dim">{v.detail}</p></div></div>
    {devs.map((d) => <div className="setrow" key={d.id}><div><b>{d.label}{d.id === s.this_device ? " (this device)" : ""}</b>
      <p className="dim">{d.bound ? `${d.source === "webcrypto" ? "Bound by a browser key" : "Bound by the secure chip"} ${ago(d.since)} · refreshed ${d.refreshes} time${d.refreshes === 1 ? "" : "s"}, last ${ago(d.last_refresh_at)}` : "Not bound yet (binds at its next sign-in)"}</p></div>
      <em className={d.bound ? "ok" : "no"}>{d.bound ? "Bound" : "Not bound"}</em></div>)}
    {s.report && <div className="setrow"><div><b>Ledger</b><p className="dim">Refreshes 24 h: {s.report.refreshes_24h} · refused proofs: {s.report.rejects_24h} · blocked: {s.report.blocked_24h} · chain {s.report.chain?.ok ? "intact" : "BROKEN"} ({s.report.chain?.checked ?? 0} rows checked)</p></div></div>}
  </section>;
}
