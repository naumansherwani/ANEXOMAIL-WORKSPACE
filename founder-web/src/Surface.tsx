import { useCallback, useEffect, useState, useSyncExternalStore } from "react";
import { get, warm, deviceStatus } from "./api";
import { trust } from "./kernel";

// Dashboard "control surface": the founder API, its gates and the features that really answer — all measured in THIS browser, right now (Rule 69: no mock).
// Technology: React-TS UI over the signed Rust endpoints; every GET below is verified by the WASM kernel before it is shown.
type Ep = { method: "GET" | "PUT" | "POST"; path: string; what: string; gate: string; probe: boolean };
export const ENDPOINTS: Ep[] = [
  { method: "GET", path: "/founder/v1/me", what: "Your account and device", gate: "Approved device", probe: true },
  { method: "GET", path: "/founder/v1/bridge", what: "Money, checks and customers", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/finance/polar", what: "Billing from Polar", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/settings", what: "Your settings", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/actions", what: "Actions and gates", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/audit", what: "Audit ledger and chain check", gate: "Signed", probe: true },
  { method: "GET", path: "/founder/v1/keys", what: "Public signing key", gate: "Public", probe: true },
  { method: "PUT", path: "/founder/v1/settings", what: "Save a setting", gate: "Signed write", probe: false },
  { method: "POST", path: "/founder/v1/action", what: "Request an action", gate: "Signed write · recorded in audit · runs from F8", probe: false },
  { method: "POST", path: "/founder/v1/exchange", what: "Start a device session", gate: "Sign-in", probe: false },
];
type Row = { ep: Ep; ms?: number; ok?: boolean; note?: string; data?: any };
type Act = { key: string; title: string; deck: string; danger: "low" | "medium" | "high"; enabled: boolean };
const GATES: [string, "low" | "medium" | "high", string][] = [["G1", "low", "One tap"], ["G2", "medium", "Two taps and a reason"], ["G3", "high", "Passkey (coming in F2d)"]];

