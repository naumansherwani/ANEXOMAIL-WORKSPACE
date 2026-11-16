import { useEffect, useRef, useState } from "react";
import { motion, useReducedMotion } from "motion/react";
import * as api from "./mail_api";
import { arcs, gradeTone, outLine, reasonLine, ringLabel, ringSegments, unrated, type Evidence, type OutFacts, type RingFacts } from "./trust_pure";
import "./trust.css";

// Q1b4 step d: the TRUST RING. Eight arcs (SPF, DKIM, DMARC, ARC, TLS, scan, sender, look-alike), the score in the middle, and a "Why this ring?" sheet that shows the reasons and the raw evidence.
// Everything comes from the signed Rust door; a verdict the server never produced stays GREY and says "not checked". No colour-only meaning: every arc has a text row in the sheet.
const R = 19, C = 24;
const pt = (deg: number, r = R) => { const a = ((deg - 90) * Math.PI) / 180; return [C + r * Math.cos(a), C + r * Math.sin(a)]; };
const arcPath = (s: number, e: number) => { const [x1, y1] = pt(s), [x2, y2] = pt(e); return `M${x1.toFixed(2)} ${y1.toFixed(2)}A${R} ${R} 0 0 1 ${x2.toFixed(2)} ${y2.toFixed(2)}`; };

export function TrustRing({ box, id, facts }: { box: string; id: string; facts: RingFacts }) {
  const reduce = useReducedMotion(), dlg = useRef<HTMLDialogElement>(null);
  const [ev, setEv] = useState<Evidence | null>(null), [busy, setBusy] = useState(false), [err, setErr] = useState("");
  const none = unrated(facts);
  const segs = ringSegments(facts, ev?.sender?.known ?? null);
  useEffect(() => { setEv(null); setErr(""); }, [id]);
  const open = async () => {
    dlg.current?.showModal(); if (ev || busy) return; setBusy(true); setErr("");
    try { const r = await api.authFacts(box, id); if (r && r.direction === "in" && r.evidence?.found) setEv(r.evidence as Evidence); else setErr("The server has no stored evidence for this mail yet."); } catch { setErr("The evidence could not be loaded."); }
    setBusy(false);
  };
  const tone = none ? "off" : gradeTone(facts.grade);
  return (
    <>
      <button type="button" className={`tr tr-${tone}`} onClick={() => void open()} aria-label={`${ringLabel(facts)}. Why this ring?`} title="Why this ring?">
        <svg viewBox="0 0 48 48" width="44" height="44" aria-hidden="true">
          {arcs().map((a, i) => (
            <motion.path key={segs[i].key} d={arcPath(a.start, a.end)} className={`tr-a ${segs[i].tone}`} fill="none" strokeWidth="4" strokeLinecap="round"
              initial={reduce ? false : { pathLength: 0, opacity: 0 }} animate={{ pathLength: 1, opacity: 1 }} transition={{ duration: 0.2, delay: reduce ? 0 : i * 0.02 }} />
          ))}
        </svg>
        <span className="tr-g">{none ? "–" : facts.grade}</span>
      </button>
      <dialog ref={dlg} className="trs" aria-labelledby="trs-t" onClick={(e) => { if (e.target === dlg.current) dlg.current?.close(); }}>
        <div className="trs-in">
          <div className="trs-h"><h3 id="trs-t">Why this ring?</h3><button type="button" className="trs-x" onClick={() => dlg.current?.close()} aria-label="Close">×</button></div>
          <p className="trs-s">{none ? "This mail has no stored verdict, so nothing is claimed about it." : `${facts.score} of 100 · grade ${facts.grade}`}</p>
          <ul className="trs-l">{segs.map((s) => <li key={s.key}><i className={`trs-d ${s.tone}`} aria-hidden="true" /><b>{s.label}</b><span>{s.text}</span></li>)}</ul>
          {busy && <p className="trs-n" role="status">Loading the evidence…</p>}
          {err && !busy && <p className="trs-n" role="status">{err}</p>}
          {ev && (
            <>
              {!!ev.reasons?.length && (<><h4>How the score was made</h4><ul className="trs-r">{ev.reasons.map((r, i) => <li key={i}>{reasonLine(r)}</li>)}</ul></>)}
              <h4>Evidence</h4>
              <dl className="trs-e">
                <dt>Sent from</dt><dd>{ev.client?.ip ?? "no client address"}{ev.client?.rdns ? ` · ${ev.client.rdns}` : ""}</dd>
                <dt>SPF</dt><dd>{ev.spf?.result}{ev.spf?.domain ? ` for ${ev.spf.domain}` : ""}</dd>
                <dt>DKIM</dt><dd>{ev.dkim?.count ? ev.dkim.sigs.map((s) => `${s.domain} (${s.algo}, ${s.result}${s.aligned ? ", aligned" : ""})`).join("; ") : "no signature"}</dd>
                <dt>DMARC</dt><dd>{ev.dmarc?.result}{ev.dmarc?.policy ? ` · policy ${ev.dmarc.policy}` : ""}{ev.dmarc?.record_domain ? ` · record at ${ev.dmarc.record_domain}` : ""}{ev.dmarc?.walk != null ? ` · ${ev.dmarc.walk} DNS queries` : ""}</dd>
                <dt>TLS</dt><dd>{[ev.tls?.version, ev.tls?.cipher, ev.tls?.group].filter(Boolean).join(" · ") || "not recorded"}</dd>
                {ev.spoof?.lookalike_kind && (<><dt>Look-alike</dt><dd>{ev.spoof.lookalike_kind}{ev.spoof.lookalike_of ? ` of ${ev.spoof.lookalike_of}` : ""}</dd></>)}
                {ev.spoof?.display && (<><dt>Display name</dt><dd>pretends to be another address</dd></>)}
                <dt>Chain</dt><dd>{ev.chain_ok ? "verdict chain intact" : "chain not verified"}{ev.seq != null ? ` · #${ev.seq}` : ""}{ev.row_hash ? ` · ${ev.row_hash.slice(0, 12)}…` : ""}</dd>
              </dl>
            </>
          )}
        </div>
      </dialog>
    </>
  );
}

/** Outgoing mail has no receive-side verdicts: one honest sentence (signed, TLS, the receiver's 250 time). */
export function OutFactsLine({ box, id, refresh }: { box: string; id: string; refresh?: number }) {
  const [f, setF] = useState<OutFacts | null>(null);
  useEffect(() => { let on = true; setF(null); api.authFacts(box, id).then((r) => { if (on && r?.direction === "out") setF(r.facts as OutFacts); }).catch(() => {}); return () => { on = false; }; }, [box, id, refresh]);
  return <p className="tr-out" role="status">{outLine(f)}</p>;
}
