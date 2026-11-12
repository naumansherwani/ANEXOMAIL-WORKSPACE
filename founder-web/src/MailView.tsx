import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import * as Popover from "@radix-ui/react-popover";
import { LogoMark } from "./Brand";
import * as api from "./mail_api";
import { FOLDERS, ago, compact, fmtSize, glide, isGatedView, keyCmd, merge, pill, proofChip, hue, initials, matchRow, rowText, touchAction, verdicts, when, folderLabel, type Box, type Counts, type Lane, type Proof, type Row } from "./mail_pure";
import "./mail.css";

// Q1c — the founder Mail page. Everything on it is read from the Rust mail doors (E167-E169): lanes, folder counts, rows, the ledger proof, the live channel.
// Nothing is made up: a number the server did not give is shown as "—", a check that failed is shown as failed (hollow dot), a sealed row is opened by the server only
// after the gate, and Quarantine / Vault need a passkey touch every single time.

const IC: Record<string, string> = {
  inbox: "M3 13h5l1.5 3h5L16 13h5M3 13l2.5-7h13L21 13v6H3z", sent: "M21 3L3 11l7 3 3 7zM10 14L21 3", draft: "M4 20h4l11-11-4-4L4 16zM13 7l4 4", outbox: "M12 3v12M7 8l5-5 5 5M4 21h16",
  archive: "M3 5h18v4H3zM5 9v10h14V9M10 13h4", snooze: "M12 7v5l3 2M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z", spam: "M12 3l9 16H3zM12 10v4M12 17h.01",
  shield: "M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6zM9 12l2 2 4-4", vault: "M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 12h3", trash: "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
  lock: "M7 11V8a5 5 0 0 1 10 0v3M5 11h14v10H5z", star: "M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.5 6.7 19.4l1.2-6L3.4 9.3l6-.7z", back: "M15 6l-6 6 6 6", pin: "M9 4h6l-1 6 3 3H7l3-3zM12 13v7", clip: "M20 11l-8 8a5 5 0 0 1-7-7l9-9a3.5 3.5 0 0 1 5 5l-9 9a2 2 0 0 1-3-3l8-8",
  unread: "M3 6h18v12H3zM3 6l9 7 9-7", check: "M5 12l4 4 10-10",
};
const I = ({ k, s = 18 }: { k: string; s?: number }) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={IC[k] ?? IC.inbox} /></svg>;

/** A number that glides to its new value (no spinner, no jump). Respects reduced motion. */
function Num({ n, off }: { n: number | null | undefined; off?: boolean }) {
  const [shown, setShown] = useState(n ?? 0), from = useRef(n ?? 0), raf = useRef(0);
  useEffect(() => {
    if (n == null) return; if (off) { setShown(n); from.current = n; return; }
    const a = from.current, t0 = performance.now(), D = 600;
    const step = (t: number) => { const p = Math.min(1, (t - t0) / D); setShown(glide(a, n, p)); if (p < 1) raf.current = requestAnimationFrame(step); else from.current = n; };
    raf.current = requestAnimationFrame(step); return () => cancelAnimationFrame(raf.current);
  }, [n, off]);
  return <>{n == null ? "—" : compact(shown)}</>;
}

function PillBar({ box, bound, h3 }: { box: Box | null; bound: boolean | null; h3: string }) {
  const p = pill(h3, bound, box);
  const seg = (ok: boolean, t: string) => <span className={`mp-seg ${ok ? "ok" : "no"}`}><i aria-hidden="true" />{t}</span>;
  return <div className="mp-pill" role="status" aria-label={`${p.quic.text}, ${p.dbsc.text}, ${p.seal.text}`}>{seg(p.quic.ok, p.quic.text)}<b aria-hidden="true">·</b>{seg(p.dbsc.ok, p.dbsc.text)}<b aria-hidden="true">·</b>{seg(p.seal.ok, p.seal.text)}</div>;
}