export function Surface({ go }: { go: (v: string) => void }) {
  const [rows, setRows] = useState<Row[] | null>(null), [at, setAt] = useState<Date | null>(null), [busy, setBusy] = useState(false);
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
      } catch (e) { return { ep, ok: false, ms: Math.round(performance.now() - t0), note: e instanceof Error ? e.message : "failed" }; }
    }));
    setRows(out); setAt(new Date()); setBusy(false);
  }, []);
  useEffect(() => { void run(); }, [run]);

  const by = (p: string) => rows?.find((r) => r.ep.path === p && r.ep.method === "GET");
  const acts: Act[] = by("/founder/v1/actions")?.data?.actions || [];
  const au = by("/founder/v1/audit")?.data, pol = by("/founder/v1/finance/polar")?.data, br = by("/founder/v1/bridge")?.data, hook = br?.polar_hook, ds = deviceStatus();
  const feat: { name: string; state: "ok" | "warn" | "fail" | "unknown"; text: string; to?: string }[] = rows ? [
    { name: "Signed answers", state: ks === "verified" ? "ok" : ks === "failed" ? "fail" : "unknown", text: ks === "verified" ? "Every answer is checked in this browser" : ks === "failed" ? "A response failed verification and was hidden" : "Waiting for the first answer" },
    { name: "Device approval", state: ds.mode === "device" ? "ok" : "warn", text: ds.mode === "device" ? `Approved device · ${ds.label || "this device"}` : "Signed in without a device token" },
    { name: "Audit ledger", state: !au ? "fail" : !au.connected ? "unknown" : au.chain_ok ? "ok" : "fail", text: !au ? "Not answering" : !au.connected ? au.note || "Not connected" : au.chain_ok ? `Chain intact${au.head ? ` · head #${au.head.seq}` : ""} · ${au.entries?.length ?? 0} recent entries` : `Chain broken at #${au.first_bad_seq}`, to: "audit" },
    { name: "Billing (Polar)", state: !pol && !hook ? "fail" : pol?.connected ? (pol.stale ? "warn" : "ok") : hook?.subscriptions?.connected ? "ok" : "unknown", text: pol?.connected ? `${pol.active_subscriptions ?? "?"} active subscriptions${pol.stale ? " · stale" : ""}` : hook?.subscriptions?.connected ? `Polar webhook live · ${hook.subscriptions.by_status?.active ?? 0} active subscriptions · Polar API metrics not connected` : pol?.note || "Not connected", to: "finance" },
    { name: "Finance records", state: !br ? "fail" : br.money?.connected ? "ok" : "unknown", text: !br ? "Not answering" : br.money?.connected ? `${br.money.active_accounts} active account(s)` : br.money?.note || "Not connected", to: "finance" },
    { name: "Customer voice", state: !br ? "fail" : br.voice?.connected ? "ok" : "unknown", text: !br ? "Not answering" : br.voice?.connected ? `${br.voice.new_leads} new lead(s)` : br.voice?.note || "Not connected", to: "bridge" },
    { name: "Action registry", state: !by("/founder/v1/actions")?.ok ? "fail" : !acts.length ? "unknown" : "ok", text: !by("/founder/v1/actions")?.ok ? "Not answering" : acts.length ? `${acts.length} actions · ${acts.filter((a) => a.enabled).length} enabled · actions run from F8` : "No actions registered", to: "control" },
    { name: "Settings on the server", state: by("/founder/v1/settings")?.ok ? "ok" : "fail", text: by("/founder/v1/settings")?.ok ? "Saved and read back from the server" : "Not answering", to: "settings" },
  ] : [];
  const live = rows ? rows.filter((r) => r.ep.probe) : [];
  const okN = live.filter((r) => r.ok).length;

  return (
    <>
      <h2>Working features</h2>
      <div className="ledger" aria-label="Features">
        {!rows ? <div className="lrow empty">Checking…</div> : feat.map((f) => (
          <div className="lrow" key={f.name}>
            <i className={`sdot ${f.state}`} />
            <div><div className="lt">{f.name}</div><div className="ld">{f.text}</div></div>
            {f.to ? <button className="lnk" onClick={() => go(f.to!)}>Open</button> : <span />}
          </div>
        ))}
      </div>
      <h2>Gates <span>who can do what</span></h2>
      <div className="ledger" aria-label="Gates">
        {GATES.map(([g, danger, how]) => {
          const list = acts.filter((a) => a.danger === danger);
          return (
            <div className="lrow" key={g}>
              <i className={`sdot ${!rows ? "unknown" : !by("/founder/v1/actions")?.ok ? "fail" : list.length ? "ok" : "unknown"}`} />
              <div><div className="lt">{g} · {how}</div><div className="ld">{!rows ? "Checking…" : !by("/founder/v1/actions")?.ok ? "Action registry is not answering" : list.length ? `${list.filter((a) => a.enabled).length} of ${list.length} enabled: ${list.slice(0, 4).map((a) => a.title).join(", ")}${list.length > 4 ? "…" : ""}` : "No actions at this level"}</div></div>
              <b className="lnum">{list.length}</b>
            </div>
          );
        })}
      </div>
      <h2>Endpoints <span>{rows ? `${okN} of ${live.length} answering` : "checking…"}{at ? ` · checked ${at.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" })}` : ""}</span> <button className="lnk" disabled={busy} onClick={() => void run()}>{busy ? "Checking…" : "Check again"}</button></h2>
      <div className="ledger" aria-label="Endpoints">
        {ENDPOINTS.map((ep) => {
          const r = rows?.find((x) => x.ep === ep);
          const st = !rows ? "unknown" : !ep.probe ? "unknown" : r?.ok ? "ok" : "fail";
          return (
            <div className="lrow" key={ep.method + ep.path}>
              <i className={`sdot ${st}`} />
              <div><div className="lt"><code>{ep.method}</code> {ep.path}</div><div className="ld">{ep.what} · {ep.gate}{ep.probe && r ? ` · ${r.note}` : !ep.probe ? " · Not tested here" : ""}</div></div>
              <b className="lnum">{ep.probe && r?.ms != null ? `${r.ms} ms` : ""}</b>
            </div>
          );
        })}
      </div>
    </>
  );
}
