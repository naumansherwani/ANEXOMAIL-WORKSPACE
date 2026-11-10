import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { get, post, signOut } from "./api";
import { PolicyEditor } from "./PolicyEditor";
import { KERNEL } from "./kernel.pin";
import {
  ago, alerts, browserText, canClose, closeWarning, countryName, flag, freshness, hasAlert, INTEGRITY_TEXT, KEY_TEXT, kindInfo, methodText, othersLive, parseBoard, parseLedger, pathShort, reasonText, remaining, revokeText, ring, rowText, span, visible,
  type Board, type Filter, type Policy, type Ring, type Row, type Sess,
} from "./sessions_pure";

// D3 (11 Nov 2026): the Devices & Sessions screen. Plan: docs/claude/G-MIX-D3-PLAN-11NOV.md. Data ONLY from the signed doors
// /founder/v1/sessions/{board,ledger,revoke,revoke-others} (verified by the WASM kernel inside api.get/post). One build, container queries for 390 / 820 / 1200+.
const EVERY = 15000, PAGE = 50, DOM_CAP = 400;
const STATE_ICON = { good: "✓", warn: "!", bad: "✕", unknown: "?" } as const;
const STATE_WORD = { good: "Good", warn: "Check", bad: "Problem", unknown: "Unknown" } as const;

function useNow(everyMs = 1000) { const [n, setN] = useState(() => Date.now()); useEffect(() => { const t = window.setInterval(() => setN(Date.now()), everyMs); return () => window.clearInterval(t); }, [everyMs]); return n; }

/** Four real facts about this session as four arcs; the centre says one honest word. Icon + word + colour, never colour alone. */
function TrustRing({ r }: { r: Ring }) {
  const C = 2 * Math.PI * 44, len = C / 4 - 7;
  return (
    <div className="dv-ringbox">
      <svg className={`dv-ring v-${r.verdict}`} viewBox="0 0 120 120" role="img" aria-label={`Session trust: ${r.word}. ${r.arcs.map((a) => `${a.label}: ${STATE_WORD[a.state]}`).join(", ")}`}>
        <circle cx="60" cy="60" r="44" className="trk" />
        {r.arcs.map((a, i) => <circle key={a.id} cx="60" cy="60" r="44" className={`arc s-${a.state}`} strokeDasharray={`${len} ${C - len}`} transform={`rotate(${-90 + i * 90 + 3.5} 60 60)`} />)}
        {(() => { const w = r.word.split(" "); const two = r.word.length > 9 && w.length > 1; return two
          ? <><text x="60" y="53" textAnchor="middle" className="rw">{w[0]}</text><text x="60" y="67" textAnchor="middle" className="rw">{w.slice(1).join(" ")}</text><text x="60" y="81" textAnchor="middle" className="rs">this session</text></>
          : <><text x="60" y="58" textAnchor="middle" className="rw">{r.word}</text><text x="60" y="74" textAnchor="middle" className="rs">this session</text></>; })()}
      </svg>
      <ul className="dv-legend">
        {r.arcs.map((a) => <li key={a.id} className={`s-${a.state}`}><i aria-hidden="true">{STATE_ICON[a.state]}</i><span><b>{a.label}</b><em>{STATE_WORD[a.state]}</em><small>{a.detail}</small></span></li>)}
      </ul>
    </div>
  );
}

function PolicyCard({ p, limits, reload }: { p: Policy | null; limits: string[]; reload: () => void }) {
  const [editing, setEditing] = useState(false);
  if (!p) return <section className="dx-card dv-card"><h2 className="dv-h">Session policy</h2><p className="dim">The policy is not available.</p></section>;
  const geo = p.geoMode === "enforce" ? "Enforced" : p.geoMode === "observe" ? "Observe only" : p.geoMode === "off" ? "Off" : "Unknown";
  return (
    <section className="dx-card dv-card" aria-label="Session policy">
      <h2 className="dv-h">Session policy</h2>
      <dl className="dv-dl">
        <div><dt>Location lock</dt><dd><b>{geo}</b>{p.countries.length > 0 && <span> · {p.countries.map((c) => `${flag(c)} ${countryName(c)}`).join(", ")}</span>}</dd></div>
        <div><dt>Idle limit</dt><dd>{span(p.idleS)}</dd></div>
        <div><dt>Absolute limit</dt><dd>{span(p.absoluteS)}</dd></div>
        <div><dt>Live sessions</dt><dd>at most {p.maxLive}</dd></div>
        <div><dt>Shared-session alarm</dt><dd>{p.flapLimit} network changes in 10 min · {p.flapAction === "revoke" ? "closes the session" : "alert only"}</dd></div>
        <div><dt>Browser mismatch</dt><dd>{p.spoofAction === "block" ? "Blocked" : "Alert only"}</dd></div>
      </dl>
      <p className="src">Changing these needs a fresh passkey touch that signs the exact change. {limits.includes("vpn_inside_an_allowed_country_passes_the_location_lock") ? "Honest limit: a VPN inside an allowed country passes the location lock." : ""}</p>
      {editing ? <PolicyEditor p={p} onDone={() => { setEditing(false); reload(); }} /> : <div className="dv-actions"><button type="button" className="dv-btn ghost" onClick={() => setEditing(true)}>Change policy…</button></div>}
    </section>
  );
}

