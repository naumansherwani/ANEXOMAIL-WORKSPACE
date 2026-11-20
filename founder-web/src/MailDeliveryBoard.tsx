// QC3 gap 2: Systems > Mail health > Delivery board. One door (/founder/v1/mail/delivery) through the Rust WASM kernel RPC (mail_api.delivery). Read only; no content, no addresses.
import { useEffect, useState } from "react";
import * as api from "./mail_api";
import { boardView } from "./delivery_pure";
import "./presend.css";

export function MailDeliveryBoard({ box }: { box: string }) {
  const [b, setB] = useState<api.DeliveryBoard | null | undefined>(undefined), [days, setDays] = useState(7);
  useEffect(() => { let on = true; setB(undefined); api.delivery(box, days).then((r) => on && setB(r)).catch(() => on && setB(null)); return () => { on = false; }; }, [box, days]);
  if (b === undefined) return <p className="dim small">Reading delivery…</p>;
  const v = boardView(b, Date.now());
  return (
    <div className="dlb" aria-label="Delivery board">
      <div className="dlb-h"><b>Delivery board</b><span className="dim small">{v.title}</span>
        <span className="dlb-d" role="group" aria-label="Period">{[1, 7, 30].map((d) => <button key={d} type="button" aria-pressed={days === d} className={days === d ? "on" : ""} onClick={() => setDays(d)}>{d === 1 ? "24 h" : `${d} d`}</button>)}</span></div>
      {b === null ? <p className="dim small">Delivery numbers are not available right now.</p> : v.empty ? <p className="dim small">{v.title}</p> : <>
        <ul className="dlb-t">{v.tiles.map((t) => <li key={t.k} className={`dlb-${t.tone}`}><b>{t.v}</b><span>{t.k}</span></li>)}</ul>
        {v.speed && <p className="dim small">{v.speed}</p>}
        <ul className="dlb-r">{v.rows.map((r) => <li key={r.id}><span className={`mx-chip sb ${r.tone === "bad" ? "bad" : r.tone === "warn" ? "warn" : "off"}`}>{r.word}</span><span>{r.who}</span><time className="dim small">{r.when}</time></li>)}</ul>
      </>}
    </div>
  );
}
