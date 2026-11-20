// QC2-B: signatures + snippets, one small panel inside the compose box (insert, add, delete). Texts are sealed on the server; this screen only shows what the signed doors return.
import { useState } from "react";
import * as api from "./mail_api";
import { cleanName, placeholders, type Sig, type Snippet } from "./rich_pure";

type P = { box: string; address: string; sigs: Sig[]; snips: Snippet[]; reload: () => void; onSig: (s: Sig) => void; onSnip: (s: Snippet) => void; onClose: () => void };
export function MailRichPanel({ box, address, sigs, snips, reload, onSig, onSnip, onClose }: P) {
  const own = sigs.find((s) => s.fallback) ?? sigs[0] ?? null;
  const [sig, setSig] = useState(own?.text ?? ""), [name, setName] = useState(""), [body, setBody] = useState(""), [err, setErr] = useState(""), [busy, setBusy] = useState(false);
  const run = async (f: () => Promise<{ ok: boolean; error?: string }>) => { setBusy(true); setErr(""); const r = await f(); setBusy(false); if (!r.ok) setErr(r.error ?? "Not saved"); else reload(); return r.ok; };
  const nm = cleanName(name);
  return (
    <section className="rt-panel" aria-label="Signatures and snippets">
      <header className="rt-ph"><h3>Signature</h3><button type="button" className="mx-btn alt" onClick={onClose}>Close</button></header>
      <label className="sr" htmlFor="rt-sig">Signature text</label>
      <textarea id="rt-sig" className="rt-ta" rows={4} maxLength={2000} value={sig} onChange={(e) => setSig(e.target.value)} placeholder={`Text and https links only. Used for ${address}.`} />
      <div className="rt-row">
        <button type="button" className="mx-btn" disabled={busy || !sig.trim()} onClick={() => void run(() => api.signatureAct(box, { op: "put", from: address, text: sig, fallback: true }))}>Save signature</button>
        {own && <button type="button" className="mx-btn alt" onClick={() => onSig(own)}>Insert</button>}
        {own && <button type="button" className="mx-btn alt" disabled={busy} onClick={() => void run(async () => { const r = await api.signatureAct(box, { op: "clear", id: own.id }); if (r.ok) setSig(""); return r; })}>Remove</button>}
      </div>
      <h3>Snippets <span className="dim small">type / then the name</span></h3>
      <ul className="rt-list">
        {snips.map((s) => (
          <li key={s.id}><b>/{s.name}</b> <span className="dim small">{s.vars.length ? s.vars.map((v) => `{${v}}`).join(" ") : ""}</span>
            <span className="rt-row"><button type="button" className="mx-btn alt" onClick={() => onSnip(s)}>Insert</button>
              <button type="button" className="mx-btn alt" disabled={busy} onClick={() => void run(() => api.snippetAct(box, { op: "delete", id: s.id }))}>Delete</button></span></li>
        ))}
        {!snips.length && <li className="dim small">No snippets yet.</li>}
      </ul>
      <label className="sr" htmlFor="rt-sn">Snippet name</label>
      <input id="rt-sn" className="rt-in" value={name} onChange={(e) => setName(e.target.value)} placeholder="name (letters, digits, - _)" maxLength={41} aria-invalid={!!name && !nm} />
      <label className="sr" htmlFor="rt-sb">Snippet text</label>
      <textarea id="rt-sb" className="rt-ta" rows={4} maxLength={8000} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Hi {first_name}, … {my_name}  ({date}); any {other} stays a placeholder you fill in" />
      {!!body && <p className="dim small">Placeholders: {placeholders(body).map((p) => `{${p}}`).join(" ") || "none"}</p>}
      <div className="rt-row"><button type="button" className="mx-btn" disabled={busy || !nm || !body.trim()} onClick={() => void run(async () => { const r = await api.snippetAct(box, { op: "put", name: nm!, text: body }); if (r.ok) { setName(""); setBody(""); } return r; })}>Save snippet</button></div>
      {err && <p className="mx-warn" role="alert">{err}</p>}
    </section>
  );
}
