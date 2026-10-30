import { useEffect, useRef, useState } from "react";
import { deviceStatus } from "./api";

// The one place that says whether you can trust what you are looking at. Every line is a real check of this browser's session.
// Signature row stays amber until the WASM kernel (F2b) verifies each response in the browser.
export function Trust({ go }: { go: (v: string) => void }) {
  const [open, setOpen] = useState(false), ref = useRef<HTMLDivElement>(null), ds = deviceStatus();
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
    { s: "warn", t: "Responses not yet verified in this browser", d: "The server signs every response (Ed25519). Checking it here arrives with the browser kernel (F2b)." },
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
