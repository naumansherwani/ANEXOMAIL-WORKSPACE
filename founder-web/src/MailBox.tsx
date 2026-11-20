import { TlsProven } from "./TlsLock";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { flushSync } from "react-dom";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { titleWith } from "./mail_change";
import * as Popover from "@radix-ui/react-popover";
import * as api from "./mail_api";
import { openSealedMail } from "./mail_pq";
import { MailCompose, UndoBar, type Start } from "./MailCompose";
import { OutboxPanel } from "./OutboxPanel";
import { MailAnchorLine } from "./MailAnchorLine";
import { LogoMark } from "./Brand";
import { Ic, FOLDER_ICON } from "./mailbox_icons";
import { arrivalLine, describeQuery, freshRows, isEmptyQuery, matchQuery, parseQuery, speedWords, suggest } from "./mailbox_pure";
import { FOLDERS, ago, compact, fmtSize, glide, hue, initials, isGatedView, keyCmd, ledgerChip, merge, pill, proofChip, quoteReply, replySubject, rowText, touchAction, verdicts, when, folderLabel, type Box, type Counts, type Lane, type Proof, type Row } from "./mail_pure";
import { TrustRing, OutFactsLine } from "./TrustRing";
import { MailTimeline } from "./MailTimeline";
import { FollowupChip } from "./FollowupChip";
import { SentBadge, useSentBadges } from "./SentBadges";
import { hasOthers } from "./reply_pure";
import { buildStart, type ReplyKind } from "./reply_start";
import { QuotedBody, selectedIn } from "./QuotedBody";
import { MailReplyBar } from "./MailReplyBar";
import { ConfirmSheet } from "./ConfirmSheet";
import { deleteQuestion, emptyTrashQuestion, foreverIds, type Ask } from "./confirm_pure";
import { sentMs } from "./trust_pure";
import "./mail.css";
import "./mailbox.css";

// QUI-LIVE: the founder mailbox, the living look. NEW file; MailView.tsx stays untouched (its logic is reused through mail_api / mail_pure, not copied into a second door).
// Nothing is made up: every row, count, chip and the Mail speed number comes from the Rust mail doors through the kernel; a value the server did not give is "-".

function Num({ n, off }: { n: number | null | undefined; off?: boolean }) {
  const [shown, setShown] = useState(n ?? 0), from = useRef(n ?? 0), raf = useRef(0);
  useEffect(() => {
    if (n == null) return; if (off) { setShown(n); from.current = n; return; }
    const a = from.current, t0 = performance.now(), D = 600;
    const step = (t: number) => { const p = Math.min(1, (t - t0) / D); setShown(glide(a, n, p)); if (p < 1) raf.current = requestAnimationFrame(step); else from.current = n; };
    raf.current = requestAnimationFrame(step); return () => cancelAnimationFrame(raf.current);
  }, [n, off]);
  return <>{n == null ? "-" : compact(shown)}</>;
}

function ProofChip({ p, busy, box, id }: { p: Proof | null; busy: boolean; box?: string; id?: string }) {
  const c = proofChip(p);
  return (
    <Popover.Root>
      <Popover.Trigger asChild><button type="button" className={`mx-proof ${busy ? "busy" : c.state}`}><i aria-hidden="true" />{busy ? "Checking the ledger…" : c.text}</button></Popover.Trigger>
      <Popover.Portal><Popover.Content className="mx-pop" side="bottom" align="start" sideOffset={8} collisionPadding={12}>
        <b>{busy ? "Checking…" : c.text}</b>{!busy && c.detail.map((d, i) => <span key={i} className={d.startsWith("Hash chain only") ? "mx-stale" : undefined}>{d}</span>)}{!busy && box && id && <MailAnchorLine box={box} id={id} />}<Popover.Arrow className="mx-arrow" />
      </Popover.Content></Popover.Portal>
    </Popover.Root>
  );
}

const LANE_TO_VIEW: Record<string, string> = { "mail-in": "inbox", "mail-quarantine": "quarantine", "mail-out": "sent", "mail-failed": "outbox", "mail-queued": "outbox" };

