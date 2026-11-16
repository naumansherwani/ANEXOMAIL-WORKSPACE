// Q1d-1a a4: the founder's "Mail signing" panel (DKIM). ONE additive mount in the Mail rail; nothing existing is edited. Founder only (the awam mailbox does not carry it).
// Data: E175 health read (keys, DNS state, rotation, policy, blockers) + E170 key rows for the TXT text. Every call goes through the kernel-signed doors.
import { useCallback, useEffect, useState } from "react";
import { dkimKeys, dkimCreate, type DkimRow } from "./mail_api";
import { dkimChain, dkimCheck, dkimHealth, dkimPolicy, dkimProof } from "./dkim_api";
import { RECEIVERS, dnsWords, headline, nextSelector, ratchetWords, rotationWords, type Alg, type Health } from "./dkim_pure";
import "./dkimpanel.css";

export function DkimPanel({ box }: { box: string }) {
  const [chain, setChain] = useState<{ checked: number; broken: number } | "none" | null>(null), [chainBusy, setChainBusy] = useState(false);
  const [open, setOpen] = useState(false), [h, setH] = useState<Health | null | undefined>(undefined), [rows, setRows] = useState<DkimRow[]>([]);
  const [busy, setBusy] = useState(""), [err, setErr] = useState(""), [note, setNote] = useState(""), [rcv, setRcv] = useState<string>("gmail"), [paste, setPaste] = useState("");
  const load = useCallback(() => { Promise.all([dkimHealth(box), dkimKeys(box)]).then(([a, b]) => { setH(a); setRows(b ?? []); }).catch(() => setH(null)); }, [box]);
  useEffect(() => { if (open) load(); }, [open, load]);
  const run = async (tag: string, f: () => Promise<{ ok: boolean; error?: string } & Record<string, unknown>>, done?: (r: any) => string) => {
    setBusy(tag); setErr(""); setNote(""); try { const r = await f(); if (r.ok) { setNote(done ? done(r) : "Done."); load(); } else setErr(String(r.error ?? "Failed")); } catch (e) { setErr(e instanceof Error ? e.message : "Failed"); } setBusy("");
  };
  const make = (alg: Alg) => {
    const sel = nextSelector(alg, rows.map((k) => k.selector));
    if (!sel) { setErr("All 26 selectors of this month are used."); return; }
    void run(alg, async () => dkimCreate(box, sel, alg).then((r) => (r.ok ? { ok: true as const } : r)), () => `Key ${sel} created. Publish its TXT record, then press Check DNS.`);
  };
  const hl = headline(h ?? null), p = h?.policy;
  return (
    <section className="dk" aria-label="Mail signing">
      <button type="button" className="dk-head" aria-expanded={open} onClick={() => setOpen((o) => !o)}><span className="mbx-cap dk-t">Signing (DKIM)</span><i className="dk-dot" data-tone={open ? hl.tone : "idle"} /><span className="dk-sum">{open ? hl.text : "Keys, DNS, proof"}</span></button>
      {open && (
        <div className="dk-body">
          {h === undefined && <p className="dim small">Reading the signing state…</p>}
          {h === null && <p className="mx-warn" role="alert">The signing state is not available. Run the E175 SQL step, then reload.</p>}
          {h && (<>
            {h.keys.length === 0 ? <p className="dk-ok"><b>Nothing is wrong.</b> You just have no key yet. Start here: press <b>New Ed25519 key</b> (touch your key), then <b>New RSA-2048 key</b> (touch again).</p> : h.blockers.map((b) => <p key={b} className="dk-b">{b}</p>)}{h.warnings.map((w) => <p key={w} className="dk-w">{w}</p>)}
            <div className="dk-act">
              <button type="button" className="mx-btn" disabled={!!busy} onClick={() => make("ed25519-sha256")}>{busy === "ed25519-sha256" ? "Touch your key…" : "New Ed25519 key"}</button>
              <button type="button" className="mx-btn alt" disabled={!!busy} onClick={() => make("rsa-sha256")}>{busy === "rsa-sha256" ? "Touch your key…" : "New RSA-2048 key"}</button>
            </div>
            {h.keys.map((k) => { const d = dnsWords(k.dns?.result), r = rows.find((x) => x.id === k.key_id), rot = h.rotation.find((x) => x.key_id === k.key_id); return (
              <div className="dk-key" key={k.key_id}>
                <p><b>{k.selector}</b> <span className="dim">{k.alg === "ed25519-sha256" ? "Ed25519" : "RSA-2048"}</span></p>
                <p className="dk-st" data-tone={d.tone}>{d.text}{k.dns?.dnssec === "secure" ? " (DNSSEC secure)" : ""}</p>
                <p className="dim small">{k.signed_24h} signed in 24 h{k.last_proof ? `, outside receiver: dkim=${k.last_proof}` : ", no outside receiver yet"}{rot ? `. ${rotationWords(rot)}` : ""}</p>
                {r && <div className="dk-dns"><span className="mx-cap">TXT record</span><b>{r.dns_name}</b><code>{r.dns_value}</code><button type="button" className="mx-btn alt" onClick={() => { void navigator.clipboard?.writeText(r.dns_value); }}>Copy value</button></div>}
                <button type="button" className="mx-btn alt" disabled={!!busy} onClick={() => void run("chk" + k.key_id, () => dkimCheck(box, k.key_id), (x) => dnsWords(x.result).text)}>{busy === "chk" + k.key_id ? "Asking DNS…" : "Check DNS"}</button>
              </div>); })}
            {p && (<div className="dk-pol"><span className="mx-cap">Policy (switches only turn on)</span>
              {([["oversign", "Over-sign From, To, Subject, Date, Message-ID", p.require_oversign], ["dual", "Both Ed25519 and RSA keys required", p.require_dual], ["dns_match", "DNS record must be confirmed before sending", p.require_dns_match]] as const).map(([k, t, on]) => (
                <div className="dk-sw" key={k}><span>{t}<small className="dim"> {ratchetWords(on)}</small></span>{!on && <button type="button" className="mx-btn alt" disabled={!!busy} onClick={() => void run("pol" + k, () => dkimPolicy(box, { [k]: true }), () => "Switched on.")}>Turn on (touch)</button>}</div>))}
              <p className="dim small">Fixed rules, set once, nothing for you to do now: a key lasts {p.rotate_days} days, the old DNS record stays {p.overlap_days} days by itself, each signature expires after {p.sig_ttl_days} days. About twice a year this panel will say "new key due" and you press one button.</p></div>)}
            <div className="dk-proof"><span className="mx-cap">Evidence chains</span>
              <div className="dk-row"><button type="button" className="mx-btn alt" disabled={chainBusy} onClick={() => { setChainBusy(true); dkimChain().then((c) => setChain(c ?? "none")).catch(() => setChain("none")).finally(() => setChainBusy(false)); }}>{chainBusy ? "Checking…" : "Check evidence chains"}</button>
                <span className="dim small" role="status">{chain === null ? "Re-checks the DNS, signature and proof logs (hash chains)." : chain === "none" ? "The check door did not answer." : chain.broken === 0 ? `${chain.checked} rows checked, none broken.` : `${chain.broken} of ${chain.checked} rows BROKEN.`}</span></div></div>
            <div className="dk-proof"><span className="mx-cap">Outside receiver proof</span>
              <p className="dim small">Send a mail to the receiver, open Show original, copy the Authentication-Results header and paste it here.</p>
              <div className="dk-row"><select value={rcv} onChange={(e) => setRcv(e.target.value)} aria-label="Receiver">{RECEIVERS.map((x) => <option key={x}>{x}</option>)}</select>
                <button type="button" className="mx-btn alt" disabled={!!busy || paste.trim().length < 20} onClick={() => void run("proof", () => dkimProof(box, rcv, paste), (r) => (r.results as { verdict: string; domain: string }[]).map((x) => `dkim=${x.verdict} (${x.domain})`).join(", "))}>{busy === "proof" ? "Recording…" : "Record proof"}</button></div>
              <textarea value={paste} onChange={(e) => setPaste(e.target.value)} rows={4} spellCheck={false} placeholder="Authentication-Results: mx.google.com; dkim=pass header.i=@... header.s=..." aria-label="Authentication-Results header" />
            </div>
          </>)}
          {err && <p className="mx-warn" role="alert">{err}</p>}{note && <p className="dk-ok" role="status">{note}</p>}
        </div>
      )}
    </section>
  );
}
