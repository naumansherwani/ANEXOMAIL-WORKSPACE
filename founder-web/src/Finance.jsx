import { useState } from "react";

// Every finance feature carries its own gate. G1 = read (signed session), G2 = two-tap + written reason, G3 = two-tap + passkey.
// Gate levels mirror founder_actions danger/E102-E103. Features marked "Planned" are not connected yet (Rule 63: no fake data).
export const GATES = {
  1: { tag: "G1 · Read", cls: "ok", text: "Signed founder session. Read only, nothing changes." },
  2: { tag: "G2 · Two-tap", cls: "warn", text: "Second tap plus a written reason. Written to the audit chain." },
  3: { tag: "G3 · Passkey", cls: "fail", text: "Two-tap, reason and your passkey. Strongest gate, written to the audit chain." },
};
const FEATURES = [
  ["Revenue — MRR / ARR", "Real MRR and ARR per plan from Polar data", 1, "F3"],
  ["Failed payments & churn", "Whose card failed, dunning list, churn this month", 1, "F3"],
  ["Reconciliation", "Manual revenue records vs Polar, flagged when they differ", 1, "F3"],
  ["Forecast", "Target vs actual, labelled as an estimate", 1, "F3"],
  ["Biggest leak", "Where most money was lost, with proof rows", 1, "F3"],
  ["Send payment reminder", "One tap on a failed-payment row", 2, "F3"],
  ["Extend grace period", "More days before an account is restricted", 2, "F3"],
  ["Comp / free plan", "Grant a plan without payment — changes money", 3, "F4"],
];
export const Gate = ({ n }) => <span className={`gate lv-${GATES[n].cls}`}><i />{GATES[n].tag}</span>;
const Tile = ({ l, v, s, tone }) => <div className="tile"><span>{l}</span><b className={tone ? `lv-${tone}` : ""}>{v}</b><small>{s}</small></div>;

export function Finance({ money }) {
  const [tab, setTab] = useState("Overview");
  const m = money;
  const live = m && m.connected;
  const mrr = live ? (Number(m.mrr_gbp) === 0 ? 0 : Number(m.mrr_gbp)) : null;
  return (
    <>
      <div className="tabs" role="tablist">{["Overview", "Gates"].map((t) => <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>{t}</button>)}</div>
      <div className="col">
        <div className="tiles">
          <Tile l="MRR" v={live ? `£ ${mrr.toLocaleString("en-GB")}` : "Not connected"} s={live ? `${m.active_accounts} active account(s)` : (m?.note || "…")} tone={live ? "" : "warn"} />
          <Tile l="Target" v={live && m.target_gbp ? `£ ${m.target_gbp}` : "Not set"} s="monthly" />
          <Tile l="ARR / Failed payments" v="Not connected" s="arrives with Polar in F3" tone="warn" />
        </div>
        {tab === "Overview" ? (
          <div className="list"><h3>Features and their gates</h3>
            {FEATURES.map(([t, s, g, ph]) => (
              <div className="rowcard" key={t}><div><b>{t}</b><em>{s}</em></div><Gate n={g} /><span className="plan">Planned · {ph}</span></div>))}
          </div>
        ) : (
          <div className="list"><h3>How the three gates work</h3>
            {[1, 2, 3].map((g) => <div className="rowcard" key={g}><div><b>{GATES[g].tag}</b><em>{GATES[g].text}</em></div></div>)}
            <p className="dim small">The gate level of every action lives in the founder_actions registry. A level can only go up, never down.</p>
          </div>
        )}
      </div>
    </>
  );
}
