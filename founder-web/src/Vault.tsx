import { useEffect, useState, useSyncExternalStore } from "react";
import { Button } from "@/components/ui/button";
import { deviceStatus, leaseSubscribe, leaseView, renew, startLease, type StatusDevice } from "./lease";
import { phaseText, sortRows } from "./lease_pure";

// J8d — Device vault lease (Settings → Privacy, under Phone alerts). The vault key of this device works only while a short server lease is live; the server renews it only for an approved, un-revoked device.
// One layout for 390 / 820 / 1200+: .setrow wraps, buttons are 44 px. Honest: nothing is encrypted with the key yet; consumers (session snapshot, mail cache) come in later phases.
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
  return <section className="panel" aria-label="Device vault lease">
    <div className="panelhead"><h2>Device vault lease</h2><p className="dim">This device's vault key works only while a short lease from the server is live (15 minutes, renewed on its own). If this device is removed, or goes offline, it locks itself. The key lives in this page's memory only and is wiped when the lease ends.</p></div>
    <div className="setrow" role="status"><div><b>This device: {t.title}</b><p className="dim">{v.text || t.sub}{v.serial ? ` · lease #${v.serial}` : ""}{v.hasKey ? " · key held in memory only" : ""}</p></div>
      <Button size="mini" style={{ minHeight: 44 }} disabled={v.renewing || !v.device || v.phase === "locked"} onClick={() => void renew()}>{v.renewing ? "Renewing…" : "Renew now"}</Button></div>
    {err && <p className="err" role="alert">{err}</p>}
    {rows && sortRows(rows, v.device).map((d) => <div className="setrow" key={d.device_id}><div><b>{d.label || "Device"}{d.device_id === v.device ? " (this one)" : ""}</b>
      <p className="dim">{stateWord[d.state]}{d.state === "live" ? ` · ${Math.floor(d.seconds_left / 60)} min left` : ""}{d.serial ? ` · lease #${d.serial}` : ""}{d.chain_head ? ` · chain ${d.chain_head.slice(0, 10)}` : ""}</p></div></div>)}
    <p className="dim">Not yet: nothing is encrypted with this key today. It is the lock the session snapshot and mail cache will use in later phases.</p>
  </section>;
}
