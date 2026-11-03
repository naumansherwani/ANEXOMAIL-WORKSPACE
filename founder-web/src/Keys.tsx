import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { door, friendly, loadKeys, prove, register, runSignals, supported, type KeysView } from "./passkey";

// J4 — Security keys (inside Settings → Privacy). Everything shown comes from the server (Rust + E117/E118/E139 SQL); nothing is invented here.
// A protected step (revoke, recovery codes, phone, hardware rule) is proved with a key; the kernel re-derives the digest first (passkey.ts).
const ago = (ms?: number | null) => { if (!ms) return "never"; const s = Math.max(0, (Date.now() - ms) / 1000); return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} days ago`; };
const LEVEL: Record<string, string> = { ok: "Healthy", warn: "Needs a look", fail: "Broken", off: "Not started" };

export function Keys() {
  const [v, setV] = useState<KeysView | null>(null), [err, setErr] = useState<string | null>(null), [busy, setBusy] = useState(false), [note, setNote] = useState<{ ok: boolean; t: string } | null>(null);
  const [label, setLabel] = useState(""), [codes, setCodes] = useState<string[] | null>(null), [phone, setPhone] = useState(""), [reason, setReason] = useState<Record<string, string>>({});
  const reload = useCallback(async () => {
    try { const x = await loadKeys(); setV(x); setErr(null); if (x.signals?.length) { const r = await runSignals(x.signals); if (r.done) setNote({ ok: true, t: `Told your passkey provider about ${r.done} change${r.done > 1 ? "s" : ""} (Signal API).` }); } }
    catch (e) { setErr((e as Error).message); }
  }, []);
  useEffect(() => { void reload(); }, [reload]);
  const run = async (f: () => Promise<string>) => { setBusy(true); setNote(null); try { setNote({ ok: true, t: await f() }); await reload(); } catch (e) { setNote({ ok: false, t: friendly(e) }); } setBusy(false); };
  /** prove ONE named step with a key, then call its door with the grant */
  const step = async (action: string, target: string, params: Record<string, string>, doorName: string, body: (grant: string, n: string) => Record<string, unknown>): Promise<any> => {
    const p = await prove({ action, target, params });
    if (!p.ok) throw new Error(p.error);
    const r = await door(doorName, body(p.result.grant, p.result.nonce ?? ""));
    if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
    return r.body.result;
  };
  if (err) return <section className="panel"><div className="panelhead"><h2>Security keys</h2><p className="dim">{err}</p></div></section>;
  if (!v) return <section className="panel"><div className="panelhead"><h2>Security keys</h2><p className="dim">Loading…</p></div></section>;
  const wa = v.webauthn ?? {}, pr = v.protocol ?? {}, keys = (v.keys ?? []).filter((k) => !k.revoked), pq = v.post_quantum ?? {};
  return <section className="panel" aria-label="Security keys">
    <div className="panelhead"><h2>Security keys</h2>
      <p className="dim">Passkeys (WebAuthn Level 3). Every sign-in is judged by the server and written to a chained ledger — {LEVEL[wa.level] ?? "unknown"}: {wa.why ?? "no data yet"}.</p></div>
    {!supported() && <p className="dim">This browser cannot use passkeys.</p>}
    <div className="setrow"><div><b>Your keys ({keys.length}/5)</b><p className="dim">{pr.hardware_keys ?? 0} hardware · {pr.platform_keys ?? 0} on a device or synced. Hardware = a model on your own trusted list.</p></div></div>
    {keys.map((k) => <div className="setrow" key={k.id}><div><b>{k.label}</b><p className="dim">…{k.credential} · added {ago(k.created_ms)} · last used {ago(k.last_used_ms)}</p></div>
      <span style={{ display: "flex", gap: 6, alignItems: "center" }}>
        <input aria-label={`Why remove ${k.label}`} placeholder="Why (8+ letters)" value={reason[k.id] ?? ""} onChange={(e) => setReason({ ...reason, [k.id]: e.target.value })} style={{ width: 150 }} />
        <Button variant="ghost" size="mini" disabled={busy || keys.length <= 1 || (reason[k.id] ?? "").trim().length < 8}
          onClick={() => run(async () => { const r = (reason[k.id] ?? "").trim(); await step("passkey.revoke", (v.keys.find((x) => x.id === k.id)?.credential_id ?? ""), { reason: r }, "revoke", (g, n) => ({ p_id: k.id, p_reason: r, p_grant: g, p_nonce: n })); return `${k.label} removed.`; })}>Remove</Button></span></div>)}
    <div className="setrow"><div><b>Add a key</b><p className="dim">Name it, then use the key. A new key is a protected step: an existing key must approve it.</p></div>
      <span style={{ display: "flex", gap: 6 }}><input aria-label="Key name" placeholder="Name (e.g. YubiKey 5C)" value={label} maxLength={40} onChange={(e) => setLabel(e.target.value)} />
        <Button size="mini" disabled={busy || !supported() || !label.trim() || keys.length >= 5}
          onClick={() => run(async () => { const r = await register(label.trim()); if (!r.ok) throw new Error(r.error); setLabel(""); if (r.recovery_codes?.length) setCodes(r.recovery_codes); return "Key added."; })}>Add key</Button></span></div>
    <div className="setrow"><div><b>Recovery codes</b><p className="dim">Ten one-time codes, shown once. New codes replace the old ones.</p></div>
      <Button variant="ghost" size="mini" disabled={busy || !keys.length}
        onClick={() => run(async () => { const r = await step("recovery.codes", "new batch", {}, "recovery_codes", (g, n) => ({ p_grant: g, p_nonce: n })); setCodes(r?.codes ?? r); return "New recovery codes made. Save them now."; })}>Make new codes</Button></div>
    {codes && <pre className="dim" aria-label="Recovery codes, shown once" style={{ userSelect: "all", whiteSpace: "pre-wrap" }}>{codes.join("\n")}</pre>}
    <div className="setrow"><div><b>Protected steps need hardware</b><p className="dim">{pr.t2_hardware_only ? "On: a protected step must be approved by an allow-listed hardware key." : "Off: a synced passkey can approve a protected step."}</p></div>
      <Button variant="ghost" size="mini" disabled={busy || !keys.length}
        onClick={() => run(async () => { await step("protocol.t2_hardware", "protocol", { on: pr.t2_hardware_only ? "no" : "yes" }, "t2_hardware", (g, n) => ({ p_on: !pr.t2_hardware_only, p_grant: g, p_nonce: n })); return pr.t2_hardware_only ? "Hardware-only turned off." : "Hardware-only turned on."; })}>{pr.t2_hardware_only ? "Turn off" : "Turn on"}</Button></div>
    <div className="setrow"><div><b>Phone for the emergency flare</b><p className="dim">{pr.mobile?.registered ? `Registered …${pr.mobile.last4}${pr.mobile.confirmed ? " (confirmed)" : " (waiting for confirmation)"}.` : "None. The flare texts you when a high-risk step starts."}</p></div>
      <span style={{ display: "flex", gap: 6 }}>{!pr.mobile?.registered && <input aria-label="Phone number" placeholder="+923001234567" value={phone} onChange={(e) => setPhone(e.target.value)} />}
        {pr.mobile?.registered
          ? <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => { await step("mobile.flare", "alert number", { last4: "none" }, "flare_remove", (g, n) => ({ p_grant: g, p_nonce: n })); return "Phone removed."; })}>Remove</Button>
          : <Button size="mini" disabled={busy || !/^\+[1-9][0-9]{7,14}$/.test(phone)} onClick={() => run(async () => { await step("mobile.flare", "alert number", { last4: phone.slice(-4) }, "flare_set", (g, n) => ({ p_e164: phone, p_grant: g, p_nonce: n })); setPhone(""); return "Phone saved."; })}>Save</Button>}</span></div>
    {(pr.t3_open ?? []).map((r: any) => <div className="setrow" key={r.id}><div><b>Waiting: {r.action}</b><p className="dim">{r.state} · ready {new Date(r.ready_ms).toLocaleString()} · expires {new Date(r.expires_ms).toLocaleString()}</p></div>
      <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => { const x = await door("t3_cancel", { p_request: r.id, p_reason: "cancelled from Security keys" }); if (x.status !== 200) throw new Error(x.body?.error || "refused"); return "Cancelled."; })}>Cancel</Button></div>)}
    <div className="setrow"><div><b>Trust report</b><p className="dim">Events 24 h: {Object.entries(wa.events_24h ?? {}).map(([k, n]) => `${k} ${n}`).join(" · ") || "none"} · quarantined keys {wa.quarantined ?? 0} · key-model data {wa.mds ?? "none"} · open provider notices {wa.open_signals ?? 0}.
      Post-quantum keys: {pq.post_quantum ?? 0} ({pq.pq_allowed_by_policy ? "allowed" : "off until the standard is final"}).</p></div></div>
    {note && <p role="status" className={note.ok ? "dim" : "err"}>{note.t}</p>}
  </section>;
}
