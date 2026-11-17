// Q1d: the Compose window and the Undo bar. React 19 + TypeScript + motion. Every call goes through mail_api (kernel doors); a send needs a passkey touch on the exact mail
// (mail_pure.sendTarget is the browser twin of fmail_mime::send_target). Drafts autosave as sealed versions; a stale save is shown, never merged silently.
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import * as api from "./mail_api";
import { composeProblem, undoLeft, type Box } from "./mail_pure";
import { RecipientField } from "./RecipientField";
import { chipsOf, joinChips, parseAddrs, removeChip, takenMap, type Field } from "./recipients";

export type Start = { to?: string; subject?: string; text?: string; in_reply_to?: string; reply_to?: string; draft?: string };

function DkimSetup({ box, onDone }: { box: Box; onDone: () => void }) {
  const [keys, setKeys] = useState<api.DkimRow[] | null>(null), [busy, setBusy] = useState(""), [err, setErr] = useState(""), [made, setMade] = useState<{ name: string; value: string }[]>([]);
  const load = useCallback(() => { api.dkimKeys(box.id).then(setKeys).catch(() => setKeys(null)); }, [box.id]);
  useEffect(load, [load]);
  const make = async (alg: "ed25519-sha256" | "rsa-sha256") => {
    setBusy(alg); setErr("");
    const sel = alg === "ed25519-sha256" ? "fe" : "fr";
    const r = await api.dkimCreate(box.id, sel, alg); setBusy("");
    if (r.ok) { setMade((m) => [...m, { name: r.name, value: r.value }]); load(); onDone(); } else setErr(r.error);
  };
  const have = (a: string) => keys?.some((k) => k.alg === a);
  const rows = [...(keys ?? []).map((k) => ({ name: k.dns_name, value: k.dns_value })), ...made.filter((m) => !(keys ?? []).some((k) => k.dns_name === m.name))];
  return (
    <div className="mc-dkim" role="group" aria-label="Domain signing keys">
      <p><b>Signing key needed.</b> Every mail is signed (DKIM) so receivers can trust it. Unsigned mail is never sent. Create the keys, then publish each record in your DNS.</p>
      <div className="mc-row"><button type="button" className="mx-btn" disabled={!!busy || have("ed25519-sha256")} onClick={() => void make("ed25519-sha256")}>{have("ed25519-sha256") ? "Ed25519 key exists" : busy === "ed25519-sha256" ? "Touch your key…" : "Create Ed25519 key"}</button>
        <button type="button" className="mx-btn alt" disabled={!!busy || have("rsa-sha256")} onClick={() => void make("rsa-sha256")}>{have("rsa-sha256") ? "RSA-2048 key exists" : busy === "rsa-sha256" ? "Touch your key…" : "Create RSA-2048 key"}</button></div>
      {err && <p className="mx-warn" role="alert">{err}</p>}
      {rows.map((r) => (<div className="mc-dns" key={r.name}><span className="mx-cap">TXT record</span><b>{r.name}</b><code>{r.value}</code>
        <button type="button" className="mx-btn alt" onClick={() => { void navigator.clipboard?.writeText(r.value); }}>Copy value</button></div>))}
      {rows.length > 0 && <p className="dim small">After the record is live in DNS, press Send again. Keep both keys: some receivers still read only RSA.</p>}
    </div>
  );
}

