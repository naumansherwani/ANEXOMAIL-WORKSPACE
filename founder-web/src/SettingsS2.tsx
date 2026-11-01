import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { get, post } from "./api";
import { merkleVerify } from "./kernel";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { LABEL, ago, fmtVal, label, when, whatChanged } from "./s2lib";

// Founder Settings S2 (master order step 6; SQL E113, Rust settings_s2.rs). Same tabs and row pattern as the user app's Settings Center:
// Time machine (every change, one-click undo), Drift & schedule (score vs the safe baseline, scheduled changes that roll back by themselves),
// and the Explain / Blast radius / History trio under a setting. Every number comes from a signed server answer; each version shows its ledger entry
// and is proven in THIS browser by the WASM kernel (Merkle). Nothing is invented: a server without E113 says so in one honest line.

type Res<T> = { available: boolean; data?: T; note?: string };
async function ask<T = any>(path: string): Promise<Res<T>> { const r = await get(path); return r.data as Res<T>; }

const NOSQL = <div className="toast bad" role="alert">The settings time machine is not installed on the server yet. Run the E113 SQL step (sql-run.sh), then reload this page.</div>;

/** Browser-side proof: the ledger rows for these entry numbers are fetched once and every Merkle path is checked by the kernel here. */
function useProven(seqs: number[]) {
  const [ok, setOk] = useState<Record<number, boolean>>({});
  const key = seqs.join(",");
  useEffect(() => {
    let off = false;
    (async () => {
      const list = [...new Set(seqs)].filter((n) => n > 0).sort((a, b) => a - b);
      if (!list.length) return;
      const hi = list[list.length - 1], lo = Math.max(list[0], hi - 199);
      try {
        const ex = (await get(`/founder/v1/audit/export?from=${lo}&to=${hi}`)).data;
        if (!ex?.rows?.length || !ex.root) return;
        const out: Record<number, boolean> = {};
        for (const row of ex.rows) {
          const good = await merkleVerify(row.hash, (row.path || []).map((x: { s: string; h: string }) => `${x.s}:${x.h}`).join(","), ex.root);
          if (typeof row.seq === "number") out[row.seq] = good;
        }
        if (!off) setOk(out);
      } catch { /* proof unavailable: the rows simply show their entry number without the tick */ }
    })();
    return () => { off = true; };
  }, [key]); // eslint-disable-line react-hooks/exhaustive-deps
  return ok;
}

type Item = { id: number; key: string; at_ms: number; hash_only: boolean; from: unknown; to: unknown; from_hash: string | null; to_hash: string | null; was_default: boolean; now_default: boolean; reverted: boolean; can_undo: boolean; audit_seq: number | null };

