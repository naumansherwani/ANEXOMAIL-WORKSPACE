import { useCallback, useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { deviceLabel, get } from "./api";
import { door, friendly, loadKeys, prove } from "./passkey";
import { countryList, numberProblem, toE164 } from "./countries";
import { PENDING_CACHE, PENDING_KEY, b64uBytes, isConfirmToken, pushSupported, sha256Hex, subscriptionFields } from "./flare_pure";

// J6 — Phone alerts (inside Settings → Privacy, under Security keys). A push message, encrypted to THIS phone's browser, tells you when a protected action starts.
// Adding or removing a phone is a protected step: a key approves exactly that phone (the grant is bound to sha-256 of its address). Nothing here is invented: the list comes from the server.
const ago = (ms?: number | null) => { if (!ms) return "never"; const s = Math.max(0, (Date.now() - ms) / 1000); return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} days ago`; };
const swUrl = () => `${import.meta.env.BASE_URL}flare-sw.js`;
// The server sends `require-trusted-types-for 'script'`: a service-worker URL must be a TrustedScriptURL (found live 3 Nov 12:30: 'This document requires TrustedScriptURL'). One narrow policy: only our own flare-sw.js.
type TT = { createPolicy(n: string, o: { createScriptURL(u: string): string }): { createScriptURL(u: string): string } };
/** `serviceWorker.ready` waits for the registration that controls THIS page (another scope), not for the one just registered: found live 3 Nov 12:45 ('no active Service Worker'). Wait for this very registration. */
const whenActive = (reg: ServiceWorkerRegistration): Promise<ServiceWorkerRegistration> => new Promise((ok, no) => {
  if (reg.active) return ok(reg);
  const w = reg.installing ?? reg.waiting; if (!w) return no(new Error("The alert worker did not start."));
  const t = setTimeout(() => no(new Error("The alert worker took too long to start.")), 15000);
  w.addEventListener("statechange", () => { if (w.state === "activated") { clearTimeout(t); ok(reg); } else if (w.state === "redundant") { clearTimeout(t); no(new Error("The alert worker was replaced before it started.")); } });
});
let ttPolicy: { createScriptURL(u: string): string } | null | undefined;
const swScript = (): string | unknown => {
  if (ttPolicy === undefined) { const tt = (window as unknown as { trustedTypes?: TT }).trustedTypes; try { ttPolicy = tt?.createPolicy("anexo-flare-sw", { createScriptURL(u: string) { const x = new URL(u, location.href); if (x.origin !== location.origin || x.pathname !== `${import.meta.env.BASE_URL}flare-sw.js`) throw new Error("blocked service worker url"); return x.href; } }) ?? null; } catch { ttPolicy = null; } }
  return ttPolicy ? ttPolicy.createScriptURL(swUrl()) : swUrl();
};

export function Flare() {
  const [st, setSt] = useState<any>(null), [err, setErr] = useState<string | null>(null), [busy, setBusy] = useState(false), [note, setNote] = useState<{ ok: boolean; t: string } | null>(null);
  const [last, setLast] = useState<{ ts: number; k: string; tl: number; bl: number; why: string; t: string; b: string } | null>(null), [here, setHere] = useState<string | null>(null);
  const [mob, setMob] = useState<{ registered: boolean; confirmed: boolean; last4: string } | null>(null), [dial, setDial] = useState("92"), [national, setNational] = useState("");
  const countries = useMemo(() => countryList(navigator.language || "en"), []);
  const e164 = toE164(dial, national), bad = national.trim() ? numberProblem(e164) : null;
  const reload = useCallback(async () => {
    try {
      const r = await door("push_status", {});
      if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
      setSt(r.body.result); setErr(null);
      try { const k = await loadKeys(); setMob(k.protocol?.mobile ?? null); } catch { setMob(null); }
      try { const reg = await navigator.serviceWorker?.getRegistration(swUrl()); void reg?.update().catch(() => {});
      try { const m = await (await caches.open(PENDING_CACHE)).match("/__flare/last"); setLast(m ? await m.json() : null); } catch { setLast(null); } const s = await reg?.pushManager.getSubscription(); setHere(s ? await sha256Hex(s.endpoint) : null); } catch { setHere(null); }
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
    const reg = await whenActive(await navigator.serviceWorker.register(swScript() as string));
    const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64uBytes(k.data.key) });
    const f = subscriptionFields(sub.toJSON() as any); if (!f) throw new Error("The browser gave an address the server would refuse.");
    const target = await sha256Hex(f.endpoint);
    const p = await prove({ action: "flare.push", target, params: {} });
    if (!p.ok) { await sub.unsubscribe().catch(() => {}); throw new Error(p.error); }
    const r = await door("push_subscribe", { p_endpoint: f.endpoint, p_p256dh: f.p256dh, p_auth: f.auth, p_label: deviceLabel().slice(0, 40), p_grant: p.result.grant, p_nonce: p.nonce });
    if (r.status !== 200) { await sub.unsubscribe().catch(() => {}); throw new Error(r.body?.error || `HTTP ${r.status}`); }
    return (await confirmFromCache()) ? "Phone confirmed. Alerts are on." : "Phone added. The confirmation push has not arrived yet — keep this page open; it finishes when the push lands (10 minutes).";
  });

  const remove = (ph: any) => run(async () => {
    const p = await prove({ action: "flare.push", target: ph.sha, params: { op: "remove" } });
    if (!p.ok) throw new Error(p.error);
    const r = await door("push_remove", { p_sub: ph.id, p_grant: p.result.grant, p_nonce: p.nonce });
    if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
    if (ph.sha === here) { const reg = await navigator.serviceWorker.getRegistration(swUrl()); await (await reg?.pushManager.getSubscription())?.unsubscribe().catch(() => {}); }
    return `${ph.label} removed.`;
  });

  if (err) return <section className="panel"><div className="panelhead"><h2>Phone alerts</h2><p className="dim">{err}</p></div></section>;
  if (!st) return <section className="panel"><div className="panelhead"><h2>Phone alerts</h2><p className="dim">Loading…</p></div></section>;
  const phones: any[] = st.phones ?? [], q = st.queue ?? {}, unacked: any[] = st.unacked ?? [];
  const ios = /iPhone|iPad/.test(navigator.userAgent) && !(navigator as any).standalone && !matchMedia("(display-mode: standalone)").matches;
  return <section className="panel" aria-label="Phone alerts">
    <div className="panelhead"><h2>Phone alerts</h2>
      <p className="dim">An alert on your phone when something protected starts. Encrypted, no SMS.</p></div>
    {unacked.length > 0 && <div className="setrow" role="alert"><div><b className="err">{unacked.length} alert{unacked.length > 1 ? "s" : ""} not confirmed received</b>
      <p className="dim">{unacked.slice(0, 3).map((u) => `${u.kind.replace("t3_", "")} → ${u.phone}, sent ${ago(u.sent_ms)}`).join(" · ")}. The push service accepted them, but the phone never sent its receipt. Check the phone, then send a test.</p></div></div>}
    {ios && <div className="setrow"><div><b>iPhone: one step first</b><p className="dim">Safari only allows alerts for a site on the Home Screen. Tap Share, then "Add to Home Screen", open Anexomail from that icon, and come back to this page.</p></div></div>}
    {phones.length === 0 && <div className="setrow"><div><b>No phone yet</b><p className="dim">Without a confirmed phone there is no flare. Add this phone below.</p></div></div>}
    {phones.map((p) => <div className="setrow" key={p.id}><div><b>{p.label}{p.sha === here ? " (this device)" : ""}</b>
      <p className="dim">{p.confirmed ? "Confirmed" : p.waiting ? "Waiting for the confirmation push" : "Not confirmed"} · via {p.service} · last receipt {ago(p.last_ack_ms)}{p.fail_count ? ` · ${p.fail_count} failed` : ""}</p></div>
      <Button variant="ghost" size="mini" disabled={busy} onClick={() => remove(p)}>Remove</Button></div>)}
    {!phones.some((p) => p.sha === here) && <div className="setrow"><div><b>Alerts on this device</b><p className="dim">One tap. Allow notifications, then touch your key.</p></div>
      <Button size="mini" disabled={busy || !pushSupported(window)} title={pushSupported(window) ? undefined : "This browser cannot receive push alerts"} onClick={add}>Turn on</Button></div>}
    <div className="setrow"><div><b>Alert number</b><p className="dim">{mob?.registered ? `Saved: ••••${mob.last4}${mob.confirmed ? " · confirmed" : " · not confirmed yet"}. ` : "No number saved. "}Record and recovery contact only. No SMS.</p></div>
      <span className="numrow"><select aria-label="Country code" value={dial} onChange={(e) => setDial(e.target.value)}>
          {countries.map((c) => <option key={c.iso2} value={c.dial}>{c.flag} {c.name} +{c.dial}</option>)}</select>
        <input aria-label="Mobile number" inputMode="tel" autoComplete="tel-national" placeholder="300 1234567" maxLength={20} value={national} onChange={(e) => setNational(e.target.value)} />
        <Button size="mini" disabled={busy || !e164 || !!bad} onClick={() => run(async () => {
          const n = e164!; const p = await prove({ action: "mobile.flare", target: "alert number", params: { last4: n.slice(-4) } }); if (!p.ok) throw new Error(p.error);
          const r = await door("flare_set", { p_e164: n, p_grant: p.result.grant, p_nonce: p.nonce }); if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
          setNational(""); return `Number saved (••••${n.slice(-4)}).`; })}>Save number</Button>
        {mob?.registered && <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => {
          const p = await prove({ action: "mobile.flare", target: "alert number", params: { last4: "none" } }); if (!p.ok) throw new Error(p.error);
          const r = await door("flare_remove", { p_grant: p.result.grant, p_nonce: p.nonce }); if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`);
          return "Number removed."; })}>Remove</Button>}</span></div>
    {bad && <p role="status" className="err">{bad}</p>}
    {last && <div className="setrow" aria-label="Last alert on this device"><div><b>Last alert on this device</b><p className="dim">{last.why === "ok" ? `“${last.t}” — ${last.b || "(no text)"}` : `Not one of ours (${last.why})`} · {ago(last.ts)} · title {last.tl} / text {last.bl} characters</p></div></div>}
    {phones.some((p) => p.confirmed) && <div className="setrow"><div><b>Send a test</b><p className="dim">One test per phone per minute.</p></div>
      <Button variant="ghost" size="mini" disabled={busy} onClick={() => run(async () => { const r = await door("push_test", {}); if (r.status !== 200) throw new Error(r.body?.error || `HTTP ${r.status}`); return r.body.result?.queued ? "Test queued; it arrives in a few seconds." : "A test was just sent; wait a minute."; })}>Send test</Button></div>}
    <div className="setrow"><div><b>Delivery</b><p className="dim">Queue: {Object.entries(q).map(([k, n]) => `${k} ${n}`).join(" · ") || "empty"} · ledger {st.chain?.ok ? `intact (${st.chain.checked} checked)` : "BROKEN"}.</p>
      {(st.limits ?? []).map((l: string, i: number) => <p className="dim" key={i}>• {l}</p>)}</div></div>
    {note && <p role="status" className={note.ok ? "dim" : "err"}>{note.t}</p>}
  </section>;
}