function SessionRow({ s, pol, now, busy, confirm, setConfirm, close }: { s: Sess; pol: Policy | null; now: number; busy: string | null; confirm: string | null; setConfirm: (v: string | null) => void; close: (s: Sess) => void }) {
  const mismatch = s.claimed !== "unknown" && s.proven !== "unknown" && s.claimed !== s.proven;
  const left = remaining(s, pol, now), asking = confirm === s.sidHash, mine = busy === s.sidHash;
  return (
    <li className={`dv-row ${s.live ? "live" : "closed"} ${s.current ? "me" : ""} sp-${s.spoof.level}`} aria-label={`${browserText(s.claimed)} session ${s.live ? "live" : "closed"}${s.current ? ", this device" : ""}`}>
      <div className="dv-main">
        <div className="dv-title">
          <b>{browserText(s.claimed)}</b>
          {s.current && <span className="dv-tag me">This device</span>}
          <span className={`dv-tag ${s.live ? "ok" : "off"}`}>{s.live ? "Live" : "Closed"}</span>
          <span className="dv-tag">{methodText(s.method)}</span>
        </div>
        {mismatch && <p className="dv-warn" role="note">⚠ Claims {browserText(s.claimed)} but proves {browserText(s.proven)}</p>}
        <p className="dv-facts">
          <span title={`Path measured by the server: ${s.pathBadge}`}>{pathShort(s.protocol)}</span>
          <span title={KEY_TEXT[s.keySource]}>{s.keySource === "none" ? "No key" : s.keySource === "unknown" ? "Key ?" : `Key ${s.keyFp.slice(0, 8) || "set"}`}</span>
          <span title={INTEGRITY_TEXT[s.integrity.state]}>{INTEGRITY_TEXT[s.integrity.state]}</span>
          <span>{s.country ? `${flag(s.country)} ${countryName(s.country)}` : "Country unknown"}</span>
          <span title="App build this browser reports">Build {s.kernel}</span>
          <span className="mono" title="Short session id (never the full id)">{s.sid}</span>
        </p>
        {s.spoof.level !== "ok" && (
          <div className="dv-spoof" role="note"><span className="meter" aria-hidden="true"><i style={{ width: `${s.spoof.score}%` }} /></span><b>{s.spoof.level === "spoof" ? "Identity mismatch" : "Suspicious"} · {s.spoof.score}/100</b>
            <ul>{s.spoof.reasons.map((r) => <li key={r}>{reasonText(r)}</li>)}</ul></div>
        )}
        {(s.netFlips >= 2 || s.failStreak > 0) && <p className="dv-warn" role="note">{s.netFlips >= 2 ? `${s.netFlips} network changes recently. ` : ""}{s.failStreak > 0 ? `${s.failStreak} failed request signature${s.failStreak === 1 ? "" : "s"} in a row.` : ""}</p>}
        <p className="dv-times">
          <span title={s.createdAt ? new Date(s.createdAt).toLocaleString() : ""}>Opened {ago(s.createdAt, now)}</span>
          <span title={s.lastSeenAt ? new Date(s.lastSeenAt).toLocaleString() : ""}>Last seen {ago(s.lastSeenAt, now)}</span>
          {left && <span>Ends in {span(left.secs)} ({left.why === "idle" ? "idle limit" : "absolute limit"})</span>}
          {!s.live && s.revokedAt && <span title={new Date(s.revokedAt).toLocaleString()}>{revokeText(s.revokeReason)} {ago(s.revokedAt, now)}</span>}
        </p>
      </div>
      {canClose(s) && (
        <div className="dv-act">
          {!asking
            ? <button type="button" className="dv-btn" disabled={busy !== null} onClick={() => setConfirm(s.sidHash)}>{s.current ? "Sign out here" : "Close session"}</button>
            : <div className="dv-confirm" role="group" aria-label="Confirm">
                <p>{closeWarning(s)}</p>
                <button type="button" className="dv-btn danger" disabled={busy !== null} onClick={() => close(s)} autoFocus>{mine ? "Closing…" : "Confirm close"}</button>
                <button type="button" className="dv-btn ghost" disabled={busy !== null} onClick={() => setConfirm(null)}>Cancel</button>
              </div>}
        </div>
      )}
    </li>
  );
}