export function MailCompose({ box, start, onClose, onQueued }: { box: Box; start: Start; onClose: () => void; onQueued: (q: api.Queued) => void }) {
  const [to, setTo] = useState(start.to ?? ""), [cc, setCc] = useState(""), [bcc, setBcc] = useState(""), [showCc, setShowCc] = useState(false);
  const [subject, setSubject] = useState(start.subject ?? ""), [text, setText] = useState(start.text ?? ""), [when, setWhen] = useState("");
  const [busy, setBusy] = useState(false), [err, setErr] = useState(""), [needsDkim, setNeedsDkim] = useState(false), [saved, setSaved] = useState("");
  const draft = useRef<{ id?: string; v: number }>({ v: 0 });
  const last = useRef(""), dirty = useRef(false);
  const toRef = useRef<HTMLInputElement>(null), reduce = !!useReducedMotion();
  const taken = takenMap({ To: to, Cc: cc, Bcc: bcc });
  const setters = { To: setTo, Cc: setCc, Bcc: setBcc }, vals = { To: to, Cc: cc, Bcc: bcc };
  const moveChip = (addr: string, raw: string, from: Field, dest: Field) => {                    // QC1a: a chip moves between To / Cc / Bcc (drag or menu); the address is never duplicated
    setters[from](joinChips(removeChip(chipsOf(vals[from]), addr)));
    setters[dest](joinChips([...removeChip(chipsOf(vals[dest]), addr), ...chipsOf(raw)])); if (dest !== "To") setShowCc(true);
  };
  const lists = () => ({ to: parseAddrs(to), cc: parseAddrs(cc), bcc: parseAddrs(bcc) });

  // open an existing draft
  useEffect(() => { if (!start.draft) { toRef.current?.focus(); return; } let on = true; api.draftOpen(box.id, start.draft).then((d) => { if (!on || !d) return; draft.current = { id: d.id, v: d.version }; const c = d.content; setTo((c.to ?? []).join(", ")); setCc((c.cc ?? []).join(", ")); setBcc((c.bcc ?? []).join(", ")); setShowCc(!!(c.cc?.length || c.bcc?.length)); setSubject(c.subject ?? ""); setText(c.text ?? ""); last.current = JSON.stringify([c.to ?? [], c.cc ?? [], c.bcc ?? [], c.subject ?? "", c.text ?? ""]); }); return () => { on = false; }; }, [box.id, start.draft]);

  // autosave: 1.5 s after the last change, only when something is typed. persist() is also called when the box closes, so the last words are never lost (QC0b: a draft is ALWAYS kept).
  const latest = useRef({ to, cc, bcc, subject, text }); latest.current = { to, cc, bcc, subject, text };
  const persist = useCallback(async (): Promise<void> => {
    const v = latest.current; const L = { to: parseAddrs(v.to), cc: parseAddrs(v.cc), bcc: parseAddrs(v.bcc) }; const snap = JSON.stringify([L.to.ok, L.cc.ok, L.bcc.ok, v.subject, v.text]);
    if (snap === last.current || (!v.subject.trim() && !v.text.trim() && !L.to.ok.length)) return;
    const r = await api.draftSave(box.id, { to: L.to.ok, cc: L.cc.ok, bcc: L.bcc.ok, subject: v.subject, text: v.text, in_reply_to: start.in_reply_to }, { draft: draft.current.id, expected: draft.current.v, reply_to: start.reply_to });
    if (r.ok) { draft.current = { id: r.id, v: r.version }; last.current = snap; dirty.current = false; setSaved("Draft saved, sealed"); } else setSaved(r.stale ? "This draft changed elsewhere - close and reopen it" : "Draft not saved");
  }, [box.id, start.in_reply_to, start.reply_to]);
  useEffect(() => {
    const L = lists(); const snap = JSON.stringify([L.to.ok, L.cc.ok, L.bcc.ok, subject, text]);
    if (snap === last.current || (!subject.trim() && !text.trim() && !L.to.ok.length)) return;
    dirty.current = true;
    const t = window.setTimeout(() => { void persist(); }, 1500);
    return () => window.clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [to, cc, bcc, subject, text]);
  const closeKeep = async () => { try { await persist(); } catch { /* the draft stays as last saved */ } onClose(); };
  // QC0b: on a phone the box is full screen and follows the keyboard (visualViewport), so Send is never hidden behind it
  const [vv, setVv] = useState<{ h: number; t: number } | null>(null);
  useEffect(() => { const w = window.visualViewport; if (!w) return; const f = () => setVv({ h: Math.round(w.height), t: Math.round(w.offsetTop) }); f(); w.addEventListener("resize", f); w.addEventListener("scroll", f); return () => { w.removeEventListener("resize", f); w.removeEventListener("scroll", f); }; }, []);
  const [sure, setSure] = useState(false);
  // QC0d: Gmail-style window states: normal (centred) / large (expand) / min (bar). The component stays mounted, so nothing typed is lost.
  const [mode, setMode] = useState<"normal" | "large" | "min">("normal"), [fx, setFx] = useState(false);

  async function send() {
    setErr(""); setNeedsDkim(false);
    const L = lists(); const bad = [...L.to.bad, ...L.cc.bad, ...L.bcc.bad];
    if (bad.length) { setErr(`Not an address: ${bad.slice(0, 3).join(", ")}`); return; }
    const c = { to: L.to.ok, cc: L.cc.ok, bcc: L.bcc.ok, subject: subject.trim(), text, ...(start.in_reply_to ? { in_reply_to: start.in_reply_to } : {}) };
    const p = composeProblem(c); if (p) { setErr(p); return; }
    let schedule = ""; if (when) { const d = new Date(when); if (!(d.getTime() > Date.now() + 60_000)) { setErr("Pick a time at least a minute from now."); return; } schedule = d.toISOString().replace(/\.\d{3}Z$/, "Z"); }
    setBusy(true);
    const r = await api.send(box.id, c, { schedule: schedule || undefined, draft: draft.current.id });
    setBusy(false);
    if (r.ok) { onQueued(r.queued); const calm = reduce || document.documentElement.dataset.motion !== "full"; setFx(true); window.setTimeout(onClose, calm ? 1300 : 2900); } else { setErr(r.error); setNeedsDkim(!!r.needsDkim); }
  }
  async function discard() { if (!sure) { setSure(true); window.setTimeout(() => setSure(false), 4000); return; } if (draft.current.id) await api.draftDiscard(box.id, draft.current.id).catch(() => false); onClose(); }

  return (
    <motion.div className="mc-wrap" data-mode={mode} style={vv ? ({ "--vvh": `${vv.h}px`, "--vvt": `${vv.t}px` } as React.CSSProperties) : undefined} initial={reduce ? false : { opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} role="dialog" aria-modal="true" aria-label="New email" onKeyDown={(e) => { if (e.key === "Escape") void closeKeep(); if ((e.ctrlKey || e.metaKey) && e.key === "Enter") void send(); }}>
      <motion.form className="mc" data-mode={mode} data-fx={fx ? "sent" : undefined} initial={reduce ? false : { y: 24, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 24, opacity: 0 }} transition={{ type: "spring", stiffness: 420, damping: 36 }} onSubmit={(e) => { e.preventDefault(); void send(); }}>
        <header><h2>{start.in_reply_to ? "Reply" : "New email"}</h2><span className="dim small" aria-live="polite">{saved}</span><button type="button" className="mc-x mc-b" onClick={() => setMode(mode === "min" ? "normal" : "min")} aria-label={mode === "min" ? "Restore" : "Minimize"}>{mode === "min" ? "▢" : "–"}</button><button type="button" className="mc-x mc-b mc-exp" onClick={() => setMode(mode === "large" ? "normal" : "large")} aria-label={mode === "large" ? "Smaller" : "Expand"}>{mode === "large" ? "⤡" : "⤢"}</button><button type="button" className="mc-x" onClick={() => void closeKeep()} aria-label="Close (the draft is kept)">×</button></header>
        <label className="mc-f"><span>From</span><b>{box.address}</b></label>
        <RecipientField field="To" value={to} onChange={setTo} taken={taken} onMove={moveChip} onDragActive={(on) => { if (on) setShowCc(true); }} inputRef={toRef}
          trailing={!showCc ? <button type="button" className="mc-link" onClick={() => setShowCc(true)}>Cc / Bcc</button> : undefined} />
        {showCc && <><RecipientField field="Cc" value={cc} onChange={setCc} taken={taken} onMove={moveChip} />
          <RecipientField field="Bcc" value={bcc} onChange={setBcc} taken={taken} onMove={moveChip} /></>}
        <label className="mc-f"><span>Subject</span><input value={subject} onChange={(e) => setSubject(e.target.value)} maxLength={300} /></label>
        <label className="sr" htmlFor="mc-text">Message</label>
        <textarea id="mc-text" className="mc-t" value={text} onChange={(e) => setText(e.target.value)} placeholder="Write your message…" rows={10} />
        <AnimatePresence>{err && <motion.p key="e" className="mx-warn" role="alert" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>{err}</motion.p>}</AnimatePresence>
        {needsDkim && <DkimSetup box={box} onDone={() => setErr("")} />}
        <footer>
          <button type="submit" className="mx-btn" disabled={busy}>{busy ? "Sending…" : when ? "Schedule" : "Send"}</button>
          <label className="mc-when"><span className="sr">Send later</span><input type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} aria-label="Send later (optional)" /></label>
          <button type="button" className="mx-btn alt" onClick={() => void discard()}>{sure ? "Discard this draft? Press again" : "Discard"}</button>
          <span className="dim small mc-hint">Ctrl+Enter sends · held 30 s, you can undo</span>
        </footer>
      </motion.form>
    </motion.div>
  );
}

/** After a send: a countdown with Undo. When the window closes it says what the sender does next. */
export function UndoBar({ box, q, onGone, onUndone }: { box: string; q: api.Queued; onGone: () => void; onUndone: () => void }) {
  const until = Date.parse(q.undo_until), [now, setNow] = useState(Date.now()), [state, setState] = useState<"wait" | "undoing" | "releasing" | "released" | "failed">("wait"), [err, setErr] = useState("");
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 250); return () => window.clearInterval(t); }, []);
  const left = undoLeft(until, now), scheduled = q.state === "scheduled";
  useEffect(() => { if (state === "wait" && left === 0 && !scheduled) { const t = window.setTimeout(onGone, 4000); return () => window.clearTimeout(t); } }, [left, scheduled, state, onGone]);
  useEffect(() => { if (scheduled && left === 0 && state === "wait") { const t = window.setTimeout(onGone, 5000); return () => window.clearTimeout(t); } }, [scheduled, left, state, onGone]);
  async function undo() { setState("undoing"); const r = await api.undo(box, q.outbox_id); if (r.ok) { onUndone(); onGone(); } else { setState("failed"); setErr(r.error || "Too late: the mail is already on its way."); } }
  async function sendNow() { setState("releasing"); const r = await api.release(box, q.outbox_id); if (r.ok) { setState("released"); window.setTimeout(onGone, 4000); } else { setState("failed"); setErr(r.error || "Could not send now; the mail leaves on its own clock."); window.setTimeout(() => setState("wait"), 3500); } }
  return (
    <div className="mu" role="status" aria-live="polite" style={{ "--p": `${Math.max(0, Math.min(1, left / 30))}` } as React.CSSProperties}>
      <span>{state === "undoing" ? "Taking it back…" : state === "releasing" ? "Sending now…" : state === "released" ? "Sent. On its way now." : state === "failed" ? err : left > 0 ? `${scheduled ? "Scheduled" : "Sent"}. Undo within ${left}s` : scheduled ? `Scheduled for ${new Date(q.not_before).toLocaleString()}.` : "On its way."}</span>
      {left > 0 && state === "wait" && <button type="button" className="mx-btn alt" onClick={() => void undo()}>Undo</button>}
      {left > 0 && state === "wait" && !scheduled && <button type="button" className="mx-btn mu-now" onClick={() => void sendNow()}>Send now</button>}
      <button type="button" className="mu-x" onClick={onGone} aria-label="Dismiss">×</button>
    </div>
  );
}