const LANE_TO_VIEW: Record<string, string> = { "mail-in": "inbox", "mail-quarantine": "quarantine", "mail-out": "sent", "mail-failed": "outbox", "mail-queued": "outbox" };
function LaneRow({ lanes, go, reduce }: { lanes: Lane[] | null; go: (v: string) => void; reduce: boolean }) {
  if (!lanes) return <div className="ml-row" aria-label="Mail lanes"><span className="dim small">Lanes appear when the mail SQL (E168) answers.</span></div>;
  return (
    <ul className="ml-row" aria-label="Mail lanes, last 24 hours">
      {lanes.map((l) => {
        const v = LANE_TO_VIEW[l.lane];
        const body = <><span className={`ml-dot ${l.tone}`} aria-hidden="true" /><span className="ml-n"><Num n={l.count} off={reduce} /></span><span className="ml-l">{l.label}</span><span className="ml-t">{l.last_ms ? ago(l.last_ms) : ""}</span></>;
        return <li key={l.lane}>{v ? <button type="button" className="ml-c" onClick={() => go(v)} title={`Open ${folderLabel(v)}`}>{body}</button> : <div className="ml-c">{body}</div>}</li>;
      })}
    </ul>
  );
}

function Rail({ view, set, counts, pinned, setPinned }: { view: string; set: (v: string) => void; counts: Counts | null; pinned: boolean; setPinned: (b: boolean) => void }) {
  return (
    <nav className={`mr ${pinned ? "pin" : ""}`} aria-label="Mail folders">
      {FOLDERS.map((f) => {
        const c = counts?.[f.key];
        return (
          <button key={f.key} type="button" className={`mr-b ${view === f.key ? "on" : ""}`} onClick={() => set(f.key)} aria-current={view === f.key ? "page" : undefined} title={f.label}>
            <span className="mr-i"><I k={f.icon} /></span><span className="mr-l">{f.label}</span>
            {f.gated && <span className="mr-lock" title="Needs a key touch to open"><I k="lock" s={12} /></span>}
            <span className={`mr-c ${c?.unread ? "u" : ""}`}>{c ? <Num n={c.unread || c.total} /> : "—"}</span>
          </button>
        );
      })}
      <button type="button" className="mr-pin" onClick={() => setPinned(!pinned)} aria-pressed={pinned} title="Pin labels"><I k="pin" s={16} /><span className="mr-l">Pin labels</span></button>
    </nav>
  );
}

function ProofChip({ p, busy }: { p: Proof | null; busy: boolean }) {
  const c = proofChip(p);
  return (
    <Popover.Root>
      <Popover.Trigger asChild><button type="button" className={`mx-proof ${busy ? "busy" : c.state}`}><i aria-hidden="true" />{busy ? "Checking the ledger…" : c.text}</button></Popover.Trigger>
      <Popover.Portal><Popover.Content className="mx-pop" side="bottom" align="start" sideOffset={8} collisionPadding={12}>
        <b>{busy ? "Checking…" : c.text}</b>{!busy && c.detail.map((d, i) => <span key={i}>{d}</span>)}<Popover.Arrow className="mx-arrow" />
      </Popover.Content></Popover.Portal>
    </Popover.Root>
  );
}