export function DevicesView() {
  const [verified, setVerified] = useState(false), [board, setBoard] = useState<Board | null>(null), [down, setDown] = useState(false), [err, setErr] = useState(""), [loadedAt, setLoadedAt] = useState<number | null>(null), [loading, setLoading] = useState(true);
  const [rows, setRows] = useState<Row[]>([]), [more, setMore] = useState(true), [ledgerErr, setLedgerErr] = useState(""), [kind, setKind] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>("all"), [q, setQ] = useState(""), [confirm, setConfirm] = useState<string | null>(null), [confirmOthers, setConfirmOthers] = useState(false);
  const [shown, setShown] = useState(10), [busy, setBusy] = useState<string | null>(null), [msg, setMsg] = useState<{ ok: boolean; t: string } | null>(null);
  const now = useNow(), alive = useRef(true);
  useEffect(() => () => { alive.current = false; }, []);

  const loadBoard = useCallback(async () => {
    try {
      const e = await get("/founder/v1/sessions/board");
      if (!alive.current) return;
      const b = (e.data as { available?: boolean })?.available === false ? null : parseBoard(e.data);
      setVerified(e.verified === true);
      if (!b) { setDown(true); setBoard(null); } else { setDown(false); setBoard(b); setLoadedAt(Date.now()); }
      setErr("");
    } catch (x) { if (alive.current) setErr((x as Error).message || "The server did not answer"); } // keep the last good data, mark it stale
    if (alive.current) setLoading(false);
  }, []);
  const loadLedger = useCallback(async (before?: number) => {
    try {
      const e = await get(`/founder/v1/sessions/ledger?limit=${PAGE}${before ? `&before=${before}` : ""}`);
      if (!alive.current) return;
      const got = parseLedger(e.data);
      setRows((old) => (before ? [...old, ...got.filter((r) => !old.some((o) => o.id === r.id))] : got).slice(0, DOM_CAP));
      setMore(got.length >= PAGE); setLedgerErr("");
    } catch (x) { if (alive.current) setLedgerErr((x as Error).message || "The ledger did not answer"); }
  }, []);

  // refresh every 15 s, paused while the tab is hidden, and once at once when it comes back
  useEffect(() => {
    void loadBoard(); void loadLedger();
    const tick = () => { if (document.visibilityState === "visible") { void loadBoard(); void loadLedger(); } };
    const t = window.setInterval(tick, EVERY);
    document.addEventListener("visibilitychange", tick);
    return () => { window.clearInterval(t); document.removeEventListener("visibilitychange", tick); };
  }, [loadBoard, loadLedger]);

  async function act(key: string, path: string, body: unknown, okText: (d: { revoked?: number }) => string, after?: () => void) {
    if (busy) return;
    setBusy(key); setMsg(null);
    try {
      const r = await post(path, body);
      const d = (r.body as { ok?: boolean; data?: { revoked?: number } } | null) ?? null;
      if (r.status === 200 && d?.ok === true) { setMsg({ ok: true, t: okText(d.data ?? {}) }); setConfirm(null); setConfirmOthers(false); if (after) after(); else await Promise.all([loadBoard(), loadLedger()]); }
      else setMsg({ ok: false, t: r.status === 502 ? "Devices & Sessions is not answering on the server (run the E155/E156 SQL step)." : (r.body as { error?: string } | null)?.error || `Not done (HTTP ${r.status}). Nothing was changed.` });
    } catch (x) { setMsg({ ok: false, t: (x as Error).message || "The server did not answer. Nothing was changed." }); }
    if (alive.current) setBusy(null);
  }
  const close = (s: Sess) => act(s.sidHash, "/founder/v1/sessions/revoke", { sid_hash: s.sidHash }, () => (s.current ? "Signed out." : "Session closed. It stops working on its very next request."), s.current ? () => signOut() : undefined);
  const closeOthers = () => act("others", "/founder/v1/sessions/revoke-others", {}, (d) => `Closed ${d.revoked ?? 0} other session${d.revoked === 1 ? "" : "s"}.`);

  const cur = board?.sessions.find((s) => s.current) ?? null;
  const r = useMemo(() => ring(cur, board), [cur, board]);
  const list = useMemo(() => (board ? visible(board.sessions, filter, q) : []), [board, filter, q]);
  const strip = useMemo(() => alerts(rows, now), [rows, now]);
  const [routine, setRoutine] = useState(false);
  const hiddenRoutine = kind ? 0 : rows.filter((x) => x.kind === "seen").length;
  const filtered = kind ? rows.filter((x) => x.kind === kind) : routine ? rows : rows.filter((x) => x.kind !== "seen"), shownRows = filtered.slice(0, shown);
  const fresh = freshness(loadedAt, now, EVERY);
  const others = othersLive(board);

  if (loading) return <div className="dx dv" aria-busy="true"><div className="dx-card dv-card dv-skel" /><div className="dx-card dv-card dv-skel tall" /></div>;
  if (down || !board) return (
    <div className="dx dv"><section className="dx-card dv-card" role="alert"><h2 className="dv-h">Devices &amp; sessions</h2>
      <p className="err">Devices &amp; Sessions is not answering{err ? `: ${err}` : "."}</p>
      <p className="dim">The screen shows nothing rather than something invented. Run the E155 and E156 SQL step (sql-run.sh) on the server if it was not applied, then try again.</p>
      <button type="button" className="dv-btn" onClick={() => { setLoading(true); void loadBoard(); }}>Try again</button></section></div>
  );
  return (
    <div className="dx dv">
      <section className="dx-card dv-card dv-hero" aria-label="This session">
        <div className="dv-herohead"><div><h2 className="dv-h">Devices &amp; sessions</h2>
          <p className="dim">Every sign-in is a session. Close any you do not recognise; it stops on its very next request. {board.live} live{board.liveWithAlert > 0 ? `, ${board.liveWithAlert} with an alert` : ""}.</p></div>
          <div className="dv-prov"><p className={`dv-fresh ${fresh}`} role="status" aria-live="polite">{fresh === "fresh" ? `Updated ${loadedAt ? new Date(loadedAt).toLocaleTimeString() : ""} · refreshes every 15 s` : `Stale: last update ${loadedAt ? new Date(loadedAt).toLocaleTimeString() : "never"}${err ? ` (${err})` : ""}`}</p>
          {verified && <span className="dv-verified" title={`Every figure on this screen was signed by the server and checked inside your browser by the security kernel (build ${KERNEL.version}). A wrong signature hides the answer instead of showing it.`}><i aria-hidden="true">✓</i> Verified in this browser · kernel {KERNEL.version}</span>}</div></div>
        <TrustRing r={r} />
      </section>

      {strip.length > 0 && (
        <section className="dx-card dv-card dv-alerts" aria-label="Alerts in the last 24 hours">
          <h2 className="dv-h">Last 24 hours</h2>
          <div className="dv-chips">{strip.map((a) => <button key={a.kind} type="button" className={`dv-chip ${kindInfo(a.kind).tone} ${kind === a.kind ? "on" : ""}`} aria-pressed={kind === a.kind} onClick={() => setKind(kind === a.kind ? null : a.kind)}><i aria-hidden="true">{kindInfo(a.kind).icon}</i>{kindInfo(a.kind).text.split(":")[0]} ×{a.count}</button>)}</div>
        </section>
      )}

      <section className="dx-card dv-card" aria-label="Sessions">
        <div className="dv-bar">
          <div className="dv-filters" role="group" aria-label="Filter sessions">
            {(["all", "live", "closed", "alert"] as Filter[]).map((f) => <button key={f} type="button" className={`dv-chip ${filter === f ? "on" : ""}`} aria-pressed={filter === f} onClick={() => setFilter(f)}>{{ all: "All", live: "Live", closed: "Closed", alert: "With alert" }[f]}{f === "alert" ? ` (${board.sessions.filter(hasAlert).length})` : ""}</button>)}
          </div>
          <input className="dv-search" type="search" value={q} maxLength={40} placeholder="Search browser, country, build…" aria-label="Search sessions" onChange={(e) => setQ(e.target.value)} />
        </div>
        {msg && <div className={msg.ok ? "note dv-msg ok" : "err banner dv-msg"} role="status" aria-live="assertive">{msg.t}</div>}
        {list.length === 0
          ? <p className="dim dv-empty">{board.sessions.length === 0 ? "No sessions are recorded yet. Sign out and in once and this device appears here." : "No session matches this filter."}</p>
          : <ul className="dv-list">{list.map((s) => <SessionRow key={s.sidHash} s={s} pol={board.policy} now={now} busy={busy} confirm={confirm} setConfirm={setConfirm} close={close} />)}</ul>}
        <div className="dv-foot">
          {!confirmOthers
            ? <button type="button" className="dv-btn soft" disabled={busy !== null || others === 0} onClick={() => setConfirmOthers(true)}>Sign out everywhere else{others > 0 ? ` (${others})` : ""}</button>
            : <div className="dv-confirm" role="group" aria-label="Confirm sign out everywhere else"><p>Close {others} other live session{others === 1 ? "" : "s"}? This browser stays signed in.</p>
                <button type="button" className="dv-btn danger" disabled={busy !== null} onClick={closeOthers} autoFocus>{busy === "others" ? "Closing…" : "Confirm"}</button>
                <button type="button" className="dv-btn ghost" disabled={busy !== null} onClick={() => setConfirmOthers(false)}>Cancel</button></div>}
          {others === 0 && <span className="dim small">No other live sessions.</span>}
        </div>
      </section>

      <PolicyCard p={board.policy} limits={board.limits} reload={() => void loadBoard()} />

      <section className="dx-card dv-card" aria-label="Session ledger">
        <div className="dv-ledhead"><h2 className="dv-h">Ledger</h2>
          <p className="dv-proof">
            <span className={`dv-badge ${board.chainOk === true ? "good" : board.chainOk === false ? "bad" : "unknown"}`}><i aria-hidden="true">{board.chainOk === true ? "✓" : board.chainOk === false ? "✕" : "?"}</i>{board.chainOk === true ? "Chain verified" : board.chainOk === false ? `Chain broken${board.chainBrokenAt != null ? ` at row ${board.chainBrokenAt}` : ""}` : "Chain not checked"}</span>
            <span className={`dv-badge ${board.anchorOk === true ? "good" : board.anchorOk === false ? "bad" : "unknown"}`}><i aria-hidden="true">{board.anchorOk === true ? "✓" : board.anchorOk === false ? "✕" : "?"}</i>{board.anchorOk === true ? "Anchor matches the audit chain" : board.anchorOk === false ? `Anchor mismatch${board.anchorWhy ? ` (${board.anchorWhy})` : ""}` : "Anchor not checked"}</span>
          </p></div>
        <p className="dim small dv-ledsub">Every event is hash-chained and append-only. {kind ? <>Showing only “{kindInfo(kind).text}”. <button type="button" className="dv-link" onClick={() => setKind(null)}>Show all</button></> : <>Newest first. {routine ? <button type="button" className="dv-link" onClick={() => setRoutine(false)}>Hide routine check-ins</button> : hiddenRoutine > 0 && <button type="button" className="dv-link" onClick={() => setRoutine(true)}>Show {hiddenRoutine} routine check-ins</button>}</>}</p>
        {ledgerErr && <p className="err" role="alert">{ledgerErr}</p>}
        {filtered.length === 0 && !ledgerErr ? <p className="dim dv-empty">{hiddenRoutine > 0 ? "Nothing important yet: only routine check-ins so far." : "No events yet."}</p>
          : <ol className="dv-tl">{shownRows.map((x) => { const k = kindInfo(x.kind); return (
              <li key={x.id} className={`tone-${k.tone}`}><i aria-hidden="true">{k.icon}</i>
                <div><p>{rowText(x)}</p>
                  <time dateTime={x.atMs ? new Date(x.atMs).toISOString() : undefined} title={x.atMs ? new Date(x.atMs).toLocaleString() : ""}>{ago(x.atMs, now)}</time>
                  <span className="mono"> · row {x.id}{x.sid ? ` · session ${x.sid}` : ""}{x.kernel !== "unknown" ? ` · build ${x.kernel}` : ""}</span></div></li>); })}</ol>}
        {filtered.length > shown && <button type="button" className="dv-btn ghost" onClick={() => setShown((n) => n + 20)}>Show {Math.min(20, filtered.length - shown)} more ({filtered.length - shown} left)</button>}
        {filtered.length <= shown && more && !kind && rows.length < DOM_CAP && rows.length > 0 && <button type="button" className="dv-btn ghost" onClick={() => void loadLedger(rows[rows.length - 1].id)}>Load older events</button>}
      </section>
    </div>
  );
}
