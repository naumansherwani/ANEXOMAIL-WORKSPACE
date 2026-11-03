import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { get } from "./api";
import { door, friendly, prove } from "./passkey";
import { PENDING_CACHE, PENDING_KEY, b64uBytes, isConfirmToken, pushSupported, sha256Hex, subscriptionFields } from "./flare_pure";

// J6 — Phone alerts (inside Settings → Privacy, under Security keys). A push message, encrypted to THIS phone's browser, tells you when a protected action starts.
// Adding or removing a phone is a protected step: a key approves exactly that phone (the grant is bound to sha-256 of its address). Nothing here is invented: the list comes from the server.
const ago = (ms?: number | null) => { if (!ms) return "never"; const s = Math.max(0, (Date.now() - ms) / 1000); return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} days ago`; };
const swUrl = () => `${import.meta.env.BASE_URL}flare-sw.js`;

export function Flare() {
  const [st, setSt] = useState<any>(null), [err, setErr] = useState<string | null>(null), [busy, setBusy] = useState(false), [note, setNote] = useState<{ ok: boolean; t: string } | null>(null);
  const [label, setLabel] = useState(""), [here, setHere] = useState<string | null>(null);
  const reload = useCallback(async () => {
    try {
      const r = await door("push_status", {});
      if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
      setSt(r.body.result); setErr(null);
      try { const reg = await navigator.serviceWorker?.getRegistration(swUrl()); const s = await reg?.pushManager.getSubscription(); setHere(s ? await sha256Hex(s.endpoint) : null); } catch { setHere(null); }
    } catch (e) { setErr((e as Error).message); }
  }, []);
  useEffect(() => { void reload(); }, [reload]);
  useEffect(() => {   // a push arrived while this page is open: refresh the list
    const on = (e: MessageEvent) => { if (e.data?.flare) void reload(); };
    navigator.serviceWorker?.addEventListener("message", on); return () => navigator.serviceWorker?.removeEventListener("message", on);
  }, [reload]);
  const run = async (f: () => Promise<string>) => { setBusy(true); setNote(null); try { setNote({ ok: true, t: await f() }); await reload(); } catch (e) { setNote({ ok: false, t: friendly(e) }); } setBusy(false); };

  /** wait for the confirm push to land on this phone (the service worker leaves the token in the cache), then give it back to the server */
  const confirmFromCache = async (): Promise<boolean> => {
    for (let i = 0; i < 40; i++) {
      const c = await caches.open(PENDING_CACHE); const m = await c.match(PENDING_KEY);
      if (m) {
        const t = (await m.text()).trim(); await c.delete(PENDING_KEY);
        if (!isConfirmToken(t)) return false;
        const r = await door("push_confirm", { p_token: t }); return r.status === 200 && r.body?.result?.ok === true;
      }
      await new Promise((ok) => setTimeout(ok, 1500));
    }
    return false;
  };

  const add = () => run(async () => {
    if (!pushSupported(window)) throw new Error("This browser cannot receive push alerts. On an iPhone, add the site to the Home Screen first.");
    const k = await get<{ enabled: boolean; key: string | null }>("/founder/v1/flare/key");
    if (!k.data.enabled || !k.data.key) throw new Error("Phone alerts are switched off on the server.");
    if ((await Notification.requestPermission()) !== "granted") throw new Error("Notifications were not allowed on this phone.");
    const reg = await navigator.serviceWorker.register(swUrl()); await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64uBytes(k.data.key) });
    const f = subscriptionFields(sub.toJSON() as any); if (!f) throw new Error("The browser gave an address the server would refuse.");
    const target = await sha256Hex(f.endpoint);
    const p = await prove({ action: "flare.push", target, params: {} });
    if (!p.ok) { await sub.unsubscribe().catch(() => {}); throw new Error(p.error); }
    const r = await door("push_subscribe", { p_endpoint: f.endpoint, p_p256dh: f.p256dh, p_auth: f.auth, p_label: label.trim() || "My phone", p_grant: p.result.grant, p_nonce: p.result.nonce ?? "" });
    if (r.status !== 200) { await sub.unsubscribe().catch(() => {}); throw new Error(r.body?.error || `HTTP ${r.status}`); }
    setLabel("");
    return (await confirmFromCache()) ? "Phone confirmed. Alerts are on." : "Phone added. The confirmation push has not arrived yet — keep this page open; it finishes when the push lands (10 minutes).";
  });

  const remove = (ph: any) => run(async () => {
    const p = await prove({ action: "flare.push", target: ph.sha, params: { op: "remove" } });
    if (!p.ok) throw new Error(p.error);
    const r = await door("push_remove", { p_sub: ph.id, p_grant: p.result.grant, p_nonce: p.result.nonce ?? "" });
    if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
    if (ph.sha === here) { const reg = await navigator.serviceWorker.getRegistration(swUrl()); await (await reg?.pushManager.getSubscription())?.unsubscribe().catch(() => {}); }
    return `${ph.label} removed.`;
  });

  if (err) return <section className="panel"><div className="panelhead"><h2>Phone alerts</h2><p className="dim">{err}</p></div></section>;
  if (!st) return <section className="panel"><div className="panelhead"><h2>Phone alerts</h2><p className="dim">Loading…</p></div></section>;
  const phones: any[] = st.phones ?? [], q = st.queue ?? {};
  return <section className="panel" aria-label="Phone alerts">
    <div className="panelhead"><h2>Phone alerts</h2>
      <p className="dim">When a protected action starts, your phone gets an encrypted push (Web Push). No text message and no phone number are involved. The alert is advice; the waiting time and the cancel button stay the real protection.</p></div>
    {phones.length === 0 && <div className="setrow"><div><b>No phone yet</b><p className="dim">Without a confirmed phone there is no flare. Add this phone below.</p></div></div>}
    {phones.map((p) => <div className="setrow" key={p.id}><div><b>{p.label}{p.sha === here ? " (this device)" : ""}</b>
      <p className="dim">{p.confirmed ? "Confirmed" : p.waiting ? "Waiting for the confirmation push" : "Not confirmed"} · via {p.service} · last delivered {ago(p.last_ok_ms)}{p.fail_count ? ` · ${p.fail_count} failed` : ""}</p></div>
      <Button variant="ghost" size="mini" disabled={busy} onClick={() => remove(p)}>Remove</Button></div>)}
    <div className="setrow"><div><b>Add this phone</b><p className="dim">Name it, allow notifications, then use a key. The key approves exactly this phone.</p></div>
      <span style={{ display: "flex", gap: 6 }}><input aria-label="Phone name" placeholder="My phone" maxLength={40} value={label} onChange={(e) => setLabel(e.target.value)} />
        <Button size="mini" disabled={busy || !pushSupported(window)} onClick={add}>Add</Button></span></div>
    {phones.some((p) => p.confirmed) && <div className="setrow"><div><b>Send a test</b><p className="dim">One test per phone per minute.</p></div>
      <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => { const r = await door("push_test", {}); if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`); return r.body.result?.queued ? "Test queued; it arrives in a few seconds." : "A test was just sent; wait a minute."; })}>Send test</Button></div>}
    <div className="setrow"><div><b>Delivery</b><p className="dim">Queue: {Object.entries(q).map(([k, n]) => `${k} ${n}`).join(" · ") || "empty"} · ledger {st.chain?.ok ? `intact (${st.chain.checked} checked)` : "BROKEN"}.</p>
      {(st.limits ?? []).map((l: string, i: number) => <p className="dim" key={i}>• {l}</p>)}</div></div>
    {note && <p role="status" className={note.ok ? "dim" : "err"}>{note.t}</p>}
  </section>;
}
