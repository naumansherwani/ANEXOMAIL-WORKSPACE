// QC1c F5-3 / F6 (18 Nov 2026, his "haan" 08:18, old UI untouched): the lock on each recipient chip and the 'proven' line on a sent mail. React 19 + TypeScript. ADDITIVE only:
// RecipientField mounts <TlsLock/> with one line; the data comes from the server through the kernel-verified door (mail_api.tlsFor / tlsCheck). Pure logic: tls_pure.ts.
// Colours (tls.css data-tone): pq blue, classic grey, old grey, warn amber, nomail red, checking dotted. Accessibility: the lock is a named image-button (aria-label says the state in words), the tooltip is role="tooltip" and opens on hover, keyboard focus of the chip and touch; a polite aria-live
// region says when a lock changes (checking -> post-quantum). Touch targets are 44 px on coarse pointers (tls.css). One code for 390 / 820 / 1200+: only the CSS flexes.
import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import * as api from "./mail_api";
import { onMail } from "./livefeed";
import { domainsOf, lockView, needCheck, provenLine, type LockView, type TlsFact } from "./tls_pure";
import "./tls.css";

/** One small lock. `view` comes from lockView(); the tooltip text is its lines. */
export function TlsLock({ view }: { view: LockView }) {
  const id = useId(), [open, setOpen] = useState(false), [said, setSaid] = useState(""), first = useRef(true);
  useEffect(() => { if (first.current) { first.current = false; return; } setSaid(""); const t = window.setTimeout(() => setSaid(view.aria), 20); return () => window.clearTimeout(t); }, [view.aria]);
  return (
    <span className="tls-wrap" data-tone={view.tone} data-dotted={view.dotted ? "1" : undefined} onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)}>
      <button type="button" className="tls-lock" tabIndex={-1} aria-label={view.aria} aria-describedby={id} aria-expanded={open}
        onClick={(e) => { e.stopPropagation(); setOpen((o) => !o); }} onKeyDown={(e) => { if (e.key === "Escape") { e.stopPropagation(); setOpen(false); } }} onBlur={() => setOpen(false)}>
        <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true" focusable="false"><rect x="3" y="7" width="10" height="7" rx="1.6" fill="currentColor" /><path d="M5.2 7V5.2a2.8 2.8 0 0 1 5.6 0V7" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" /></svg>
        <i className="tls-s" aria-hidden="true">{view.short}</i>
      </button>
      <span id={id} role="tooltip" className={`tls-tip${open ? " on" : ""}`}><b>{view.label}</b>{view.lines.map((l, i) => <span key={i}>{l}</span>)}</span>
      <span className="sr" role="status" aria-live="polite">{said}</span>
    </span>
  );
}

/**
 * The facts for the domains of the addresses on screen. Reads the server (50 domains in one call), asks it to probe the ones without an answer (10 at a time, each at most once per minute here;
 * the server has its own cache, budget and retry schedule), and reads again when the live mail tick says the change log moved (the E190 'tls' line) or while something is still dotted.
 */
export function useTlsFacts(box: string, addrs: string[]): Record<string, TlsFact> {
  const key = useMemo(() => domainsOf(addrs).join(","), [addrs.join("\u0001")]);
  const [facts, setFacts] = useState<Record<string, TlsFact>>({});
  const asked = useRef<Map<string, number>>(new Map());
  const load = useCallback(async (ds: string[]) => {
    if (!ds.length) return;
    const r = await api.tlsFor(box, ds).catch(() => null); if (!r) return;
    setFacts((old) => { const n = { ...old }; for (const row of r.rows) n[row.domain] = row; return n; });
    const now = Date.now(), cur: Record<string, TlsFact | undefined> = {}; for (const row of r.rows) cur[row.domain] = row;
    const ask = needCheck(ds, cur, now).filter((d) => now - (asked.current.get(d) ?? 0) > 60_000);
    if (ask.length) { ask.forEach((d) => asked.current.set(d, now)); await api.tlsCheck(box, ask).catch(() => null); const r2 = await api.tlsFor(box, ds).catch(() => null); if (r2) setFacts((old) => { const n = { ...old }; for (const row of r2.rows) n[row.domain] = row; return n; }); }
  }, [box]);
  useEffect(() => { const ds = key ? key.split(",") : []; const t = window.setTimeout(() => { void load(ds); }, 450); return () => window.clearTimeout(t); }, [key, load]);
  useEffect(() => onMail((m) => { if (m.box === box && key) { void load(key.split(",")); } }), [box, key, load]);
  const dotted = Object.values(facts).some((f) => f.verdict === "checking");
  useEffect(() => { if (!dotted || !key) return; const t = window.setInterval(() => { void load(key.split(",")); }, 15_000); return () => window.clearInterval(t); }, [dotted, key, load]);
  return facts;
}

/** The 'proven' line under a SENT mail (QC1cF5-3): what the real delivery proved per recipient domain. Shows nothing until a delivery has proved something. */
export function TlsProven({ box, addrs }: { box: string; addrs: string[] }) {
  const facts = useTlsFacts(box, addrs), doms = useMemo(() => domainsOf(addrs), [addrs.join("\u0001")]);
  const line = provenLine(facts, doms);
  return line ? <p className="tls-proven" role="status">{line}</p> : null;
}
export { lockView };
