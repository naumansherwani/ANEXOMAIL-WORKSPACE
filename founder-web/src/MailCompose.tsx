// Q1d: the Compose window and the Undo bar. React 19 + TypeScript + motion. Every call goes through mail_api (kernel doors); a send needs a passkey touch on the exact mail
// (mail_pure.sendTarget is the browser twin of fmail_mime::send_target). Drafts autosave as sealed versions; a stale save is shown, never merged silently.
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import * as api from "./mail_api";
import { composeProblem, parseAddrs, undoLeft, type Box } from "./mail_pure";

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
  const lists = () => ({ to: parseAddrs(to), cc: parseAddrs(cc), bcc: parseAddrs(bcc) });

  // open an existing draft
  useEffect(() => { if (!start.draft) { toRef.current?.focus(); return; } let on = true; api.draftOpen(box.id, start.draft).then((d) => { if (!on || !d) return; draft.current = { id: d.id, v: d.version }; const c = d.content; setTo((c.to ?? []).join(", ")); setCc((c.cc ?? []).join(", ")); setBcc((c.bcc ?? []).join(", ")); setShowCc(!!(c.cc?.length || c.bcc?.length)); setSubject(c.subject ?? ""); setText(c.text ?? ""); last.current = JSON.stringify([c.to ?? [], c.cc ?? [], c.bcc ?? [], c.subject ?? "", c.text ?? ""]); }); return () => { on = false; }; }, [box.id, start.draft]);

  // autosave: 1.5 s after the last change, only when something is typed
  useEffect(() => {
    const L = lists(); const snap = JSON.stringify([L.to.ok, L.cc.ok, L.bcc.ok, subject, text]);
    if (snap === last.current || (!subject.trim() && !text.trim() && !L.to.ok.length)) return;
    dirty.current = true;
    const t = window.setTimeout(async () => {
      const r = await api.draftSave(box.id, { to: L.to.ok, cc: L.cc.ok, bcc: L.bcc.ok, subject, text, in_reply_to: start.in_reply_to }, { draft: draft.current.id, expected: draft.current.v, reply_to: start.reply_to });
      if (r.ok) { draft.current = { id: r.id, v: r.version }; last.current = snap; dirty.current = false; setSaved("Draft saved"); } else setSaved(r.stale ? "This draft changed elsewhere - close and reopen it" : "Draft not saved");
    }, 1500);
    return () => window.clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [to, cc, bcc, subject, text]);

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
    if (r.ok) { onQueued(r.queued); onClose(); } else { setErr(r.error); setNeedsDkim(!!r.needsDkim); }
  }
  async function discard() { if (draft.current.id) await api.draftDiscard(box.id, draft.current.id).catch(() => false); onClose(); }

  return (
    <motion.div className="mc-wrap" initial={reduce ? false : { opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} role="dialog" aria-modal="true" aria-label="New email" onKeyDown={(e) => { if (e.key === "Escape") onClose(); if ((e.ctrlKey || e.metaKey) && e.key === "Enter") void send(); }}>
      <motion.form className="mc" initial={reduce ? false : { y: 24, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 24, opacity: 0 }} transition={{ type: "spring", stiffness: 420, damping: 36 }} onSubmit={(e) => { e.preventDefault(); void send(); }}>
        <header><h2>{start.in_reply_to ? "Reply" : "New email"}</h2><span className="dim small" aria-live="polite">{saved}</span><button type="button" className="mc-x" onClick={onClose} aria-label="Close">×</button></header>
        <label className="mc-f"><span>From</span><b>{box.address}</b></label>
        <label className="mc-f"><span>To</span><input ref={toRef} value={to} onChange={(e) => setTo(e.target.value)} placeholder="name@example.com" autoComplete="off" spellCheck={false} inputMode="email" />{!showCc && <button type="button" className="mc-link" onClick={() => setShowCc(true)}>Cc / Bcc</button>}</label>
        {showCc && <><label className="mc-f"><span>Cc</span><input value={cc} onChange={(e) => setCc(e.target.value)} autoComplete="off" spellCheck={false} inputMode="email" /></label>
          <label className="mc-f"><span>Bcc</span><input value={bcc} onChange={(e) => setBcc(e.target.value)} autoComplete="off" spellCheck={false} inputMode="email" /></label></>}
        <label className="mc-f"><span>Subject</span><input value={subject} onChange={(e) => setSubject(e.target.value)} maxLength={300} /></label>
        <label className="sr" htmlFor="mc-text">Message</label>
        <textarea id="mc-text" className="mc-t" value={text} onChange={(e) => setText(e.target.value)} placeholder="Write your message…" rows={10} />
        <AnimatePresence>{err && <motion.p key="e" className="mx-warn" role="alert" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>{err}</motion.p>}</AnimatePresence>
        {needsDkim && <DkimSetup box={box} onDone={() => setErr("")} />}
        <footer>
          <button type="submit" className="mx-btn" disabled={busy}>{busy ? "Touch your key…" : when ? "Schedule" : "Send"}</button>
          <label className="mc-when"><span className="sr">Send later</span><input type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} aria-label="Send later (optional)" /></label>
          <button type="button" className="mx-btn alt" onClick={() => void discard()}>Discard</button>
          <span className="dim small mc-hint">Sending asks for your key touch · Ctrl+Enter</span>
        </footer>
      </motion.form>
    </motion.div>
  );
}

/** After a send: a countdown with Undo. When the window closes it says what the sender does next. */
export function UndoBar({ box, q, onGone, onUndone }: { box: string; q: api.Queued; onGone: () => void; onUndone: () => void }) {
  const until = Date.parse(q.undo_until), [now, setNow] = useState(Date.now()), [state, setState] = useState<"wait" | "undoing" | "failed">("wait"), [err, setErr] = useState("");
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 250); return () => window.clearInterval(t); }, []);
  const left = undoLeft(until, now), scheduled = q.state === "scheduled";
  useEffect(() => { if (state === "wait" && left === 0 && !scheduled) { const t = window.setTimeout(onGone, 4000); return () => window.clearTimeout(t); } }, [left, scheduled, state, onGone]);
  useEffect(() => { if (scheduled && left === 0 && state === "wait") { const t = window.setTimeout(onGone, 5000); return () => window.clearTimeout(t); } }, [scheduled, left, state, onGone]);
  async function undo() { setState("undoing"); const r = await api.undo(box, q.outbox_id); if (r.ok) { onUndone(); onGone(); } else { setState("failed"); setErr(r.error || "Too late: the mail is already on its way."); } }
  return (
    <div className="mu" role="status" aria-live="polite">
      <span>{state === "undoing" ? "Taking it back…" : state === "failed" ? err : left > 0 ? `${scheduled ? "Scheduled" : "Sent"}. Undo within ${left}s` : scheduled ? `Scheduled for ${new Date(q.not_before).toLocaleString()}.` : "On its way."}</span>
      {left > 0 && state === "wait" && <button type="button" className="mx-btn alt" onClick={() => void undo()}>Undo</button>}
      <button type="button" className="mu-x" onClick={onGone} aria-label="Dismiss">×</button>
    </div>
  );
}
