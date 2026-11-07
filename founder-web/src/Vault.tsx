import { useEffect, useState, useSyncExternalStore } from "react";
import { Button } from "@/components/ui/button";
import { deviceStatus, leaseSubscribe, leaseView, renew, startLease, type StatusDevice } from "./lease";
import { PANIC_ACTION, PANIC_KEY, panicStage, panicText, parsePanic, phaseText, sortRows, type PanicSaved } from "./lease_pure";
import { door, loadKeys, prove } from "./passkey";

const lsGet = (k: string) => { try { return window.localStorage.getItem(k); } catch { return null; } };
const lsSet = (k: string, v: string | null) => { try { if (v === null) window.localStorage.removeItem(k); else window.localStorage.setItem(k, v); } catch { /* private window: the request still lives on the server */ } };

// J8d — Device vault lease (Settings → Privacy, under Phone alerts). The vault key of this device works only while a short server lease is live; the server renews it only for an approved, un-revoked device.
// One layout for 390 / 820 / 1200+: .setrow wraps, buttons are 44 px. G2: the browser-kept session snapshot is sealed with this key (AES-256-GCM) and deleted when the lease ends; the mail cache comes in a later phase.
const stateWord: Record<StatusDevice["state"], string> = { live: "unlocked", expired: "locked, lease ended", revoked: "revoked, locked for good", none: "never unlocked" };

export function Vault() {
  const v = useSyncExternalStore(leaseSubscribe, leaseView, leaseView);
  const [rows, setRows] = useState<StatusDevice[] | null>(null), [err, setErr] = useState<string | null>(null);
  useEffect(() => { void startLease(); }, []);
  useEffect(() => {
    let dead = false;
    const load = async () => { try { const r = await deviceStatus(); if (!dead) { setRows(r); setErr(null); } } catch (e) { if (!dead) setErr((e as Error).message); } };
    void load(); const t = setInterval(load, 20000); return () => { dead = true; clearInterval(t); };
  }, [v.serial]);
  const t = phaseText(v.phase, v.secs);
  const [pan, setPan] = useState<PanicSaved | null>(() => parsePanic(lsGet(PANIC_KEY))), [now, setNow] = useState(Date.now()), [busy, setBusy] = useState(false), [note, setNote] = useState<{ ok: boolean; t: string } | null>(null);
  useEffect(() => { const i = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(i); }, []);
  const stage = panicStage(pan, now), pt = panicText(stage, (pan?.ready_ms ?? now) - now);
  const save = (p: PanicSaved | null) => { setPan(p); lsSet(PANIC_KEY, p ? JSON.stringify(p) : null); };
  // every step is one key touch; SQL (E118 + E145) decides, this only carries it
  const act = async (f: () => Promise<string>) => { setBusy(true); setNote(null); try { setNote({ ok: true, t: await f() }); } catch (e) { setNote({ ok: false, t: (e as Error).message }); } finally { setBusy(false); } };
  const begin = () => act(async () => {
    if (!v.device) throw new Error("This sign-in has no approved device.");
    const r = await prove({ action: PANIC_ACTION, target: v.device, purpose: "t3_begin" }); if (!r.ok) throw new Error(r.error);
    const req = r.result?.request as string, ready = Number(r.result?.ready_ms);
    let exp = ready + 30 * 60_000; try { const k = await loadKeys(); const o = (k.protocol?.t3_open ?? []).find((x: any) => x.id === req); if (o?.expires_ms) exp = Number(o.expires_ms); } catch { /* the 30 minute fallback is shorter than the server window, never longer */ }
    const p = parsePanic(JSON.stringify({ request: req, nonce: r.nonce, ready_ms: ready, expires_ms: exp })); if (!p) throw new Error("The server's answer was not understood."); save(p); return "Started. The 10-minute delay is running.";
  });
  const approve = () => act(async () => { if (!pan || !v.device) throw new Error("No request."); const r = await prove({ action: PANIC_ACTION, target: v.device, purpose: "t3_approve", request: pan.request, nonce: pan.nonce }); if (!r.ok) throw new Error(r.error); save({ ...pan, approved: true }); return "Approved by the second key. Confirm to lock."; });
  const confirm = () => act(async () => { if (!pan || !v.device) throw new Error("No request."); const r = await prove({ action: PANIC_ACTION, target: v.device, purpose: "t3_execute", request: pan.request, nonce: pan.nonce }); if (!r.ok) throw new Error(r.error); save(null); setRows(null); return `Locked ${r.result?.locked ?? 0} other device(s). Only this one is left.`; });
  const cancel = () => act(async () => { if (!pan) return ""; const x = await door("t3_cancel", { p_request: pan.request, p_reason: "cancelled from Device vault lease" }); if (x.status !== 200) throw new Error(x.body?.error || "refused"); save(null); return "Cancelled."; });
  return <section className="panel" aria-label="Device vault lease">
    <div className="panelhead"><h2>Device vault lease</h2><p className="dim">Unlocks while the server trusts this device. Locks itself if it is removed or goes offline.</p></div>
    <div className="setrow" role="status"><div><b>This device: {t.title}</b><p className="dim">{v.text || t.sub}{v.serial ? ` · lease #${v.serial}` : ""}{v.hasKey ? " · key held in memory only" : ""}</p></div>
      <Button size="mini" style={{ minHeight: 44 }} disabled={v.renewing || !v.device || v.phase === "locked"} onClick={() => void renew()}>{v.renewing ? "Renewing…" : "Renew now"}</Button></div>
    {err && <p className="err" role="alert">{err}</p>}
    {rows && sortRows(rows, v.device).map((d) => <div className="setrow" key={d.device_id}><div><b>{d.label || "Device"}{d.device_id === v.device ? " (this one)" : ""}</b>
      <p className="dim">{stateWord[d.state]}{d.state === "live" ? ` · ${Math.floor(d.seconds_left / 60)} min left` : ""}{d.serial ? ` · lease #${d.serial}` : ""}{d.chain_head ? ` · chain ${d.chain_head.slice(0, 10)}` : ""}</p></div></div>)}
    <div className="setrow"><div><b>{pt.title}</b><p className="dim">{pt.sub}</p></div>
      <span style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
        {stage === "idle" || stage === "expired" ? <Button size="mini" style={{ minHeight: 44 }} disabled={busy || !v.device || v.phase === "locked"} onClick={() => void begin()}>Start panic lock</Button> : null}
        {stage === "ready" ? <Button size="mini" style={{ minHeight: 44 }} disabled={busy} onClick={() => void approve()}>Approve with second key</Button> : null}
        {stage === "approved" ? <Button size="mini" style={{ minHeight: 44 }} disabled={busy} onClick={() => void confirm()}>Confirm: lock all others</Button> : null}
        {stage === "waiting" || stage === "ready" || stage === "approved" ? <Button variant="ghost" size="mini" style={{ minHeight: 44 }} disabled={busy} onClick={() => void cancel()}>Cancel</Button> : null}
      </span></div>
    {note && <p role="status" className={note.ok ? "dim" : "err"}>{note.t}</p>}
    <div className="panelhead"><p>{v.hasKey ? "In use: this key seals the session snapshot kept in this browser (AES-256-GCM). It is deleted the moment the lease ends." : "Locked: the session snapshot in this browser is unreadable and is not kept until this device unlocks."}</p></div>
  </section>;
}
