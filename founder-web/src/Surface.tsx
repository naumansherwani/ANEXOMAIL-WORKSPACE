import { useCallback, useEffect, useState, useSyncExternalStore } from "react";
import { get, warm, deviceStatus } from "./api";
import { trust } from "./kernel";
import { fmtHM } from "./city";
import { HealthOrb, type Tone } from "./Scene3D";

// The Dashboard body. Everything on it is measured in THIS browser, right now (Rule 69: no mock data): the signed Rust answers, the gates from the
// action registry, the endpoints with their real response time. Technology: React-TS + CSS (glass cards, one entrance motion); the WASM kernel verifies every answer.
type Ep = { method: "GET" | "PUT" | "POST"; path: string; what: string; gate: string; probe: boolean };
export const ENDPOINTS: Ep[] = [
  { method: "GET", path: "/founder/v1/me", what: "Your account and device", gate: "Approved device", probe: true },
  { method: "GET", path: "/founder/v1/bridge", what: "Money, checks and customers", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/finance/polar", what: "Billing from Polar", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/settings", what: "Your settings", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/actions", what: "Actions and gates", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/audit", what: "Audit ledger and chain check", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/hostguard", what: "Founder only on the founder host", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/keys", what: "Public signing key", gate: "Public", probe: true },
  { method: "PUT", path: "/founder/v1/settings", what: "Save a setting", gate: "Signed write", probe: false },
  { method: "POST", path: "/founder/v1/action", what: "Request an action", gate: "Signed write, recorded in audit, runs from F8", probe: false },
  { method: "POST", path: "/founder/v1/exchange", what: "Start a device session", gate: "Sign-in", probe: false },
];
const G: Record<string, string> = {
  wallet: "M20 7H5a2 2 0 0 1 0-4h13v4zM3 5v14a2 2 0 0 0 2 2h15V7M16 14h.01", repeat: "M17 2l4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4M21 13v2a3 3 0 0 1-3 3H3",
  alert: "M12 9v4M12 17h.01M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z", users: "M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM23 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8",
  shield: "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10zM9 12l2 2 4-4", device: "M5 2h14a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1zM12 18h.01",
  ledger: "M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15zM8 7h8M8 11h8", card: "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zM2 10h20",
  bolt: "M13 2L3 14h9l-1 8 10-12h-9l1-8z", lock: "M5 11h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1zM8 11V7a4 4 0 0 1 8 0v4", sliders: "M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6", chat: "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z", check: "M22 11.1V12a10 10 0 1 1-5.9-9.1M22 4L12 14l-3-3",
};
const Gl = ({ n }: { n: string }) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={G[n]} /></svg>;
const FICON: Record<string, string> = { "Signed answers": "shield", "Approved device": "device", "Audit ledger": "ledger", "Billing": "card", "Revenue records": "wallet", "Customers": "chat", "Action registry": "bolt", "Host separation": "lock", "Settings": "sliders" };
const STX: Record<State, string> = { ok: "Live", warn: "Check", fail: "Down", unknown: "Not connected" };
type Row = { ep: Ep; ms?: number; ok?: boolean; note?: string; data?: any };
type Act = { key: string; title: string; deck: string; danger: "low" | "medium" | "high"; enabled: boolean };
type State = "ok" | "warn" | "fail" | "unknown";
const GATES: [string, "low" | "medium" | "high", string, string][] = [["G1", "low", "One tap", "Read-only and safe"], ["G2", "medium", "Two taps and a reason", "Changes something"], ["G3", "high", "Passkey", "Money, access, shutdown (arrives in F2d)"]];
const fmtMinor = (n: unknown) => (Number(n) / 100).toLocaleString("en-GB", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const cap = (s: unknown) => String(s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

function Tile({ icon, tone, label, value, unit, sub, off, bar, pct }: { icon: string; tone?: State; label: string; value?: React.ReactNode; unit?: string; sub?: React.ReactNode; off?: boolean; bar?: boolean; pct?: number }) {
  return (
    <div className="dx-card dx-tile">
      <div className="dx-lab"><span className={`dx-ic ${tone || ""}`}><Gl n={icon} /></span>{label}</div>
      {value == null ? <div className="dx-big skel" aria-label="Loading" /> : <div className={`dx-big ${off ? "off" : ""}`}>{value}{unit && <small>{unit}</small>}</div>}
      {bar && <div className="dx-bar" role="progressbar" aria-valuenow={pct ?? 0} aria-valuemin={0} aria-valuemax={100}><i style={{ width: `${pct ?? 0}%` }} /></div>}
      {sub && <div className="dx-sub">{sub}</div>}
    </div>
  );
}

export function Surface({ d, at, go }: { d: any; at: Date | string | number | null | undefined; go: (v: string) => void }) {
  const [rows, setRows] = useState<Row[] | null>(null), [checked, setChecked] = useState<Date | null>(null), [busy, setBusy] = useState(false);
  const ks = useSyncExternalStore(trust.sub, () => trust.get().state);
  const run = useCallback(async () => {
    setBusy(true); await warm();
    const out = await Promise.all(ENDPOINTS.map(async (ep): Promise<Row> => {
      if (!ep.probe) return { ep };
      const t0 = performance.now();
      try {
        if (ep.path.endsWith("/keys")) { const r = await fetch(ep.path, { cache: "no-store" }); return { ep, ok: r.ok, ms: Math.round(performance.now() - t0), note: r.ok ? "Answered" : `HTTP ${r.status}` }; }
        const r = await get(ep.path);
        return { ep, ok: true, ms: Math.round(performance.now() - t0), data: r.data, note: r.verified ? "Verified" : "Answered" };
      } catch (e) { return { ep, ok: false, ms: Math.round(performance.now() - t0), note: e instanceof Error ? e.message : "Failed" }; }
    }));
    setRows(out); setChecked(new Date()); setBusy(false);
  }, []);
  useEffect(() => { void run(); }, [run]);

  const by = (p: string) => rows?.find((r) => r.ep.path === p && r.ep.method === "GET");
  const acts: Act[] = by("/founder/v1/actions")?.data?.actions || [], actsOk = !!by("/founder/v1/actions")?.ok;
  const hg = by("/founder/v1/hostguard")?.data, au = by("/founder/v1/audit")?.data, pol = by("/founder/v1/finance/polar")?.data ?? d?.polar, ds = deviceStatus();
  const m = d?.money, v = d?.voice, hk = d?.polar_hook, subs = hk?.subscriptions, t = d?.trouble;
  const tot = t ? t.items.length : 0, bad = t ? t.items.filter((i: { state: string }) => i.state !== "ok").length : 0;
  const tone: State = !t ? "unknown" : bad ? "warn" : "ok";
  const live = rows ? rows.filter((r) => r.ep.probe) : [], okN = live.filter((r) => r.ok).length;

  // Key numbers: Polar API when connected, else the founder's own revenue records. Nothing is drawn for a source that is not connected.
  const polarApi = pol?.connected && pol.mrr_minor != null;
  const mrr = polarApi ? fmtMinor(pol.mrr_minor) : m?.connected ? Number(m.mrr_gbp || 0).toLocaleString("en-GB") : null;
  const target = Number(m?.target_gbp) || 0, pct = !polarApi && m?.connected && target ? Math.min(100, Math.round((Number(m.mrr_gbp || 0) / target) * 100)) : undefined;
  const grace = (subs?.by_product || []).reduce((a: number, x: { grace?: number }) => a + (x.grace || 0), 0);
  const feat: { name: string; state: State; text: string; to?: string }[] = rows ? [
    { name: "Signed answers", state: ks === "verified" ? "ok" : ks === "failed" ? "fail" : "unknown", text: ks === "verified" ? "Checked in this browser" : ks === "failed" ? "An answer failed the check and was hidden" : "Waiting for the first answer" },
    { name: "Approved device", state: ds.mode === "device" ? "ok" : "warn", text: ds.mode === "device" ? ds.label || "This device" : "No device token" },
    { name: "Audit ledger", state: !au ? "fail" : !au.connected ? "unknown" : au.chain_ok ? "ok" : "fail", text: !au ? "Not answering" : !au.connected ? au.note || "Not connected" : au.chain_ok ? `Chain intact${au.head ? `, entry ${au.head.seq}` : ""}` : `Chain broken at ${au.first_bad_seq}`, to: "audit" },
    { name: "Billing", state: !pol && !hk ? "fail" : pol?.connected ? (pol.stale ? "warn" : "ok") : subs?.connected ? "ok" : "unknown", text: pol?.connected ? `${pol.active_subscriptions ?? "?"} active subscriptions` : subs?.connected ? "Polar webhook live, API metrics not connected" : pol?.note || "Not connected", to: "finance" },
    { name: "Revenue records", state: !d ? "fail" : m?.connected ? "ok" : "unknown", text: !d ? "Not answering" : m?.connected ? `${m.active_accounts} active account${m.active_accounts === 1 ? "" : "s"}` : m?.note || "Not connected", to: "finance" },
    { name: "Customers", state: !d ? "fail" : v?.connected ? "ok" : "unknown", text: !d ? "Not answering" : v?.connected ? `${v.new_leads} new lead${v.new_leads === 1 ? "" : "s"}` : v?.note || "Not connected", to: "bridge" },
    { name: "Host separation", state: !hg ? "fail" : !hg.connected ? "unknown" : hg.state === "ok" ? "ok" : hg.state === "warn" ? "warn" : "unknown",
      text: !hg ? "Not answering" : !hg.connected ? hg.note || "Not connected" : hg.state === "warn" ? "A founder sign-in was seen on a user host" : hg.ready_to_enforce ? `Founder session made on the founder host${hg.last_founder_host_at ? `, ${fmtHM(hg.last_founder_host_at)}` : ""}` : hg.note || "No founder session recorded yet" },
    { name: "Action registry", state: !actsOk ? "fail" : !acts.length ? "unknown" : "ok", text: !actsOk ? "Not answering" : acts.length ? `${acts.length} actions, ${acts.filter((a) => a.enabled).length} enabled` : "No actions yet", to: "control" },
    { name: "Settings", state: by("/founder/v1/settings")?.ok ? "ok" : "fail", text: by("/founder/v1/settings")?.ok ? "Saved on the server" : "Not answering", to: "settings" },
  ] : [];
  const maxMs = Math.max(400, ...live.map((r) => r.ms || 0));

  // The orb shows only what the kernel verified: unverified answers draw a grey orb, never a guess. A failing endpoint can only make it worse.
  const orbTone: Tone = ks !== "verified" || !t ? "unknown" : rows && okN === 0 ? "fail" : bad || (rows && okN < live.length) ? (bad && t.items.some((i: { state: string }) => i.state === "fail") ? "fail" : "warn") : "ok";
  const headline = !t ? "Checking your systems" : bad ? `${bad} ${bad === 1 ? "thing needs" : "things need"} a look` : "Everything is running";
  const subline = [t ? `${tot - bad} of ${tot} checks fine` : null, rows ? `${okN} of ${live.length} endpoints answering` : null, ks === "verified" ? "Answers verified" : null].filter(Boolean).join("  ·  ");

  return (
    <div className="dx">
      <section className="dx-card dx-hero" style={{ "--i": 0 } as React.CSSProperties} aria-label="Company status">
        <div className="dx-orbwrap"><HealthOrb tone={orbTone} label={`Company health: ${headline}`} /><span className="num">{tot ? `${tot - bad}/${tot}` : "–"}</span></div>
        <div className="dx-herotx">
          <h2 className="dx-h">{headline}</h2>
          <p className="dx-p">{subline || "Nothing measured yet"}{at ? `  ·  checked ${fmtHM(at)}` : ""}</p>
        </div>
        <button className="dx-pill" onClick={() => go("bridge")}>{bad ? "Open Bridge" : "Details"}</button>
      </section>

      <section className="dx-tiles" style={{ "--i": 1 } as React.CSSProperties} aria-label="Key numbers">
        <Tile icon="wallet" label="Monthly revenue" value={!d ? null : mrr == null ? "Not connected" : <>£{mrr}</>} off={!!d && mrr == null} bar={pct != null} pct={pct}
          sub={!d ? undefined : polarApi ? "From Polar" : m?.connected ? `${m.active_accounts} active account${m.active_accounts === 1 ? "" : "s"}${target ? `  ·  ${pct}% of £${target.toLocaleString("en-GB")} target` : ""}` : m?.note} />
        <Tile icon="repeat" label="Subscriptions" value={!d ? null : pol?.connected && pol.active_subscriptions != null ? pol.active_subscriptions : subs?.connected ? (subs.by_status?.active ?? 0) : "Not connected"} off={!!d && !pol?.connected && !subs?.connected}
          sub={!d ? undefined : pol?.connected ? `${pol.new_30d} new  ·  ${pol.canceled_30d} cancelled in 30 days` : subs?.connected ? `${subs.ended_30d ?? 0} ended in 30 days` : subs?.note} />
        <Tile icon="alert" tone={subs?.connected && (subs.by_status?.past_due ?? 0) > 0 ? "warn" : undefined} label="Payment problems" value={!d ? null : subs?.connected ? (subs.by_status?.past_due ?? 0) : "Not connected"} off={!!d && !subs?.connected}
          sub={!d ? undefined : subs?.connected ? (grace ? `${grace} in grace period` : "None right now") : subs?.note} />
        <Tile icon="users" label="New customers" value={!d ? null : v?.connected ? v.new_leads : "Not connected"} off={!!d && !v?.connected} unit={v?.connected ? (v.new_leads === 1 ? "lead" : "leads") : undefined}
          sub={!d ? undefined : v?.pending_channels?.length ? `Not connected yet: ${v.pending_channels.map((c: string) => cap(c)).join(", ")}` : undefined} />
      </section>

      <h3 className="dx-sec" style={{ "--i": 2 } as React.CSSProperties}>Working features</h3>
      <section className="dx-grid" style={{ "--i": 2 } as React.CSSProperties} aria-label="Working features">
        {!rows ? [0, 1, 2, 3].map((i) => <div key={i} className="dx-card dx-feat"><div className="dx-big skel s" /></div>) : feat.map((f) => {
          const inner = <><span className={`dx-ic ${f.state}`}><Gl n={FICON[f.name] || "check"} /></span><div className="dx-fx"><div className="dx-fn">{f.name}</div><div className="dx-ft">{f.text}</div></div><span className={`st ${f.state}`}>{STX[f.state]}</span></>;
          return f.to ? <button key={f.name} className="dx-card dx-feat btn" onClick={() => go(f.to!)}>{inner}</button> : <div key={f.name} className="dx-card dx-feat">{inner}</div>;
        })}
      </section>

      <h3 className="dx-sec" style={{ "--i": 3 } as React.CSSProperties}>Gates <span>Who can do what</span></h3>
      <section className="dx-gates" style={{ "--i": 3 } as React.CSSProperties} aria-label="Gates">
        {GATES.map(([g, danger, how, why]) => {
          const list = acts.filter((a) => a.danger === danger), en = list.filter((a) => a.enabled).length;
          return (
            <div className="dx-card dx-gate" key={g}>
              <div className="dx-gtop"><b className="dx-gid">{g}</b><span className="dx-gwhy">{how}</span></div>
              <div className="dx-big">{!rows ? <span className="skel s" /> : actsOk ? list.length : "–"}<small>{actsOk ? (list.length === 1 ? "action" : "actions") : "not answering"}</small></div>
              <div className="dx-seg" aria-hidden="true">{list.map((a) => <i key={a.key} className={a.enabled ? "on" : ""} />)}</div>
              <div className="dx-sub">{!actsOk ? "Action registry is not answering" : list.length ? `${en} of ${list.length} enabled  ·  ${list.slice(0, 3).map((a) => a.title).join(", ")}${list.length > 3 ? "…" : ""}` : why}</div>
            </div>
          );
        })}
      </section>

      <details className="dx-card dx-eps" open style={{ "--i": 4 } as React.CSSProperties}>
        <summary><span className="dx-sech">Endpoints</span><span className="dx-sechs">{rows ? `${okN} of ${live.length} answering` : "Checking…"}{checked ? `  ·  ${fmtHM(checked)}` : ""}</span>
          <button className="lnk" disabled={busy} onClick={(e) => { e.preventDefault(); void run(); }}>{busy ? "Checking…" : "Check again"}</button></summary>
        <div className="dx-eplist">
          {ENDPOINTS.map((ep) => {
            const r = rows?.find((x) => x.ep === ep), st: State = !rows || !ep.probe ? "unknown" : r?.ok ? "ok" : "fail";
            return (
              <div className="dx-ep" key={ep.method + ep.path} title={`${ep.what}. ${ep.gate}.${r?.note ? ` ${r.note}.` : ""}`}>
                <i className={`sdot ${st}`} />
                <span className={`dx-m ${ep.method}`}>{ep.method}</span>
                <span className="dx-path">{ep.path.replace("/founder/v1", "")}</span>
                <span className="dx-what">{ep.what}</span>
                <span className="dx-lat">{ep.probe ? <><i style={{ width: `${Math.max(4, Math.round(((r?.ms || 0) / maxMs) * 100))}%` }} className={r?.ok === false ? "bad" : ""} /><b>{r?.ms != null ? `${r.ms} ms` : ""}</b></> : <em>Not tested here</em>}</span>
              </div>
            );
          })}
        </div>
      </details>
    </div>
  );
}