export function MailBox() {
  const reduce = !!useReducedMotion();
  const [boxes, setBoxes] = useState<Box[] | null>(null), [boxId, setBoxId] = useState(""), [conn, setConn] = useState<boolean | null>(null), [err, setErr] = useState("");
  const [view, setView] = useState(() => { try { const v = window.sessionStorage.getItem("mail.openview"); window.sessionStorage.removeItem("mail.openview"); return v && FOLDERS.some((f) => f.key === v) ? v : "inbox"; } catch { return "inbox"; } });
  const [rows, setRows] = useState<Row[]>([]), [more, setMore] = useState<{ ts: string; id: string } | null>(null), [loading, setLoading] = useState(false);
  const [counts, setCounts] = useState<Counts | null>(null), [lanes, setLanes] = useState<Lane[] | null>(null), [ledgerHead, setLedgerHead] = useState<number | null>(null);
  const [sel, setSel] = useState<string | null>(null), [opened, setOpened] = useState<api.Opened | null>(null), [openErr, setOpenErr] = useState(""), [opening, setOpening] = useState(false);
  const [proof, setProof] = useState<Proof | null>(null), [proofBusy, setProofBusy] = useState(false), [chain, setChain] = useState<Proof | null>(null), [chainBusy, setChainBusy] = useState(false), [kernelLedger, setKernelLedger] = useState<Awaited<ReturnType<typeof api.verifyLedgerInKernel>>>(null);
  const [bound, setBound] = useState<boolean | null>(null), [liveState, setLiveState] = useState<"live" | "reconnecting" | "off">("off"), [fresh, setFresh] = useState(0);
  const [qText, setQText] = useState(""), [qFocus, setQFocus] = useState(false), [copied, setCopied] = useState(false);
  const [compose, setCompose] = useState<Start | null>(null), [queued, setQueued] = useState<api.Queued | null>(null);
  const [speed, setSpeed] = useState<ReturnType<typeof speedWords>>(null);
  const [arrival, setArrival] = useState<{ k: number; who: string; what: string } | null>(null), [flash, setFlash] = useState(0), [flashRows, setFlashRows] = useState<string[]>([]);
  const pending = useRef<string | null>(null), searchRef = useRef<HTMLInputElement>(null), sentRef = useRef<HTMLButtonElement>(null), rowsRef = useRef<Row[]>([]);
  const box = useMemo(() => boxes?.find((b) => b.id === boxId) ?? null, [boxes, boxId]);
  const [h3, setH3] = useState(() => api.mailTransport());
  useEffect(() => { let n = 0; const t = window.setInterval(() => { setH3(api.mailTransport()); if (++n >= 15) window.clearInterval(t); }, 2000); return () => window.clearInterval(t); }, []);
  const viewRef = useRef(view); viewRef.current = view; rowsRef.current = rows;

  useEffect(() => { let on = true; (async () => {
    try { const b = await api.boxes(); if (!on) return; setConn(b.connected); setBoxes(b.boxes ?? []); if (b.boxes?.[0]) setBoxId(b.boxes[0].id); } catch (e) { if (on) { setConn(false); setErr((e as Error).message); } }
    try { const l = await api.lanes(); if (on && l) { setLanes(l.lanes); setLedgerHead(l.ledger_head); } } catch { /* lanes are optional */ }
    api.dbscBound().then((x) => on && setBound(x)).catch(() => {});
  })(); return () => { on = false; }; }, []);

  // Mail speed (QPERF-3 door): the real median of the whole mail stage, refreshed every minute; "-" until a real mail was measured.
  useEffect(() => { let on = true; const go = () => api.perf("24h").then((r) => { if (on) setSpeed(speedWords(r?.perf.stages.total ?? null)); }).catch(() => {}); void go(); const t = window.setInterval(go, 60_000); return () => { on = false; window.clearInterval(t); }; }, []);

  const loadList = useCallback(async (more?: { ts: string; id: string } | null, announce = false) => {
    if (!boxId) return; setLoading(true);
    try {
      const l = await api.list(boxId, viewRef.current, more ?? undefined);
      if (l) {
        if (announce && !more && viewRef.current === "inbox") { const f = freshRows(rowsRef.current, l.rows); if (f.length) { const a = arrivalLine(f[0]); setArrival({ k: Date.now(), ...a }); setFlash((n) => n + 1); setFlashRows(f.map((r) => r.id)); window.setTimeout(() => setFlashRows([]), 2400); } }
        setRows((old) => (more ? merge(old, l.rows) : l.rows)); setMore(l.more ? l.next : null); setErr("");
      } else setErr("The mail doors did not answer. Run the E167, E168 and E169 SQL steps.");
    } catch (e) { setErr((e as Error).message); } setLoading(false);
  }, [boxId]);
  const loadCounts = useCallback(async () => { if (!boxId) return; try { const c = await api.counts(boxId); if (c) setCounts(c); } catch { /* the live channel retries */ } }, [boxId]);
  useEffect(() => { setRows([]); setMore(null); setSel(null); setOpened(null); setOpenErr(""); void loadList(); }, [boxId, view, loadList]);
  useEffect(() => { void loadCounts(); }, [loadCounts]);
  useEffect(() => { const base = "Mail"; const prev = document.title; document.title = titleWith(base, counts?.inbox?.unread ?? 0); return () => { document.title = prev; }; }, [counts]); // QLIVE: "(3) Mail" in the tab, like a mail client
  useEffect(() => { if (!arrival) return; const t = window.setTimeout(() => setArrival(null), 6000); return () => window.clearTimeout(t); }, [arrival]);

  useEffect(() => {
    if (!boxId) return;
    const stop = api.live(boxId, (m) => {
      if (m.data?.counts) setCounts(m.data.counts);
      if (m.data?.feed?.lanes) { setLanes(m.data.feed.lanes); setLedgerHead(m.data.feed.ledger_head ?? null); }
      if (m.event === "changes" && ((m.data?.arrived ?? 0) === 0 || viewRef.current !== "inbox")) void loadList(null, false); // QLIVE: a read / move / star / send state changed somewhere (or a mail landed in another folder): the open list follows by itself
      if (m.event === "arrival") { setFresh((n) => n + (m.data?.new > 0 ? m.data.new : 1)); if (viewRef.current === "inbox") void loadList(null, true); }
    }, (s) => setLiveState(s));
    return () => { stop(); setLiveState("off"); };
  }, [boxId, loadList]);

  /** Opening a message cross-fades the reader (View Transitions API, same document); without the API or with reduced motion it is a plain state change. */
  const swap = useCallback((fn: () => void) => {
    const d = document as Document & { startViewTransition?: (cb: () => void) => unknown };
    if (!reduce && typeof d.startViewTransition === "function") { try { d.startViewTransition(() => { flushSync(fn); }); return; } catch { /* fall through */ } }
    fn();
  }, [reduce]);

  const select = useCallback(async (r: Row) => {
    setSel(r.id); setOpened(null); setOpenErr(""); setProof(null); setOpening(true);
    const { r: a } = await api.open(boxId, r.id); if (!("opened" in a)) setOpening(false);
    if ("opened" in a) { swap(() => { setOpened(a); setOpening(false); }); setRows((old) => old.map((x) => (x.id === r.id ? { ...x, read: true } : x))); void loadCounts(); setProofBusy(true); api.proof(boxId, r.id).then(setProof).catch(() => setProof(null)).finally(() => setProofBusy(false)); }
    else if ("needs_touch" in a) setOpenErr("A key touch is needed to open this.");
    else if ("broken" in a) setOpenErr(`This message does not verify (${a.reason}). It is kept, not shown.`);
    else if ("sealed_for_kernel" in a) { setOpening(true); const o = await openSealedMail(boxId, a.mail, !!a.touched); setOpening(false); if ("opened" in o) { swap(() => { setOpened(o); }); if (r.direction === "in") void api.flag(boxId, [r.id], { read: true }); setRows((old) => old.map((x) => (x.id === r.id ? { ...x, read: true } : x))); void loadCounts(); setProofBusy(true); api.proof(boxId, r.id).then(setProof).catch(() => setProof(null)).finally(() => setProofBusy(false)); } else setOpenErr(o.error); }
    else setOpenErr(a.error);
  }, [boxId, loadCounts, swap]);

  const doAct = useCallback(async (what: "archive" | "trash" | "star" | "unread" | "vault") => {
    const r = rows.find((x) => x.id === sel); if (!r) return;
    if (what === "star" || what === "unread") { await api.flag(boxId, [r.id], what === "star" ? { starred: !r.starred } : { read: false }); setRows((o) => o.map((x) => (x.id === r.id ? { ...x, starred: what === "star" ? !x.starred : x.starred, read: what === "unread" ? false : x.read } : x))); void loadCounts(); return; }
    const res = what === "vault" ? await api.setVault(boxId, r.thread_id, view !== "vault") : what === "trash" && r.direction === "out" ? await api.discard(boxId, r.id) : await api.move(boxId, [r.id], what === "archive" && r.folder === "archive" ? "inbox" : what);   // Q1b4: Archive on an archived mail puts it back in the Inbox (nothing was able to restore it before)
    if (!res.ok) { setOpenErr(res.error || "That did not work."); return; }
    setSel(null); setOpened(null); void loadList(); void loadCounts();
  }, [rows, sel, boxId, view, loadList, loadCounts]);

  // QC5: Delete forever (Trash only). One selected mail, or Empty Trash for the listed mails (<= 100 per touch).
  const [forever, setForever] = useState<string[] | null>(null);
  const doForever = useCallback(async () => {
    const ids = forever ?? (sel ? [sel] : []); setForever(null); if (!ids.length) return;
    const res = await api.deleteForever(boxId, foreverIds(ids)); if (!res.ok) { setOpenErr(res.error || "That did not work."); return; }
    setSel(null); setOpened(null); void loadList(); void loadCounts();
  }, [forever, sel, boxId, loadList, loadCounts]);
  const cur = rows.find((r) => r.id === sel) ?? null;
  // Q1b4: Delete asks first (his 17 Nov order). Trash is the only destructive door here; every other action stays one click.
  const [ask, setAsk] = useState<Ask | null>(null);
  const bodyRef = useRef<HTMLDivElement>(null), [inline, setInline] = useState<{ id: string; start: Start } | null>(null), [hasSel, setHasSel] = useState(false);
  const composeOpen = useRef(false); composeOpen.current = compose !== null || ask !== null || inline !== null;
  const act = useCallback((what: "archive" | "trash" | "star" | "unread" | "vault") => {
    if (what !== "trash") return doAct(what);
    const r = rows.find((x) => x.id === sel); if (!r) return Promise.resolve();
    setAsk(deleteQuestion(r.folder, r.direction, r.sum?.subject)); return Promise.resolve();
  }, [rows, sel, doAct]);
  const query = useMemo(() => parseQuery(qText), [qText]);
  const shown = useMemo(() => rows.filter((r) => matchQuery(r, query)), [rows, query]);
  const sentBadges = useSentBadges(boxId, view, useMemo(() => shown.filter((r) => r.direction === "out").map((r) => r.id), [shown]));
  // QC4b: Reply / Reply all / Forward open the panel UNDER the mail (same composer); Pop-out moves it to the window. The reader's selection (if any) is what gets quoted.
  const startReply = useCallback((k: ReplyKind) => { if (!opened || !cur || !box) return; setInline({ id: cur.id, start: buildStart(k, { sum: opened.sum, text: opened.view.text || "", me: [box.address], selection: k === "forward" ? "" : selectedIn(bodyRef.current) }) }); }, [opened, cur, box]);
  const reply = useCallback(() => startReply("reply"), [startReply]);
  useEffect(() => { const f = () => setHasSel(selectedIn(bodyRef.current) !== ""); document.addEventListener("selectionchange", f); return () => document.removeEventListener("selectionchange", f); }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (composeOpen.current) return;   // Q1b4: while the compose box is open NO mailbox shortcut may fire (typed letters were archiving / starring the selected mail)
      const t = e.target as HTMLElement | null; if (t?.closest?.("dialog")) return;   // Q1b4: keys inside the ring sheet or the delete question belong to that dialog (Esc must not also close the mail)
      if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
      if (e.key === "/" && !e.ctrlKey && !e.metaKey && !e.altKey) { e.preventDefault(); searchRef.current?.focus(); return; }
      if (!e.ctrlKey && !e.metaKey && !e.altKey && opened && cur && cur.folder !== "drafts") {
        if (e.key === "r" && cur.direction === "in") { e.preventDefault(); startReply("reply"); return; }
        if (e.key === "a" && cur.direction === "in" && opened.sum.to && hasOthers({ from: opened.sum.from ?? "", to: opened.sum.to ?? [], cc: opened.sum.cc ?? [], replyTo: opened.sum.reply_to, me: [box?.address ?? ""] })) { e.preventDefault(); startReply("all"); return; }
        if (e.key === "f") { e.preventDefault(); startReply("forward"); return; }
      }
      const c = keyCmd(e.key, { ctrl: e.ctrlKey, meta: e.metaKey, alt: e.altKey }, pending.current); pending.current = null; if (!c) return;
      if ("pending" in c) { pending.current = c.pending; window.setTimeout(() => { pending.current = null; }, 1200); return; }
      const i = shown.findIndex((x) => x.id === sel);
      if (c.cmd === "next" && shown.length) void select(shown[Math.min(shown.length - 1, i + 1)]); else if (c.cmd === "prev" && shown.length) void select(shown[Math.max(0, i - 1)]);
      else if (c.cmd === "compose") setCompose({}); else if (c.cmd === "folder" && c.arg) setView(c.arg); else if (c.cmd === "close") { setSel(null); setOpened(null); }
      else if (c.cmd === "move" && sel) void act(c.arg as "archive" | "trash"); else if (c.cmd === "star" && sel) void act("star"); else if (c.cmd === "unread" && sel) void act("unread");
    };
    window.addEventListener("keydown", onKey); return () => window.removeEventListener("keydown", onKey);
  }, [shown, sel, select, act, cur, opened, reply]);

  useEffect(() => { if (boxId) void verifyChain(); }, [boxId, ledgerHead]);   // eslint-disable-line react-hooks/exhaustive-deps
  async function verifyChain() { setChainBusy(true); setChain(null); setKernelLedger(null); try { const pr = await api.proof(boxId); setChain(pr); setKernelLedger(await api.verifyLedgerInKernel(pr?.head_seq ?? null, (pr as any)?.head_hash ?? null)); } catch { setChain(null); } setChainBusy(false); }

  /** After a send: a small light flies from the Send button to "Sent" (Web Animations API). Respects reduced motion; a missing element just skips it. */
  const comet = useCallback(() => {
    if (reduce) return;
    try {
      const from = document.querySelector<HTMLElement>(".mc footer button[type=submit]")?.getBoundingClientRect(), to = sentRef.current?.getBoundingClientRect();
      if (!from || !to || !to.width) return;
      const el = document.createElement("div"); el.className = "mbx-comet"; document.body.appendChild(el);
      const x0 = from.left + from.width / 2 - 7, y0 = from.top + from.height / 2 - 7, x1 = to.left + 22, y1 = to.top + to.height / 2 - 7;
      const a = el.animate([{ transform: `translate(${x0}px,${y0}px) scale(1)`, opacity: 1 }, { transform: `translate(${(x0 + x1) / 2}px,${Math.min(y0, y1) - 90}px) scale(1.5)`, opacity: 1, offset: 0.5 }, { transform: `translate(${x1}px,${y1}px) scale(.5)`, opacity: 0.1 }], { duration: 800, easing: "cubic-bezier(.4,.1,.2,1)" });
      a.onfinish = () => { el.remove(); setFlash((n) => n + 1); }; a.oncancel = () => el.remove();
    } catch { /* decoration only */ }
  }, [reduce]);

  const copyAddr = async () => { try { await navigator.clipboard.writeText(box?.address ?? ""); setCopied(true); window.setTimeout(() => setCopied(false), 1800); } catch { /* clipboard refused */ } };
  const p = pill(h3, bound, box);
  const lc = ledgerChip(chain, chainBusy, ledgerHead, kernelLedger);
  const sugg = qFocus ? suggest(rows, qText) : [];
  const said = describeQuery(query);

  const health = (<>
        <span className={`mp-seg ${p.quic.ok ? "ok" : "no"}`}><i aria-hidden="true" />{p.quic.text}</span><b aria-hidden="true">·</b>
        <span className={`mp-seg ${p.dbsc.ok ? "ok" : "no"}`}><i aria-hidden="true" />{p.dbsc.text}</span><b aria-hidden="true">·</b>
        <span className={`mp-seg ${p.seal.ok ? "ok" : "no"}`}><i aria-hidden="true" />{p.seal.text}</span>
        {box && <button type="button" className={`mx-chip lg ${lc.tone}`} onClick={() => void verifyChain()} disabled={chainBusy} title={lc.title} aria-label={lc.title}><i aria-hidden="true" />{lc.text}</button>}
        {lanes && <ul className="mbx-lanes" aria-label="Mail lanes, last 24 hours">{lanes.map((l) => { const v = LANE_TO_VIEW[l.lane]; const body = <><i className={`ml-dot ${l.tone}`} aria-hidden="true" /><b><Num n={l.count} off={reduce} /></b>{l.label}{l.last_ms ? <small>{ago(l.last_ms)}</small> : null}</>; return <li key={l.lane}>{v ? <button type="button" onClick={() => setView(v)} title={`Open ${folderLabel(v)}`}>{body}</button> : <span>{body}</span>}</li>; })}</ul>}
  </>);
  return (
    <section className={`mbx ${sel ? "has-sel" : ""}`} aria-label="Mail">
      <div key={flash} className={`mbx-edge ${flash ? "on" : ""}`} aria-hidden="true" />
      <header className="mbx-top">
        <div className="mbx-brand"><LogoMark size={36} title="ANEXOMAIL" /><div><b>ANEXOMAIL</b>{boxes && boxes.length > 1 ? <select className="mh-box" value={boxId} onChange={(e) => setBoxId(e.target.value)} aria-label="Mailbox">{boxes.map((b) => <option key={b.id} value={b.id}>{b.address}</option>)}</select> : <small>{box?.address ?? (conn === false ? "mail not set up" : "…")}</small>}</div></div>
        <div className="mbx-status"><span className="mbx-role" title="Your role on this workspace"><Ic k="shield" s={16} /><span><b>Founder / Chairman</b><small>Muhammad Nauman Sherwani</small></span></span></div>
      </header>

      <div className="mbx-strip mbx-strip-top" role="status" aria-label={`${p.quic.text}, ${p.dbsc.text}, ${p.seal.text}`}>{health}</div>
      {conn === false && <p className="mx-warn" role="alert">The mail doors did not answer. {err || "Run the E167, E168 and E169 SQL steps (sql-run.sh), then install the Rust service."}</p>}
      {conn && boxes && boxes.length === 0 && <p className="mx-warn">No mailbox exists for this account yet (E169 seeds the founder mailbox).</p>}

      <div className="mbx-body">
        <nav className="mbx-apps" aria-label="Mail folders">
          {box && <button type="button" className="mbx-new mbx-glow idle" onClick={() => setCompose({})} title="New email (c)"><Ic k="pen" s={18} /><span>New mail</span><kbd>C</kbd></button>}
          <p className="mbx-cap">Folders</p>
          {FOLDERS.map((f) => { const c = counts?.[f.key]; return (
            <button key={f.key} ref={f.key === "sent" ? sentRef : undefined} type="button" className={`mbx-f ${view === f.key ? "on" : ""}`} onClick={() => { setView(f.key); if (f.key === "inbox") setFresh(0); }} aria-current={view === f.key ? "page" : undefined} title={f.label}>
              <Ic k={FOLDER_ICON[f.key] ?? "mail"} fill={view === f.key} /><span className="mbx-fl">{f.label}</span>{f.gated && <span className="mbx-lock" title="Needs a key touch to open"><Ic k="lock" s={13} /></span>}
              <span className={`mbx-fc ${c?.unread ? "u" : ""}`}>{c ? <Num n={c.unread || c.total} off={reduce} /> : "-"}</span>
            </button>); })}
          <div className="mbx-speed" title="Median time from arrival to sealed and stored, measured on your real mail (last 24 hours)">
            <p className="mbx-cap"><Ic k="gauge" s={14} /> Mail speed</p>
            {speed ? <><p className="mbx-sv"><b>{speed.value}</b> {speed.unit}</p><p className="mbx-sn">Arrival to sealed and stored, {speed.note}.</p></> : <><p className="mbx-sv"><b>-</b></p><p className="mbx-sn">No real mail measured yet. It appears after the first mail arrives.</p></>}
          </div>
          <div className="mbx-strip mbx-health" role="status" aria-label="Mail health"><p className="mbx-cap">Mail health</p>{health}</div>
        </nav>

        <div className="mbx-list" aria-label={`${folderLabel(view)} messages`}>
          <nav className="mbx-fchips" aria-label="Mail folders (phone)">{FOLDERS.map((f) => { const c = counts?.[f.key]; return <button key={f.key} type="button" className={view === f.key ? "on" : ""} aria-current={view === f.key ? "page" : undefined} onClick={() => { setView(f.key); setSel(null); setOpened(null); if (f.key === "inbox") setFresh(0); }}><Ic k={FOLDER_ICON[f.key] ?? "mail"} s={16} fill={view === f.key} /><span>{f.label}</span>{c?.unread ? <em>{compact(c.unread)}</em> : null}</button>; })}</nav>
          <div className="mbx-lh">
            <h2>{folderLabel(view)}</h2>
            {fresh > 0 && view === "inbox" && <button type="button" className="mbx-newn" onClick={() => { setFresh(0); void loadList(); }}>{fresh} new</button>}
            <span className="mbx-sp" />
            <div className="mbx-acts" role="toolbar" aria-label="Message actions">
              <button type="button" className="mbx-ib" disabled={!sel} onClick={() => void act("trash")} title="Delete (#)" aria-label="Delete"><Ic k="trash" /></button>
              {view === "trash" && rows.length > 0 && <button type="button" className="mbx-ib" onClick={() => { const ids = foreverIds(rows.map((r) => r.id)); setForever(ids); setAsk(emptyTrashQuestion(rows.length)); }} title="Empty Trash (delete forever)" aria-label="Empty Trash"><Ic k="trash" /></button>}
              <button type="button" className="mbx-ib" disabled={!sel} onClick={() => void act("archive")} title="Archive (e)" aria-label="Archive"><Ic k="archive" /></button>
              <button type="button" className="mbx-ib" disabled={!sel} onClick={() => void act("star")} title="Star (s)" aria-label="Star"><Ic k="flag" fill={!!cur?.starred} /></button>
              <button type="button" className="mbx-ib" disabled={!sel} onClick={() => void act("unread")} title="Mark unread (u)" aria-label="Mark unread"><Ic k="unread" /></button>
              <button type="button" className="mbx-ib" disabled={!sel} onClick={() => void act("vault")} title={view === "vault" ? "Take out of Vault" : "Move to Vault"} aria-label="Vault"><Ic k="vault" /></button>
            </div>
          </div>
          {view === "outbox" && box && <OutboxPanel box={box.id} onChanged={() => { void loadCounts(); void loadList(); }} />}
          <div className="mbx-srow">
          <div className={`mbx-sbox mbx-glow ${qFocus ? "on" : "idle"} ${qText ? "has" : ""}`}>
            <label className="mbx-sin"><span className="sr">Search mail</span><Ic k="search" s={18} /><input ref={searchRef} value={qText} onChange={(e) => setQText(e.target.value)} onFocus={() => setQFocus(true)} onBlur={() => window.setTimeout(() => setQFocus(false), 140)} placeholder="Search" autoComplete="off" spellCheck={false} />{qText ? <button type="button" className="mbx-x" onClick={() => setQText("")} aria-label="Clear search"><Ic k="close" s={16} /></button> : null}</label>
            {qFocus && <div className="mbx-dd" role="listbox">{said ? <p>{said}</p> : <p>Searched inside your browser. Sealed mail is never read.</p>}{sugg.length > 0 && <div>{sugg.map((s) => <button key={s} type="button" onMouseDown={(e) => { e.preventDefault(); setQText((t) => (t.match(/\S+$/) ? t.replace(/\S+$/, s) : t + s) + " "); }}>{s}</button>)}</div>}</div>}
          </div>
          </div>
          {isGatedView(view) && <p className="mx-note"><Ic k="lock" s={14} /> {view === "vault" ? "Vault threads" : "Quarantined mail"} stay sealed in the list. Each one needs a key touch to open.</p>}
          {!isEmptyQuery(query) && <p className="mbx-qnote">{shown.length} of {rows.length} loaded</p>}
          <ul className="mbx-rows">
            <AnimatePresence initial={false}>
              {shown.map((r) => { const t = rowText(r); return (
                <motion.li key={r.id} layout={!reduce} initial={reduce ? false : { opacity: 0, y: -12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.22 }}>
                  <button type="button" className={`mbx-r ${sel === r.id ? "on" : ""} ${r.read ? "" : "unread"} ${t.locked ? "locked" : ""} ${flashRows.includes(r.id) ? "fresh" : ""}`} onClick={() => void select(r)}>
                    <span className={`mbx-av ${t.locked ? "lk" : ""}`} style={{ ["--h" as string]: hue(r.sum?.from) }} aria-hidden="true">{t.locked ? <Ic k="lock" s={16} /> : initials(r.sum?.from_name, r.sum?.from)}</span>
                    <span className="mbx-rb">
                      <span className="mbx-r1"><b>{!r.read && <i className="mbx-dot" aria-label="unread" />}{t.who}{r.direction === "out" && <SentBadge b={sentBadges[r.id]} />}</b><span className="mbx-rm">{r.attach > 0 && <Ic k="clip" s={14} />}{r.starred && <Ic k="flag" s={14} fill />}<time>{when(sentMs(r) ?? r.received_ms)}</time></span></span>
                      <span className="mbx-r2">{t.subject}</span>
                      {t.snippet && <span className="mbx-r3">{t.snippet}</span>}
                      {(r.thread_count > 1 || r.seal_mode === "recipient_pq") && <span className="mbx-r4">{r.thread_count > 1 && <span>{r.thread_count} in thread</span>}{r.seal_mode === "recipient_pq" && <span>PQC</span>}</span>}
                    </span>
                  </button>
                </motion.li>); })}
            </AnimatePresence>
          </ul>
          {!loading && rows.length === 0 && conn && view === "inbox" && box && (
            <div className="mx-ready">
              <h3>Your inbox is ready</h3><p className="dim">Anything sent to your address lands here the moment it is delivered, already sealed.</p>
              <div className="mx-addr"><span className="mx-cap">Your address</span><b>{box.address}</b><div className="mx-addr-act"><button type="button" className="mx-btn alt" onClick={() => void copyAddr()}>{copied ? "Copied" : "Copy"}</button></div></div>
            </div>)}
          {!loading && rows.length === 0 && conn && view !== "inbox" && <p className="mx-empty">{`${folderLabel(view)} is empty.`}</p>}
          {!loading && rows.length > 0 && shown.length === 0 && <p className="mx-empty">No loaded message matches this search.</p>}
          {more && <button type="button" className="mx-more" disabled={loading} onClick={() => void loadList(more)}>{loading ? "Loading…" : "Older messages"}</button>}
        </div>

        <article className="mbx-read" aria-live="polite">
          {!cur && <div className="mbx-empty"><LogoMark size={56} /><h2>Select a message</h2><p>Every message is sealed before it is stored. The server opens it only for you, only after the checks.</p></div>}
          {cur && (
            <div className="mbx-in">
              <div className="mbx-rbar">
                <button type="button" className="mbx-ib mbx-back" onClick={() => { swap(() => { setSel(null); setOpened(null); }); }} aria-label="Back to the list"><Ic k="back" /></button>
                {cur.direction === "in" && opened && <button type="button" className="mbx-ib" onClick={reply} title="Reply (r)" aria-label="Reply"><Ic k="reply" /></button>}
                {cur.folder === "drafts" && <button type="button" className="mx-btn" onClick={() => api.drafts(boxId).then((d) => d?.[0] && setCompose({ draft: d[0].id }))}>Continue latest draft</button>}
                <span className="mbx-sp" />
                <button type="button" className="mbx-ib mbx-ra" onClick={() => void act("archive")} title={cur.folder === "archive" ? "Move to Inbox (e)" : "Archive (e)"} aria-label={cur.folder === "archive" ? "Move to Inbox" : "Archive"}><Ic k="archive" /></button>
                <button type="button" className="mbx-ib mbx-ra" onClick={() => void act("trash")} title="Delete (#)" aria-label="Delete"><Ic k="trash" /></button>
                <button type="button" className="mbx-ib" onClick={() => void act("star")} aria-pressed={cur.starred} title="Star (s)" aria-label="Star"><Ic k="flag" fill={cur.starred} /></button>
              </div>
              {opening && <p className="mx-gate" role="status"><Ic k="lock" s={16} /> {cur.gated ? `${touchAction(cur.folder, cur.folder === "vault").why} Touch your key…` : "Opening…"}</p>}
              {openErr && !opening && <p className="mx-warn" role="alert">{openErr}</p>}
              {opened && (
                <>
                  <h2 className="mbx-subj">{opened.sum.subject || "(no subject)"}</h2>
                  <div className="mbx-from"><span className="mbx-av lg" style={{ ["--h" as string]: hue(opened.sum.from) }} aria-hidden="true">{initials(opened.sum.from_name, opened.sum.from)}</span><div><b>{opened.sum.from_name || opened.sum.from}</b><small>&lt;{opened.sum.from}&gt; · {opened.sum.date ? new Date(opened.sum.date).toLocaleString() : ""}</small><small>To {(opened.sum.to ?? []).join(", ") || "-"}{opened.sum.cc?.length ? ` · Cc ${opened.sum.cc.join(", ")}` : ""} · {fmtSize(opened.facts.size)}</small></div></div>
                  <div className="mbx-chips">
                    <ProofChip p={proof} busy={proofBusy} box={boxId} id={opened.facts.id} />
                    {cur.direction === "in" && <TrustRing box={boxId} id={opened.facts.id} facts={opened.facts} />}
                    {cur.direction === "in" && verdicts(opened.facts).map((v) => <span key={v.k} className={`mx-chip ${v.tone}`}>{v.text}</span>)}
                    {opened.touched && <span className="mx-chip ok">Opened with your key</span>}
                  </div>
                  {cur.direction === "out" && <OutFactsLine box={boxId} id={opened.facts.id} />}
                  {cur.direction === "out" && <MailTimeline box={boxId} id={opened.facts.id} />}
                  {cur.direction === "out" && <FollowupChip box={boxId} message={opened.facts.id} />}
                  {cur.direction === "out" && <TlsProven box={boxId} addrs={[...(opened.sum.to ?? []), ...(opened.sum.cc ?? [])]} />}
                  {opened.view.remote_content_blocked && <p className="mx-note">Remote images and scripts in this message were not loaded. You are reading its text only.</p>}
                  <QuotedBody ref={bodyRef} text={opened.view.text || ""} />
                  {opened.view.attachments.length > 0 && (
                    <ul className="mbx-att" aria-label="Attachments">{opened.view.attachments.map((a, i) => <li key={i}><Ic k="clip" s={16} /><b>{a.name}</b><span>{a.type} · {fmtSize(a.size)}</span></li>)}<li className="mbx-attn">Opening attachments arrives with the attachment phase (virus-scanned, sealed, streamed).</li></ul>
                  )}
                  {cur.folder !== "drafts" && <MailReplyBar canAll={cur.direction === "in" && hasOthers({ from: opened.sum.from ?? "", to: opened.sum.to ?? [], cc: opened.sum.cc ?? [], replyTo: opened.sum.reply_to, me: [box?.address ?? ""] })} hasSel={hasSel} onPick={startReply} />}
                  {inline && inline.id === cur.id && box && <div className="mbx-inline"><MailCompose key={`in-${cur.id}-${inline.start.subject}`} box={box} start={inline.start} onClose={() => setInline(null)} onQueued={(q) => { comet(); setQueued(q); setInline(null); void loadCounts(); void loadList(); }} onPopOut={(n) => { setInline(null); setCompose(n); }} /></div>}
                </>
              )}
            </div>
          )}
        </article>
      </div>

      <ConfirmSheet ask={ask} onNo={() => { setAsk(null); setForever(null); }} onYes={() => { const a = ask; setAsk(null); if (a && !a.skip) void (a.forever ? doForever() : doAct("trash")); }} />
      {box && <button type="button" className="mbx-fab mbx-glow idle" onClick={() => setCompose({})} aria-label="New email"><Ic k="pen" s={22} /></button>}

      <AnimatePresence>{arrival && <motion.div key={arrival.k} className="mbx-pill" role="status" initial={reduce ? false : { opacity: 0, y: 16, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 8 }} transition={{ type: "spring", stiffness: 380, damping: 30 }}><Ic k="spark" s={16} /><b>{arrival.who}</b><span>{arrival.what}</span></motion.div>}</AnimatePresence>
      <AnimatePresence>{compose && box && <div className="mbx-compose"><MailCompose key="mc" box={box} start={compose} onClose={() => setCompose(null)} onQueued={(q) => { comet(); setQueued(q); void loadCounts(); void loadList(); }} /></div>}</AnimatePresence>
      {queued && box && <UndoBar key={queued.outbox_id} box={box.id} q={queued} onGone={() => { setQueued(null); void loadCounts(); }} onUndone={() => { void loadCounts(); void loadList(); }} />}
    </section>
  );
}