export function MailView() {
  const reduce = !!useReducedMotion();
  const [boxes, setBoxes] = useState<Box[] | null>(null), [boxId, setBoxId] = useState(""), [conn, setConn] = useState<boolean | null>(null), [err, setErr] = useState("");
  const [view, setView] = useState("inbox"), [rows, setRows] = useState<Row[]>([]), [more, setMore] = useState<{ ts: string; id: string } | null>(null), [loading, setLoading] = useState(false);
  const [counts, setCounts] = useState<Counts | null>(null), [lanes, setLanes] = useState<Lane[] | null>(null), [ledgerHead, setLedgerHead] = useState<number | null>(null);
  const [sel, setSel] = useState<string | null>(null), [opened, setOpened] = useState<api.Opened | null>(null), [openErr, setOpenErr] = useState(""), [opening, setOpening] = useState(false);
  const [proof, setProof] = useState<Proof | null>(null), [proofBusy, setProofBusy] = useState(false), [chain, setChain] = useState<Proof | null>(null), [chainBusy, setChainBusy] = useState(false);
  const [bound, setBound] = useState<boolean | null>(null), [liveState, setLiveState] = useState<"live" | "reconnecting" | "off">("off"), [fresh, setFresh] = useState(0);
  const [pinned, setPinned] = useState(() => { try { return window.localStorage.getItem("mail.rail") === "1"; } catch { return false; } });
  const [q, setQ] = useState(""), [copied, setCopied] = useState(false);
  const pending = useRef<string | null>(null);
  const box = useMemo(() => boxes?.find((b) => b.id === boxId) ?? null, [boxes, boxId]);
  const h3 = useMemo(() => api.pageProtocol(), []);
  const viewRef = useRef(view); viewRef.current = view;

  useEffect(() => { try { window.localStorage.setItem("mail.rail", pinned ? "1" : "0"); } catch { /* optional */ } }, [pinned]);
  useEffect(() => { let on = true; (async () => {
    try { const b = await api.boxes(); if (!on) return; setConn(b.connected); setBoxes(b.boxes ?? []); if (b.boxes?.[0]) setBoxId(b.boxes[0].id); } catch (e) { if (on) { setConn(false); setErr((e as Error).message); } }
    try { const l = await api.lanes(); if (on && l) { setLanes(l.lanes); setLedgerHead(l.ledger_head); } } catch { /* lanes are optional */ }
    api.dbscBound().then((x) => on && setBound(x)).catch(() => {});
  })(); return () => { on = false; }; }, []);

  const loadList = useCallback(async (more?: { ts: string; id: string } | null) => {
    if (!boxId) return; setLoading(true);
    try { const l = await api.list(boxId, viewRef.current, more ?? undefined); if (l) { setRows((old) => (more ? merge(old, l.rows) : l.rows)); setMore(l.more ? l.next : null); setErr(""); } else setErr("The mail doors did not answer. Run the E167, E168 and E169 SQL steps."); }
    catch (e) { setErr((e as Error).message); } setLoading(false);
  }, [boxId]);
  const loadCounts = useCallback(async () => { if (!boxId) return; try { const c = await api.counts(boxId); if (c) setCounts(c); } catch { /* the live channel retries */ } }, [boxId]);
  useEffect(() => { setRows([]); setMore(null); setSel(null); setOpened(null); setOpenErr(""); void loadList(); }, [boxId, view, loadList]);
  useEffect(() => { void loadCounts(); }, [loadCounts]);

  // live channel (SSE now; the same frames ride WebTransport in Q3). Counts and lanes glide; an arrival refreshes the open list.
  useEffect(() => {
    if (!boxId) return;
    const stop = api.live(boxId, (m) => {
      if (m.data?.counts) setCounts(m.data.counts);
      if (m.data?.feed?.lanes) { setLanes(m.data.feed.lanes); setLedgerHead(m.data.feed.ledger_head ?? null); }
      if (m.event === "arrival") { setFresh((n) => n + (m.data?.new > 0 ? m.data.new : 1)); if (viewRef.current === "inbox") void loadList(); }
    }, (s) => setLiveState(s));
    return () => { stop(); setLiveState("off"); };
  }, [boxId, loadList]);

  const select = useCallback(async (r: Row) => {
    setSel(r.id); setOpened(null); setOpenErr(""); setProof(null); setOpening(true);
    const { r: a } = await api.open(boxId, r.id); setOpening(false);
    if ("opened" in a) { setOpened(a); setRows((old) => old.map((x) => (x.id === r.id ? { ...x, read: true } : x))); void loadCounts(); setProofBusy(true); api.proof(boxId, r.id).then(setProof).catch(() => setProof(null)).finally(() => setProofBusy(false)); }
    else if ("needs_touch" in a) setOpenErr("A key touch is needed to open this.");
    else if ("broken" in a) setOpenErr(`This message does not verify (${a.reason}). It is kept, not shown.`);
    else if ("sealed_for_kernel" in a) setOpenErr("This message is sealed for your device key (post-quantum). Opening it on this device arrives with the device-key phase; the server cannot read it.");
    else setOpenErr(a.error);
  }, [boxId, loadCounts]);

  const act = useCallback(async (what: "archive" | "trash" | "star" | "unread" | "vault") => {
    const r = rows.find((x) => x.id === sel); if (!r) return;
    if (what === "star" || what === "unread") { await api.flag(boxId, [r.id], what === "star" ? { starred: !r.starred } : { read: false }); setRows((o) => o.map((x) => (x.id === r.id ? { ...x, starred: what === "star" ? !x.starred : x.starred, read: what === "unread" ? false : x.read } : x))); void loadCounts(); return; }
    const res = what === "vault" ? await api.setVault(boxId, r.thread_id, view !== "vault") : await api.move(boxId, [r.id], what);
    if (!res.ok) { setOpenErr(res.error || "That did not work."); return; }
    setSel(null); setOpened(null); void loadList(); void loadCounts();
  }, [rows, sel, boxId, view, loadList, loadCounts]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement | null; if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
      const c = keyCmd(e.key, { ctrl: e.ctrlKey, meta: e.metaKey, alt: e.altKey }, pending.current); pending.current = null; if (!c) return;
      if ("pending" in c) { pending.current = c.pending; window.setTimeout(() => { pending.current = null; }, 1200); return; }
      const i = rows.findIndex((x) => x.id === sel);
      if (c.cmd === "next" && rows.length) void select(rows[Math.min(rows.length - 1, i + 1)]); else if (c.cmd === "prev" && rows.length) void select(rows[Math.max(0, i - 1)]);
      else if (c.cmd === "folder" && c.arg) setView(c.arg); else if (c.cmd === "close") { setSel(null); setOpened(null); }
      else if (c.cmd === "move" && sel) void act(c.arg as "archive" | "trash"); else if (c.cmd === "star" && sel) void act("star"); else if (c.cmd === "unread" && sel) void act("unread");
    };
    window.addEventListener("keydown", onKey); return () => window.removeEventListener("keydown", onKey);
  }, [rows, sel, select, act]);

  async function verifyChain() { setChainBusy(true); setChain(null); try { setChain(await api.proof(boxId)); } catch { setChain(null); } setChainBusy(false); }

  const cur = rows.find((r) => r.id === sel) ?? null;
  const shown = useMemo(() => rows.filter((r) => matchRow(r, q)), [rows, q]);
  const copyAddr = async () => { try { await navigator.clipboard.writeText(box?.address ?? ""); setCopied(true); window.setTimeout(() => setCopied(false), 1800); } catch { /* clipboard refused */ } };
  const shareAddr = async () => { try { if (navigator.share) await navigator.share({ title: "My ANEXOMAIL address", text: box?.address ?? "" }); else await copyAddr(); } catch { /* cancelled */ } };
  return (
    <section className="mail" aria-label="Mail">
      <header className="mh">
        <div className="mh-brand"><LogoMark size={36} title="ANEXOMAIL" /><div><h1>ANEXOMAIL <span>Mail</span></h1>
          {boxes && boxes.length > 1 ? <select className="mh-box" value={boxId} onChange={(e) => setBoxId(e.target.value)} aria-label="Mailbox">{boxes.map((b) => <option key={b.id} value={b.id}>{b.address}</option>)}</select> : <p className="dim small">{box?.address ?? (conn === false ? "mail not set up" : "…")}</p>}</div></div>
        <div className="mh-right">
          <PillBar box={box} bound={bound} h3={h3} />
          <span className={`mh-live ${liveState}`} title="Live channel"><i aria-hidden="true" />{liveState === "live" ? "Live" : liveState === "reconnecting" ? "Reconnecting" : "Offline"}</span>
        </div>
      </header>
      <LaneRow lanes={lanes} go={setView} reduce={reduce} />
      {conn === false && <p className="mx-warn" role="alert">The mail doors did not answer. {err || "Run the E167, E168 and E169 SQL steps (sql-run.sh), then install the Rust service."}</p>}
      {conn && boxes && boxes.length === 0 && <p className="mx-warn">No mailbox exists for this account yet (E169 seeds the founder mailbox).</p>}
      <div className={`mb ${sel ? "has-sel" : ""}`}>
        <Rail view={view} set={(v) => { setView(v); if (v === "inbox") setFresh(0); }} counts={counts} pinned={pinned} setPinned={setPinned} />
        <div className="ml" aria-label={`${folderLabel(view)} messages`}>
          <div className="ml-h"><h2>{folderLabel(view)}</h2>{fresh > 0 && view === "inbox" && <button type="button" className="ml-new" onClick={() => { setFresh(0); void loadList(); }}>{fresh} new</button>}</div>
          <label className="ml-search"><span className="sr">Search this mailbox</span><input type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search loaded mail…" /></label>
          {isGatedView(view) && <p className="mx-note"><I k="lock" s={13} /> {view === "vault" ? "Vault threads" : "Quarantined mail"} stay sealed in the list. Each one needs a key touch to open.</p>}
          <ul className="ml-list">
            <AnimatePresence initial={false}>
              {shown.map((r) => { const t = rowText(r); return (
                <motion.li key={r.id} layout={!reduce} initial={reduce ? false : { opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.22 }}>
                  <button type="button" className={`mi ${sel === r.id ? "on" : ""} ${r.read ? "" : "unread"} ${t.locked ? "locked" : ""}`} onClick={() => void select(r)}>
                    <span className={`mi-av ${t.locked ? "lk" : ""}`} style={{ ["--h" as string]: hue(r.sum?.from) }} aria-hidden="true">{t.locked ? <I k="lock" s={15} /> : initials(r.sum?.from_name, r.sum?.from)}</span>
                    <span className="mi-bd">
                    <span className="mi-top"><b>{t.who}</b><time>{when(r.received_ms)}</time></span>
                    <span className="mi-sub">{!r.read && <i className="mi-dot" aria-label="unread" />}{t.subject}</span>
                    {t.snippet && <span className="mi-snip">{t.snippet}</span>}
                    <span className="mi-meta">{r.starred && <I k="star" s={12} />}{r.attach > 0 && <><I k="clip" s={12} />{r.attach}</>}{r.thread_count > 1 && <span>{r.thread_count} in thread</span>}{r.seal_mode === "recipient_pq" && <span>PQC</span>}</span>
                    </span>
                  </button>
                </motion.li>); })}
            </AnimatePresence>
          </ul>
          {!loading && rows.length === 0 && conn && view === "inbox" && box && (
            <div className="mx-ready">
              <h3>Your inbox is ready</h3><p className="dim">Anything sent to your address lands here the moment it is delivered, already sealed.</p>
              <div className="mx-addr"><span className="mx-cap">Your address</span><b>{box.address}</b>
                <div className="mx-addr-act"><button type="button" className="mx-btn alt" onClick={() => void copyAddr()}>{copied ? "Copied" : "Copy"}</button><button type="button" className="mx-btn alt" onClick={() => void shareAddr()}>Share</button></div></div>
            </div>)}
          {!loading && rows.length === 0 && conn && view !== "inbox" && <p className="mx-empty">{`${folderLabel(view)} is empty.`}</p>}
          {!loading && rows.length > 0 && shown.length === 0 && <p className="mx-empty">No loaded message matches “{q}”.</p>}
          {more && <button type="button" className="mx-more" disabled={loading} onClick={() => void loadList(more)}>{loading ? "Loading…" : "Older messages"}</button>}
        </div>
        <article className="mp" aria-live="polite">
          {!cur && (
            <div className="mp-empty">
              <LogoMark size={56} />
              <h2>Select a message</h2>
              <p className="dim">Every message is sealed before it is stored. The server opens it only for you, only after the checks.</p>
              <div className="mp-qa">
                <button type="button" className="mx-btn" onClick={() => void verifyChain()} disabled={chainBusy}>{chainBusy ? "Checking…" : "Verify ledger anchor"}</button>
                <button type="button" className="mx-btn alt" onClick={() => setView("vault")}><I k="vault" s={16} /> Open encrypted vault</button>
              </div>
              {chain && <p className={`mx-chain ${chain.chain_ok ? "ok" : "bad"}`} role="status"><i aria-hidden="true" />{chain.chain_ok ? `Mail ledger chain verified up to row #${chain.head_seq}.` : "The mail ledger chain FAILED its check."}{ledgerHead != null && <span> Head #{ledgerHead}.</span>}</p>}
            </div>
          )}
          {cur && (
            <div className="mp-in">
              <button type="button" className="mp-back" onClick={() => { setSel(null); setOpened(null); }}><I k="back" /> Back</button>
              {opening && <p className="mx-gate" role="status"><I k="lock" s={16} /> {cur.gated ? `${touchAction(cur.folder, cur.folder === "vault").why} Touch your key…` : "Opening…"}</p>}
              {openErr && !opening && <p className="mx-warn" role="alert">{openErr}</p>}
              {opened && (
                <>
                  <h2 className="mp-subj">{opened.sum.subject || "(no subject)"}</h2>
                  <div className="mp-from"><span className="mi-av lg" style={{ ["--h" as string]: hue(opened.sum.from) }} aria-hidden="true">{initials(opened.sum.from_name, opened.sum.from)}</span><b>{opened.sum.from_name || opened.sum.from}</b><span className="dim"> &lt;{opened.sum.from}&gt;</span><time>{opened.sum.date ? new Date(opened.sum.date).toLocaleString() : ""}</time></div>
                  <p className="dim small">To {(opened.sum.to ?? []).join(", ") || "—"}{opened.sum.cc?.length ? ` · Cc ${opened.sum.cc.join(", ")}` : ""} · {fmtSize(opened.facts.size)}</p>
                  <div className="mp-chips">
                    <ProofChip p={proof} busy={proofBusy} />
                    {verdicts(opened.facts).map((v) => <span key={v.k} className={`mx-chip ${v.tone}`}>{v.text}</span>)}
                    {opened.touched && <span className="mx-chip ok">Opened with your key</span>}
                  </div>
                  <div className="mp-act">
                    <button type="button" className="mx-btn alt" onClick={() => void act("archive")}>Archive</button>
                    <button type="button" className="mx-btn alt" onClick={() => void act("trash")}>Trash</button>
                    <button type="button" className="mx-btn alt" onClick={() => void act("star")}>{cur.starred ? "Unstar" : "Star"}</button>
                    <button type="button" className="mx-btn alt" onClick={() => void act("unread")}>Mark unread</button>
                    <button type="button" className="mx-btn alt" onClick={() => void act("vault")}><I k="vault" s={15} /> {view === "vault" ? "Take out of Vault" : "Move to Vault"}</button>
                  </div>
                  {opened.view.remote_content_blocked && <p className="mx-note">Remote images and scripts in this message were not loaded. You are reading its text only.</p>}
                  <pre className="mp-body">{opened.view.text || "(empty message)"}</pre>
                  {opened.view.attachments.length > 0 && (
                    <ul className="mp-att" aria-label="Attachments">{opened.view.attachments.map((a, i) => <li key={i}><I k="clip" s={14} /><b>{a.name}</b><span className="dim">{a.type} · {fmtSize(a.size)}</span></li>)}<li className="dim small">Opening attachments arrives with the attachment phase (virus-scanned, sealed, streamed).</li></ul>
                  )}
                </>
              )}
            </div>
          )}
        </article>
      </div>
    </section>
  );
}
