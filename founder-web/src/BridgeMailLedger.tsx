import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import { compact, ledgerChip, type Lane } from "./mail_pure";
import "./bridgemailledger.css";

/** QUI-H (Bridge, additive): the audit home of the mail ledger. Mounted by one line in Bridge.tsx; Scene3D.tsx and BridgeLanes.tsx are not touched.
 *  Everything is read from the same fmail_ledger the mailbox writes (lanes feed E168 + ledger proof door). A number the server did not give is "—", never 0. */
const GO: Record<string, string> = { "mail-in": "inbox", "mail-quarantine": "quarantine", "mail-out": "sent", "mail-failed": "outbox", "mail-queued": "outbox" };
export function BridgeMailLedger() {
  const [box, setBox] = useState<string>(""), [lanes, setLanes] = useState<Lane[] | null>(null), [head, setHead] = useState<number | null>(null);
  const [proof, setProof] = useState<Awaited<ReturnType<typeof api.proof>>>(null), [busy, setBusy] = useState(false), [conn, setConn] = useState<boolean | null>(null);
  const verify = useCallback(async (b: string) => { if (!b) return; setBusy(true); try { setProof(await api.proof(b)); } catch { setProof(null); } setBusy(false); }, []);
  useEffect(() => { let on = true; (async () => {
    try { const b = await api.boxes(); if (!on) return; setConn(b.connected); const id = b.boxes?.[0]?.id ?? ""; setBox(id);
      const l = await api.lanes(); if (on && l) { setLanes(l.lanes); setHead(l.ledger_head); } if (id) void verify(id); } catch { if (on) setConn(false); }
  })(); return () => { on = false; }; }, [verify]);
  if (conn === false || conn === null && !lanes) return null;
  const c = ledgerChip(proof, busy, head), open = (lane: string) => { try { window.sessionStorage.setItem("mail.openview", GO[lane] ?? "inbox"); } catch { /* optional */ } window.location.hash = "#/mail"; };
  const rows = (lanes ?? []).filter((l) => GO[l.lane]);
  return (
    <section className="bml" aria-label="Mail ledger">
      <header><h2>Mail ledger</h2><span className={`bml-st ${c.tone}`} role="status"><i aria-hidden="true" />{c.text}</span>
        <button type="button" className="dx-pill" disabled={busy || !box} onClick={() => void verify(box)}>{busy ? "Checking…" : "Verify now"}</button></header>
      <p className="bml-note">One hash-chained ledger carries every arrival, quarantine, unseal and send. Head {head != null ? `#${head}` : "—"}. Tap a count to open that folder in Mail.</p>
      <ul className="bml-lanes">{rows.map((l) => <li key={l.lane}><button type="button" onClick={() => open(l.lane)}><span>{l.label}</span><b className={l.tone}>{l.count != null ? compact(l.count) : "—"}</b></button></li>)}</ul>
    </section>
  );
}
