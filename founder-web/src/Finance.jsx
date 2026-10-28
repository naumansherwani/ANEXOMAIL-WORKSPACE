import { useState } from "react";
import { CATALOG, DECK_META } from "./catalog.js";
import { LiveFeature } from "./Live.jsx";

// Gate levels mirror founder_actions (E102/E103): G1 read, G2 two-tap + reason, G3 two-tap + reason + passkey. A level can only go up.
export const GATES = {
  1: { tag: "G1 · Read", cls: "ok", text: "Signed founder session. Read only, nothing changes." },
  2: { tag: "G2 · Two-tap", cls: "warn", text: "Second tap plus a written reason. Written to the audit chain." },
  3: { tag: "G3 · Passkey", cls: "fail", text: "Two-tap, reason and your passkey. Strongest gate, written to the audit chain." },
};
export const Gate = ({ n }) => <span className={`gate lv-${GATES[n].cls}`}><i />{GATES[n].tag}</span>;
const Tile = ({ l, v, s, tone }) => <div className="tile"><span>{l}</span><b className={tone ? `lv-${tone}` : ""}>{v}</b><small>{s}</small></div>;

// One page for every deck: kicker + underlined tabs (All / Today's app / New / Gates) + tiles + row-cards. Data comes from catalog.js.
export function DeckPage({ deck, money }) {
  const meta = DECK_META[deck], items = CATALOG[deck] || [];
  const live0 = items.some((i) => i.legacy);
  const [tab, setTab] = useState(live0 ? "Live" : "All");
  const TABS = [...(live0 ? ["Live"] : []), "All", "From today's app", "New", "Gates"];
  const shown = tab === "From today's app" ? items.filter((i) => i.origin === "old") : tab === "New" ? items.filter((i) => i.origin === "new") : items;
  const n = (g) => items.filter((i) => i.gate === g).length;
  const live = deck === "finance" && money && money.connected;
  return (
    <>
      <div className="tabs" role="tablist">{TABS.map((t) => <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>{t}</button>)}</div>
      <div className="col">
        <p className="dim lead">{meta.intro}</p>
        <div className="tiles">
          {deck === "finance" && <Tile l="MRR" v={live ? `£ ${(Number(money.mrr_gbp) === 0 ? 0 : Number(money.mrr_gbp)).toLocaleString("en-GB")}` : "Not connected"} s={live ? `${money.active_accounts} active account(s)` : (money?.note || "…")} tone={live ? "" : "warn"} />}
          <Tile l="Features" v={items.length} s={`${items.filter((i) => i.origin === "old").length} from today's app · ${items.filter((i) => i.origin === "new").length} new`} />
          <Tile l="Gates" v={`${n(1)} · ${n(2)} · ${n(3)}`} s="read · two-tap · passkey" />
        </div>
        {tab === "Live" ? (
          <div className="lives"><p className="dim small">Real data from the original features, shown here on the new page. Read-only. Original pages stay as they are.</p>
            {items.filter((i) => i.legacy).map((i) => <LiveFeature key={i.title} title={i.title} summary={i.summary} path={i.legacy} />)}</div>
        ) : tab === "Gates" ? (
          <div className="list"><h3>How the three gates work</h3>
            {[1, 2, 3].map((g) => <div className="rowcard" key={g}><div><b>{GATES[g].tag} <span className="plan">· {n(g)} feature(s) in {meta.title}</span></b><em>{GATES[g].text}</em></div></div>)}
          </div>
        ) : (
          <div className="list"><h3>{tab === "All" ? `${meta.title} features` : tab}</h3>
            {shown.map((i) => (
              <div className="rowcard" key={i.title}><div><b>{i.title}</b><em>{i.summary}</em><code>{i.endpoint}</code></div>
                <Gate n={i.gate} /><span className="plan">{i.origin === "old" ? "Moves from today's app" : "New"} · {i.phase}</span></div>))}
          </div>
        )}
      </div>
    </>
  );
}
