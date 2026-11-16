// Founder-only "Heartbeat + Brain" panel at the foot of the Systems page (his 16 Nov word: backend things belong in the system folder, not on the mailbox).
// Data = system_brain.json, written by docs/cursor-work/server/brain.py on every step (heartbeat = where the repo is, brain = which technology and which feature lives in which layer).
import { useState } from "react";
import brain from "./system_brain.json";
import { DkimDock } from "./DkimDock";
import { MailHealth } from "./MailHealth";
import { SendSwitch } from "./SendSwitch";
import "./systemmap.css";

const LAYERS: Record<string, string> = { rust: "Rust server", kernel: "WASM kernel (your browser)", sql: "PostgreSQL", ui: "React screen", mail: "Mail wire (SMTP)", tracked: "Tracked, not built" };
const STATUS: Record<string, [string, string]> = { live: ["Live and proven", "ok"], installed: ["Installed on your server", "ok"], written: ["Written, not installed", "warn"], off: ["Switched off", "warn"], tracked: ["Tracked only", "idle"] };

export function SystemMap() {
  const [f, setF] = useState("all"), [ph, setPh] = useState(false);
  const hb = brain.heartbeat, feats = brain.features.filter((x) => f === "all" || x.layers.includes(f));
  return (
    <div className="grid">
      <section className="card wide sm" aria-label="Mail health"><h2>MAIL HEALTH · SPEED, TRANSPORT, LEDGER, LANES</h2><div className="sm-send"><span className="sm-k">Real outgoing mail</span><SendSwitch /></div><MailHealth /></section>
      <section className="card wide sm" aria-label="Repo heartbeat">
        <h2>HEARTBEAT · WHERE THE SYSTEM IS NOW</h2>
        <div className="sm-hb">
          <div><span className="sm-k">Repo commit</span><b>{hb.head}</b><em>{hb.head_subject}</em></div>
          <div><span className="sm-k">Working on</span><b>{hb.now}</b><em>one sub-phase at a time</em></div>
          <div><span className="sm-k">Phases</span><b>{hb.phases["GREEN"] ?? 0} green</b><em>{hb.phases["NOT GREEN"] ?? 0} not green yet</em></div>
          <div><span className="sm-k">Mail steps</span><b>{hb.q_done} done</b><em>{hb.q_open} open</em></div>
          <div><span className="sm-k">Technology checks</span><b>{hb.checks_ok} hold</b><em>{hb.checks_open.length ? `${hb.checks_open.length} open` : "none open"}</em></div>
        </div>
        <p className="dim small">Written {hb.generated} from the repo. It is the state of the code, not a live probe of the server.</p>
      </section>
      <section className="card wide sm" aria-label="Technology brain">
        <h2>BRAIN · WHICH TECHNOLOGY, WHICH FEATURE, WHERE IT RUNS</h2>
        <div className="sm-chips" role="group" aria-label="Filter by layer">{["all", ...Object.keys(LAYERS)].map((k) => <button key={k} type="button" className={`sm-chip ${f === k ? "on" : ""}`} onClick={() => setF(k)}>{k === "all" ? "All" : LAYERS[k]}</button>)}</div>
        <ul className="sm-list">{feats.map((x) => { const s = STATUS[x.status] ?? ["", "idle"]; return (
          <li key={x.name}><div className="sm-top"><b>{x.name}</b><span className="sm-st" data-tone={s[1]}>{s[0]}</span></div>
            <p>{x.what}</p>{x.name === "Real outgoing mail" && <SendSwitch compact />}<p className="sm-tech"><span>{x.tech}</span><span>{x.layers.map((l) => LAYERS[l]).join(" · ")}</span><span>{x.where}</span></p></li>); })}</ul>
        <button type="button" className="mx-btn alt" aria-expanded={ph} onClick={() => setPh((o) => !o)}>{ph ? "Hide" : "Show"} all {brain.phases.length} phases and their technology</button>
        {ph && <ul className="sm-list sm-ph">{brain.phases.map((p) => <li key={p.id}><div className="sm-top"><b>{p.id}</b><span className="sm-st" data-tone={p.status === "GREEN" ? "ok" : p.status === "PAUSED" ? "idle" : "warn"}>{p.status}</span></div><p>{p.what}</p><p className="sm-tech"><span>{p.tech}</span></p></li>)}</ul>}
      </section>
      <section className="card wide sm" aria-label="Mail signing"><h2>MAIL SIGNING · DKIM KEYS, DNS, PROOF</h2><DkimDock /></section>
    </div>
  );
}
