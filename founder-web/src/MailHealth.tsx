// Systems > Mail health (his 16 Nov 03:15 word: speed, transport pills, ledger check, mail counts and signing are SYSTEM things, not mailbox things).
// Same doors and the same pure helpers the mailbox used (mail_api, mail_pure, mailbox_pure); the mailbox screen itself is not edited, a founder-only CSS file just stops showing these cards there.
import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import { speedWords } from "./mailbox_pure";
import { MailDeliveryBoard } from "./MailDeliveryBoard";
import { ago, ledgerChip, pill, type Box, type Lane, type Proof } from "./mail_pure";

export function MailHealth() {
  const [box, setBox] = useState<Box | null>(null), [lanes, setLanes] = useState<Lane[] | null>(null), [head, setHead] = useState<number | null>(null), [bound, setBound] = useState<boolean | null>(null);
  const [speed, setSpeed] = useState<ReturnType<typeof speedWords>>(null), [h3, setH3] = useState(() => api.mailTransport());
  const [chain, setChain] = useState<Proof | null>(null), [busy, setBusy] = useState(false), [kern, setKern] = useState<Awaited<ReturnType<typeof api.verifyLedgerInKernel>>>(null);
  useEffect(() => { let on = true; api.boxes().then((r) => { if (on && r?.connected) setBox(r.boxes[0] ?? null); }).catch(() => {}); api.dbscBound().then((x) => on && setBound(x)).catch(() => {}); return () => { on = false; }; }, []);
  useEffect(() => { let on = true; const go = () => { api.lanes().then((l) => { if (on && l) { setLanes(l.lanes); setHead(l.ledger_head); } }).catch(() => {}); api.perf("24h").then((r) => { if (on) setSpeed(speedWords(r?.perf.stages.total ?? null)); }).catch(() => {}); }; go(); const t = window.setInterval(go, 60_000); return () => { on = false; window.clearInterval(t); }; }, []);
  useEffect(() => { let n = 0; const t = window.setInterval(() => { setH3(api.mailTransport()); if (++n >= 15) window.clearInterval(t); }, 2000); return () => window.clearInterval(t); }, []);
  const verify = useCallback(async () => { if (!box) return; setBusy(true); setChain(null); setKern(null); try { const pr = await api.proof(box.id); setChain(pr); setKern(await api.verifyLedgerInKernel(pr?.head_seq ?? null, (pr as any)?.head_hash ?? null)); } catch { setChain(null); } setBusy(false); }, [box]);
  const p = pill(h3, bound, box), lc = ledgerChip(chain, busy, head, kern);
  return (
    <div className="sysmh">
      <div className="sysmh-speed"><span className="sm-k">Mail speed</span>{speed ? <><p className="sysmh-v"><b>{speed.value}</b> {speed.unit}</p><p className="dim small">Arrival to sealed and stored, {speed.note}.</p></> : <><p className="sysmh-v"><b>-</b></p><p className="dim small">No real mail measured yet. It appears after the first mail arrives.</p></>}</div>
      <div className="sysmh-pills" role="status" aria-label="Mail health">
        {([p.quic, p.dbsc, p.seal] as { ok: boolean; text: string }[]).map((x) => <span key={x.text} className={`mp-seg ${x.ok ? "ok" : "no"}`}><i aria-hidden="true" />{x.text}</span>)}
        {box && <button type="button" className={`mx-chip lg ${lc.tone}`} onClick={() => void verify()} disabled={busy} title={lc.title} aria-label={lc.title}><i aria-hidden="true" />{lc.text}</button>}
      </div>
      {box && <MailDeliveryBoard box={box.id} />}
      {lanes && <ul className="sysmh-lanes" aria-label="Mail lanes, last 24 hours">{lanes.map((l) => <li key={l.lane}><i className={`ml-dot ${l.tone}`} aria-hidden="true" /><b>{l.count}</b><span>{l.label}</span>{l.last_ms ? <small>{ago(l.last_ms)}</small> : null}</li>)}</ul>}
    </div>
  );
}
