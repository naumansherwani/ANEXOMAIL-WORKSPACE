import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { deviceStatus } from "./api";
import { trust } from "./kernel";

// The one place that says whether you can trust what you are looking at. Every line is a real check of this browser's session.
// F2b: the signature row is live. It turns green only after the WASM kernel (Rust, Ed25519, pinned key) has verified a response in this browser.
export function Trust({ go }: { go: (v: string) => void }) {
  const [open, setOpen] = useState(false), ref = useRef<HTMLDivElement>(null), ds = deviceStatus(), ks = useSyncExternalStore(trust.sub, () => trust.get().state), kd = trust.get().detail;
  useEffect(() => {
    if (!open) return;
    const away = (e: PointerEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("pointerdown", away); document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("pointerdown", away); document.removeEventListener("keydown", esc); };
  }, [open]);
  const dev = ds.mode === "device" ? { s: "ok", t: "Device approved", d: ds.label } : ds.mode === "legacy" ? { s: "warn", t: "Device approval is not active on the server yet", d: "Run the founder install step on the server." } : { s: "unknown", t: "Checking this device…", d: "" };
  const rows = [
    dev,
    { s: "ok", t: "Writes are signed", d: "Every change needs a per-session request signature; the server refuses unsigned writes." },
    ks === "verified" ? { s: "ok", t: "Responses are verified in this browser", d: "Every answer is checked by the WASM kernel against the server's pinned Ed25519 key before it is shown." }
      : ks === "failed" ? { s: "fail", t: "An answer failed verification and was hidden", d: kd }
      : { s: "unknown", t: "Starting the security kernel…", d: "" },
  ];
  const worst = rows.some((r) => r.s === "fail") ? "fail" : rows.some((r) => r.s === "warn" || r.s === "unknown") ? "warn" : "ok";
  return (
    <div className="trust" ref={ref}>
      <button className="trustbtn" aria-expanded={open} aria-haspopup="dialog" onClick={() => setOpen((v) => !v)}><span className={`sdot ${worst}`} /><span className="tt">{worst === "ok" ? "Trusted" : "Review"}</span></button>
      {open && <div className="tpop" role="dialog" aria-label="Trust">
        <h3>What you can trust right now</h3>
        {rows.map((r) => <div className="trow" key={r.t}><span className={`sdot ${r.s}`} /><div><b>{r.t}</b>{r.d && <span>{r.d}</span>}</div></div>)}
        <button className="mi" onClick={() => { setOpen(false); go("audit"); }}>Open audit ledger</button>
      </div>}
    </div>
  );
}