export function TimeMachine({ startKey, onKey }: { startKey: string | null; onKey: (k: string | null) => void }) {
  const [items, setItems] = useState<Item[]>([]), [more, setMore] = useState<number | null>(null), [avail, setAvail] = useState(true), [err, setErr] = useState<string | null>(null), [busy, setBusy] = useState(false);
  const [undo, setUndo] = useState<Item | null>(null), [reason, setReason] = useState(""), [msg, setMsg] = useState<{ ok: boolean; t: string } | null>(null);
  const [at, setAt] = useState(""), [past, setPast] = useState<{ settings: Record<string, unknown>; hash_only: Record<string, string> } | null>(null);
  const key = startKey;
  const load = useCallback(async (before?: number) => {
    setBusy(true); setErr(null);
    try {
      const q = `limit=30${key ? `&key=${key}` : ""}${before ? `&before=${before}` : ""}`;
      const r = await ask<{ items: Item[]; more: boolean; next_before_id: number | null }>(`/founder/v1/settings/history?${q}`);
      if (!r.available || !r.data) { setAvail(false); return; }
      setAvail(true);
      setItems((cur) => (before ? [...cur, ...r.data!.items] : r.data!.items));
      setMore(r.data.more ? r.data.next_before_id : null);
    } catch (e) { setErr((e as Error).message); }
    setBusy(false);
  }, [key]);
  useEffect(() => { void load(); }, [load]);
  const proven = useProven(items.map((i) => i.audit_seq ?? 0));
  const doUndo = async () => {
    if (!undo) return;
    setBusy(true); setMsg(null);
    try {
      const r = await post("/founder/v1/settings/revert", { history_id: undo.id, reason: reason.trim() });
      if (r.status === 200) { setMsg({ ok: true, t: `Undone. ${label(undo.key)} is back to what it was.` }); setUndo(null); setReason(""); await load(); }
      else setMsg({ ok: false, t: r.body?.error || `Not undone (HTTP ${r.status})` });
    } catch (e) { setMsg({ ok: false, t: (e as Error).message }); }
    setBusy(false);
  };
  const showPast = async (v: string) => {
    setAt(v); setPast(null);
    const ms = Date.parse(v); if (!Number.isFinite(ms)) return;
    try { const r = await ask<{ settings: Record<string, unknown>; hash_only: Record<string, string> }>(`/founder/v1/settings/at?t=${ms}`); if (r.available && r.data) setPast(r.data); } catch (e) { setErr((e as Error).message); }
  };
  if (!avail) return NOSQL;
  const n = items.length;
  return (
    <section className="panel s2">
      <div className="panelhead"><h2>Every setting change, reversible</h2><p className="dim">Who changed what, when, and why — and one click to put it back exactly as it was. Each version shows its ledger entry; the tick means this browser proved it.</p></div>
      <div className="s2bar">
        <label className="s2sel">Show
          <select value={key ?? ""} onChange={(e) => onKey(e.target.value || null)} aria-label="Filter by setting">
            <option value="">All settings</option>
            {Object.entries(LABEL).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
          </select></label>
        <label className="s2sel">See settings as of
          <input type="datetime-local" value={at} onChange={(e) => void showPast(e.target.value)} aria-label="Point in time" /></label>
      </div>
      {past && <div className="s2past" role="status"><b>On {new Date(Date.parse(at)).toLocaleString()}</b>
        {Object.keys(past.settings).length + Object.keys(past.hash_only).length === 0 ? <span className="dim"> every setting was at its default</span> :
          <ul>{Object.entries(past.settings).map(([k, v]) => <li key={k}><span>{label(k)}</span><em>{fmtVal(k, v)}</em></li>)}
            {Object.keys(past.hash_only).map((k) => <li key={k}><span>{label(k)}</span><em>photo set</em></li>)}</ul>}</div>}
      <div className="s2count dim">{n === 0 && !busy ? "This account has made no setting changes in this view." : `${n} version${n === 1 ? "" : "s"} shown`}</div>
      <ul className="s2list">
        {items.map((it) => (
          <li key={it.id} className={`s2row ${it.reverted ? "done" : ""}`}>
            <div className="s2main"><b>{whatChanged(it)}</b>
              <span className="dim small">{when(it.at_ms)} · {ago(it.at_ms)}{it.audit_seq ? <> · ledger entry {it.audit_seq} {proven[it.audit_seq] === true ? <span className="s2ok" title="Proven in this browser by the kernel">✓ proven</span> : proven[it.audit_seq] === false ? <span className="s2bad">✗ proof failed</span> : null}</> : null}</span></div>
            <div className="s2act">
              {it.reverted ? <span className="s2tag">undone</span> : it.hash_only ? <span className="s2tag" title="Only a fingerprint of the photo is kept; upload it again">photo: re-upload to change</span> :
                it.can_undo ? <Button variant="ghost" size="mini" disabled={busy} onClick={() => { setUndo(it); setReason(`Undo: ${label(it.key)} change`); setMsg(null); }}>Undo</Button> : <span className="s2tag">current</span>}
            </div>
          </li>))}
      </ul>
      {more && <Button variant="ghost" disabled={busy} onClick={() => void load(more)}>Show older versions</Button>}
      {undo && <div className="s2undo" role="dialog" aria-label="Confirm undo">
        <p><b>Undo this change?</b> {whatChanged(undo)}. The setting goes back to {undo.was_default ? "its default" : fmtVal(undo.key, undo.from)} and the undo itself is recorded in the ledger.</p>
        <label className="s2sel">Reason (kept in the audit record)<input value={reason} maxLength={300} onChange={(e) => setReason(e.target.value)} /></label>
        <div className="s2btns"><Button disabled={busy || reason.trim().length < 8} onClick={() => void doUndo()}>Undo now</Button><Button variant="ghost" onClick={() => setUndo(null)}>Keep as is</Button></div>
      </div>}
      {msg && <div className={msg.ok ? "toast ok" : "toast bad"} role="status">{msg.t}</div>}
      {err && <div className="toast bad" role="alert">{err}</div>}
    </section>
  );
}

type Drift = { score: number; aligned: number; loose: number; risky: number; items: { key: string; label: string; state: "aligned" | "loose" | "risky"; current: unknown; recommended: unknown; why: string }[] };
type Sched = { id: string; key: string; label: string; to: unknown; apply_at_ms: number; rollback_minutes: number | null; state: string; reason: string; applied_ms: number | null; rollback_due_ms: number | null; can_cancel: boolean; can_confirm: boolean; note: string | null };
const STATE_TXT: Record<string, string> = { scheduled: "Waiting to apply", applied: "Applied", confirmed: "Kept", rolled_back: "Rolled back", cancelled: "Cancelled", superseded: "Overtaken by a newer change", failed: "Failed" };
const FORM_KEYS: [string, "bool" | "text"][] = [["appearance.graphics", "bool"], ["appearance.sidebar_slim", "bool"], ["personal.display_name", "text"]];
const ROLLBACKS: [string, number | null][] = [["Keep it (no rollback)", null], ["Roll back after 15 min", 15], ["Roll back after 1 hour", 60], ["Roll back after 4 hours", 240], ["Roll back after 24 hours", 1440]];

export function DriftSchedule() {
  const [drift, setDrift] = useState<Drift | null>(null), [sched, setSched] = useState<Sched[]>([]), [avail, setAvail] = useState(true), [err, setErr] = useState<string | null>(null), [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; t: string } | null>(null);
  const [k, setK] = useState(FORM_KEYS[0][0]), [bv, setBv] = useState(false), [tv, setTv] = useState(""), [when_, setWhen] = useState(""), [rb, setRb] = useState<number | null>(15), [why, setWhy] = useState("");
  const kind = FORM_KEYS.find((x) => x[0] === k)?.[1] ?? "bool";
  const load = useCallback(async () => {
    try {
      const [d, s] = await Promise.all([ask<Drift>("/founder/v1/settings/drift"), ask<Sched[]>("/founder/v1/settings/scheduled")]);
      if (!d.available || !s.available) { setAvail(false); return; }
      setAvail(true); setDrift(d.data ?? null); setSched(s.data ?? []);
    } catch (e) { setErr((e as Error).message); }
  }, []);
  useEffect(() => { void load(); const t = window.setInterval(() => void load(), 15000); return () => window.clearInterval(t); }, [load]);
  const act = async (path: string, body: unknown, ok: string) => {
    setBusy(true); setMsg(null);
    try { const r = await post(path, body); if (r.status === 200) { setMsg({ ok: true, t: ok }); await load(); } else setMsg({ ok: false, t: r.body?.error || `Not done (HTTP ${r.status})` }); }
    catch (e) { setMsg({ ok: false, t: (e as Error).message }); }
    setBusy(false);
  };
  const create = () => {
    const ms = Date.parse(when_); const value = kind === "bool" ? bv : tv.trim();
    void act("/founder/v1/settings/schedule", { key: k, value, apply_at_ms: ms, rollback_minutes: rb, reason: why.trim() }, "Scheduled. It will apply at the chosen time.");
  };
  const worst = useMemo(() => (drift ? drift.items.filter((i) => i.state !== "aligned") : []), [drift]);
  if (!avail) return NOSQL;
  return (
    <>
      <section className="panel s2">
        <div className="panelhead"><h2>How far you are from the safe defaults</h2><p className="dim">Measured now against the recommended baseline, including your ledger seal policy and how many entries are unsealed.</p></div>
        {drift && <>
          <div className="s2score"><div className="s2big" aria-label={`Score ${drift.score} out of 100`}><b>{drift.score}</b><span>/100</span></div>
            <div className="s2cnt"><span><b>{drift.aligned}</b> aligned</span><span><b>{drift.loose}</b> looser</span><span><b>{drift.risky}</b> risky</span></div></div>
          {worst.length > 0 && <ul className="s2list">{worst.map((i) => <li key={i.key} className="s2row"><div className="s2main"><b>{i.label}</b><span className="dim small">{i.why}</span></div><span className={`s2tag ${i.state}`}>{i.state === "risky" ? "Risky" : "Looser than baseline"}</span></li>)}</ul>}
          {worst.length === 0 && <p className="dim">All {drift.aligned} measured items match the baseline.</p>}
        </>}
      </section>
      <section className="panel s2">
        <div className="panelhead"><h2>Apply later, roll back automatically</h2><p className="dim">A change lands at the time you choose. With a rollback timer it undoes itself unless you keep it — and it never overwrites something you changed in the meantime.</p></div>
        <div className="s2form">
          <label className="s2sel">Setting<select value={k} onChange={(e) => setK(e.target.value)}>{FORM_KEYS.map(([key]) => <option key={key} value={key}>{label(key)}</option>)}</select></label>
          {kind === "bool" ? <label className="s2sel">New value<span className="s2sw"><Switch checked={bv} onCheckedChange={setBv} aria-label="New value" /><em>{bv ? "On" : "Off"}</em></span></label>
            : <label className="s2sel">New value<input value={tv} maxLength={60} onChange={(e) => setTv(e.target.value)} placeholder="2–60 characters" /></label>}
          <label className="s2sel">Apply at<input type="datetime-local" value={when_} onChange={(e) => setWhen(e.target.value)} /></label>
          <label className="s2sel">Safety<select value={rb ?? ""} onChange={(e) => setRb(e.target.value ? Number(e.target.value) : null)}>{ROLLBACKS.map(([t, v]) => <option key={t} value={v ?? ""}>{t}</option>)}</select></label>
          <label className="s2sel wide">Reason (kept in the audit record)<input value={why} maxLength={300} onChange={(e) => setWhy(e.target.value)} placeholder="Why this change, in a few words" /></label>
          <Button disabled={busy || !Number.isFinite(Date.parse(when_)) || why.trim().length < 8 || (kind === "text" && tv.trim().length < 2)} onClick={create}>Schedule</Button>
        </div>
        <ul className="s2list">
          {sched.map((s) => (
            <li key={s.id} className="s2row">
              <div className="s2main"><b>{s.label}: {fmtVal(s.key, s.to)}</b>
                <span className="dim small">{STATE_TXT[s.state] ?? s.state} · {s.state === "scheduled" ? `applies ${when(s.apply_at_ms)}` : s.applied_ms ? `applied ${when(s.applied_ms)}` : `planned ${when(s.apply_at_ms)}`}
                  {s.state === "applied" && s.rollback_due_ms ? ` · rolls back ${when(s.rollback_due_ms)} unless you keep it` : ""}{s.note ? ` · ${s.note}` : ""}</span></div>
              <div className="s2act">
                {s.can_confirm && <Button size="mini" disabled={busy} onClick={() => void act("/founder/v1/settings/schedule/confirm", { id: s.id, reason: "Keep this scheduled change" }, "Kept. The rollback timer is cancelled.")}>Keep it</Button>}
                {s.can_cancel && <Button variant="ghost" size="mini" disabled={busy} onClick={() => void act("/founder/v1/settings/schedule/cancel", { id: s.id, reason: "Cancel this scheduled change" }, "Cancelled.")}>Cancel</Button>}
                {!s.can_confirm && !s.can_cancel && <span className="s2tag">{STATE_TXT[s.state] ?? s.state}</span>}
              </div>
            </li>))}
        </ul>
        <div className="s2count dim">{sched.length} scheduled change{sched.length === 1 ? "" : "s"} on record</div>
        {msg && <div className={msg.ok ? "toast ok" : "toast bad"} role="status">{msg.t}</div>}
        {err && <div className="toast bad" role="alert">{err}</div>}
      </section>
    </>
  );
}

type Info = { label: string; plain: string; example: string; tradeoff: string | null; recommended: unknown; why_recommended: string | null };
type Blast = { severity: string; reversible: boolean; devices_affected: number; surfaces: string[]; pending_schedules: number; versions: number; last_change_ms: number | null };

/** The trio under every setting row, like the user app: Explain · Blast radius · History. */
export function RowTools({ k, onHistory }: { k: string; onHistory: (key: string) => void }): ReactNode {
  const [open, setOpen] = useState<null | "explain" | "blast">(null), [info, setInfo] = useState<Info | null>(null), [blast, setBlast] = useState<Blast | null>(null), [err, setErr] = useState<string | null>(null);
  const toggle = async (w: "explain" | "blast") => {
    if (open === w) { setOpen(null); return; }
    setOpen(w); setErr(null);
    try {
      if (w === "explain" && !info) { const r = await ask<Info>(`/founder/v1/settings/explain?key=${k}`); if (r.available && r.data) setInfo(r.data); else setErr("The explanation needs the E113 SQL step on the server."); }
      if (w === "blast" && !blast) { const r = await ask<Blast>(`/founder/v1/settings/blast?key=${k}`); if (r.available && r.data) setBlast(r.data); else setErr("The blast radius needs the E113 SQL step on the server."); }
    } catch (e) { setErr((e as Error).message); }
  };
  return (
    <div className="s2tools">
      <div className="s2tbtn"><button type="button" aria-expanded={open === "explain"} onClick={() => void toggle("explain")}><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 8v.01" /></svg>Explain</button><button type="button" aria-expanded={open === "blast"} onClick={() => void toggle("blast")}><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="2.5" /><circle cx="12" cy="12" r="6" /><circle cx="12" cy="12" r="9.5" /></svg>Blast radius</button><button type="button" onClick={() => onHistory(k)}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12a9 9 0 1 0 3-6.7" /><path d="M3 4v5h5M12 7v5l3 2" /></svg>History</button></div>
      {open === "explain" && info && <div className="s2pop"><p>{info.plain}</p><p className="dim small">Example: {info.example}</p>{info.tradeoff && <p className="dim small">Trade-off: {info.tradeoff}</p>}{info.why_recommended && <p className="dim small">Recommended: {info.why_recommended}</p>}</div>}
      {open === "blast" && blast && <div className="s2pop"><p>Affects {blast.devices_affected} approved device{blast.devices_affected === 1 ? "" : "s"}: {blast.surfaces.join(", ")}.</p>
        <p className="dim small">{blast.reversible ? "Reversible from the Time machine" : "Not reversible from history"} · severity {blast.severity} · {blast.versions} version{blast.versions === 1 ? "" : "s"} recorded{blast.pending_schedules ? ` · ${blast.pending_schedules} scheduled` : ""}{blast.last_change_ms ? ` · last change ${ago(blast.last_change_ms)}` : ""}</p></div>}
      {err && <div className="toast bad" role="alert">{err}</div>}
    </div>
  );
}
