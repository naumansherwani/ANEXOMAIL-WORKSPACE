import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Flare } from "./Flare";
import { deviceLabel } from "./api";
import { approvePending, door, friendly, loadKeys, loadPending, prove, register, runSignals, supported, type KeysView, type Pending } from "./passkey";

// J4 — Security keys (inside Settings → Privacy). Everything shown comes from the server (Rust + E117/E118/E139 SQL); nothing is invented here.
// A protected step (revoke, recovery codes, phone, hardware rule) is proved with a key; the kernel re-derives the digest first (passkey.ts).
const ago = (ms?: number | null) => { if (!ms) return "never"; const s = Math.max(0, (Date.now() - ms) / 1000); return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} days ago`; };
const LEVEL: Record<string, string> = { ok: "Healthy", warn: "Needs a look", fail: "Broken", off: "Not started" };

export function Keys() {
  const [v, setV] = useState<KeysView | null>(null), [err, setErr] = useState<string | null>(null), [busy, setBusy] = useState(false), [note, setNote] = useState<{ ok: boolean; t: string } | null>(null);
  const [pend, setPend] = useState<Pending[]>([]);
  const [label, setLabel] = useState(""), [codes, setCodes] = useState<string[] | null>(null), [reason, setReason] = useState<Record<string, string>>({});
  const reload = useCallback(async () => {
    try { const x = await loadKeys(); setV(x); setErr(null); if (x.signals?.length) { const r = await runSignals(x.signals); if (r.done) setNote({ ok: true, t: `Told your passkey provider about ${r.done} change${r.done > 1 ? "s" : ""} (Signal API).` }); } }
    catch (e) { setErr((e as Error).message); }
  }, []);
  useEffect(() => { void reload(); }, [reload]);
  const loadP = useCallback(async () => { try { setPend(await loadPending()); } catch { setPend([]); } }, []);
  useEffect(() => { void loadP(); const t = setInterval(() => { void loadP(); }, 5000); return () => clearInterval(t); }, [loadP]);   // a request made on a phone shows up here within seconds; when approved it disappears on both
  const run = async (f: () => Promise<string>) => { setBusy(true); setNote(null); try { setNote({ ok: true, t: await f() }); await reload(); } catch (e) { setNote({ ok: false, t: friendly(e) }); } setBusy(false); };
  /** prove ONE named step with a key, then call its door with the grant */
  const step = async (action: string, target: string, params: Record<string, string>, doorName: string, body: (grant: string, n: string) => Record<string, unknown>): Promise<any> => {
    const p = await prove({ action, target, params });
    if (!p.ok) throw new Error(p.error);
    const r = await door(doorName, body(p.result.grant, p.nonce));
    if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
    return r.body.result;
  };
  if (err) return <section className="panel"><div className="panelhead"><h2>Security keys</h2><p className="dim">{err}</p></div></section>;
  if (!v) return <section className="panel"><div className="panelhead"><h2>Security keys</h2><p className="dim">Loading…</p></div></section>;
  const wa = v.webauthn ?? {}, pr = v.protocol ?? {}, keys = (v.keys ?? []).filter((k) => !k.revoked), pq = v.post_quantum ?? {}, hw = v.hardware && Array.isArray(v.hardware.keys) ? v.hardware : null;
  return <><section className="panel" aria-label="Security keys">
    <div className="panelhead"><h2>Security keys</h2>
      <p className="dim">Passkeys (WebAuthn Level 3). Every sign-in is judged by the server and written to a chained ledger — {LEVEL[wa.level] ?? "unknown"}: {wa.why ?? "no data yet"}.</p></div>
    {!supported() && <p className="dim">This browser cannot use passkeys.</p>}
    <div className="setrow"><div><b>Your keys ({keys.length}/5)</b><p className="dim">{pr.hardware_keys ?? 0} hardware · {pr.platform_keys ?? 0} on a device or synced. Hardware = a model on your own trusted list.</p></div></div>
    {keys.map((k) => <div className="setrow" key={k.id}><div><b>{k.label}</b><p className="dim">…{k.credential} · added {ago(k.created_ms)} · last used {ago(k.last_used_ms)}</p></div>
      <span style={{ display: "flex", gap: 6, alignItems: "center" }}>
        <input aria-label={`Why remove ${k.label}`} placeholder="Why (8+ letters)" value={reason[k.id] ?? ""} onChange={(e) => setReason({ ...reason, [k.id]: e.target.value })} style={{ width: 150 }} />
        <Button variant="ghost" size="mini" disabled={busy || keys.length <= 1 || (reason[k.id] ?? "").trim().length < 8}
          onClick={() => run(async () => { const r = (reason[k.id] ?? "").trim(); await step("passkey.revoke", (v.keys.find((x) => x.id === k.id)?.credential_id ?? ""), { reason: r }, "revoke", (g, n) => ({ p_id: k.id, p_reason: r, p_grant: g, p_nonce: n })); return `${k.label} removed.`; })}>Remove</Button></span></div>)}
    <div className="setrow"><div><b>Add a key</b><p className="dim">Fingerprint or screen lock of this device, or a USB/NFC security key. The first needs one tap on a device that already has a key.</p></div>
      <span style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
        <Button size="mini" aria-label="Add this device's fingerprint" disabled={busy || !supported() || keys.length >= 5}
          onClick={() => run(async () => { const r = await register((label.trim() || deviceLabel()).slice(0, 40), "phone"); if (!r.ok) throw new Error(r.error); setLabel(""); await loadP(); if (r.recovery_codes?.length) setCodes(r.recovery_codes); return r.pending ? "Saved. Now press Approve on a device that already has a key (5 minutes)." : "Fingerprint added."; })}>Add this device's fingerprint</Button>
        <Button size="mini" variant="ghost" disabled={busy || !supported() || keys.length >= 5}
          onClick={() => run(async () => { const r = await register((label.trim() || "Security key").slice(0, 40)); if (!r.ok) throw new Error(r.error); setLabel(""); if (r.recovery_codes?.length) setCodes(r.recovery_codes); return "Key added."; })}>Add security key</Button></span></div>
    {pend.map((p) => <div className="setrow waiting" key={p.ceremony} aria-label="Waiting for approval"><div><b>Waiting for approval: {p.label}</b>
      <p className="dim">{p.attachment === "platform" ? "Fingerprint / screen lock" : "Security key"} …{p.tail} · made on {p.device} · {Math.max(0, p.left_s)} s left. Approve it here with a key you already have; a request nobody approves disappears by itself.</p></div>
      <Button size="mini" disabled={busy} onClick={() => run(async () => { const r = await approvePending(p); if (!r.ok) throw new Error(r.error); await loadP(); return `${p.label} approved and added.`; })}>Approve</Button></div>)}

    <div className="setrow"><div><b>Recovery codes</b><p className="dim">Ten one-time codes, shown once. New codes replace the old ones.</p></div>
      <Button variant="ghost" size="mini" disabled={busy || !keys.length}
        onClick={() => run(async () => { const r = await step("recovery.codes", "new batch", {}, "recovery_codes", (g, n) => ({ p_grant: g, p_nonce: n })); setCodes(r?.codes ?? r); return "New recovery codes made. Save them now."; })}>Make new codes</Button></div>
    {codes && <pre className="dim" aria-label="Recovery codes, shown once" style={{ userSelect: "all", whiteSpace: "pre-wrap" }}>{codes.join("\n")}</pre>}
    {hw && <div className="setrow hwready" aria-label="Hardware key readiness"><div><b>Hardware keys: {hw.hardware_keys} of {hw.needed} needed</b><p className="dim">{hw.next}</p>
      <ul className="hwlist">{(hw.keys ?? []).map((k: any) => <li key={k.id}><span>{k.label}{k.attachment ? ` · ${k.attachment}` : ""}{k.be ? " · synced" : ""}</span> <em className={k.counts ? "ok" : "no"}>{k.counts ? "counts as hardware" : k.why_not}</em>
        {k.trustable && <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => { await step("aaguid.allow", k.aaguid, { enabled: "yes" }, "aaguid_allow", (g, n) => ({ p_aaguid: k.aaguid, p_label: k.label.slice(0, 60), p_enabled: true, p_grant: g, p_nonce: n })); return `${k.label}: model trusted.`; })}>Trust this model</Button>}</li>)}</ul></div></div>}
    <div className="setrow"><div><b>Protected steps need hardware</b><p className="dim">{pr.t2_hardware_only ? "On: a protected step must be approved by an allow-listed hardware key." : (pr.hardware_keys ?? 0) < 2 ? "Off: a synced passkey can approve a protected step. Needs two trusted hardware keys before it can be turned on (lock-out guard)." : "Off: a synced passkey can approve a protected step."}</p></div>
      <Button variant="ghost" size="mini" disabled={busy || !keys.length || (!pr.t2_hardware_only && (pr.hardware_keys ?? 0) < 2)} title={!pr.t2_hardware_only && (pr.hardware_keys ?? 0) < 2 ? "Needs two trusted hardware keys first (otherwise you could lock yourself out)" : undefined}
        onClick={() => run(async () => { await step("protocol.t2_hardware", "protocol", { on: pr.t2_hardware_only ? "no" : "yes" }, "t2_hardware", (g, n) => ({ p_on: !pr.t2_hardware_only, p_grant: g, p_nonce: n })); return pr.t2_hardware_only ? "Hardware-only turned off." : "Hardware-only turned on."; })}>{pr.t2_hardware_only ? "Turn off" : "Turn on"}</Button></div>
    {(pr.t3_open ?? []).map((r: any) => <div className="setrow" key={r.id}><div><b>Waiting: {r.action}</b><p className="dim">{r.state} · ready {new Date(r.ready_ms).toLocaleString()} · expires {new Date(r.expires_ms).toLocaleString()}</p></div>
      <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => { const x = await door("t3_cancel", { p_request: r.id, p_reason: "cancelled from Security keys" }); if (x.status !== 200) throw new Error(x.body?.error || "refused"); return "Cancelled."; })}>Cancel</Button></div>)}
    <div className="setrow"><div><b>Trust report</b><p className="dim">Events 24 h: {Object.entries(wa.events_24h ?? {}).map(([k, n]) => `${k} ${n}`).join(" · ") || "none"} · quarantined keys {wa.quarantined ?? 0} · key-model data {wa.mds ?? "none"} · open provider notices {wa.open_signals ?? 0}.
      Post-quantum keys: {pq.post_quantum ?? 0} ({pq.pq_allowed_by_policy ? "allowed" : "off until the standard is final"}).</p></div></div>
    {note && <p role="status" className={note.ok ? "dim" : "err"}>{note.t}</p>}
  </section>
  <Flare /></>;
}
