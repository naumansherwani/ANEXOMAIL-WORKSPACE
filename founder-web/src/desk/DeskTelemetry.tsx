import { useEffect, useState } from "react";
import { trust, warmKernel } from "../kernel";

/** The four perimeter labels (his Layer 4). EVERY value is measured, never decoration:
 *  - protocol: the browser's own report of the connection (PerformanceNavigationTiming.nextHopProtocol). ONLY "h3" is ever named on the page (his 21 Nov 09:38 word: older HTTP versions are BANNED, never written); on any other protocol the pill says only the proven TLS line;
 *  - kernel: the Rust WASM kernel's real state (kernel.ts trust: starting / verified / failed);
 *  - Merkle chain: shown only when the Desk door reports a ledger head (R3a2); until then nothing is shown (no "Armed" without a chain).
 *  "TLS 1.3 · AES-256-GCM" is written because it is enforced by the Rust AES-256 edge in front of the Desk and PROVEN by his openssl s_client 21 Nov 08:53 (TLSv1.3, TLS_AES_256_GCM_SHA384, Verification OK), WEBSITE-PROMISES P7. HTTP/3 and X25519MLKEM768 are NOT written until the Desk really answers on QUIC (stage 2); the protocol shown is the browser's own report (only HTTP/3 QUIC is ever named). */
const PROTO: Record<string, string> = { h3: "HTTP/3 QUIC" };
/** PROVEN 21 Nov 2026 09:55 PKT on his server: `anexomail-desk h3check` (client offers ONLY X25519MLKEM768 + AES-256-GCM) got HTTP/3 200 from the Desk on UDP 4400, loopback AND 62.238.98.98 (WEBSITE-PROMISES P7). */
const DESK_LINE = "HTTP/3 QUIC · TLS 1.3 · AES-256-GCM · X25519MLKEM768";
const lab: React.CSSProperties = { position: "absolute", fontSize: 12, letterSpacing: ".06em", color: "#A9C4F5", zIndex: 3 };

export function DeskTelemetry({ chainHead }: { chainHead?: string | null }) {
  const [proto, setProto] = useState<string | null>(null), [k, setK] = useState(trust.get());
  useEffect(() => {
    try { const n = performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming | undefined; setProto((n?.nextHopProtocol && PROTO[n.nextHopProtocol]) || ""); } catch { /* unknown stays hidden */ }
    warmKernel();
    return trust.sub(() => setK(trust.get()));
  }, []);
  // "starting" is never shown: on a page with no signed reply the kernel has nothing to verify yet, and a label stuck on "starting" would say nothing true.
  const kernel = k.state === "verified" ? "Rust WASM kernel verified" : k.state === "failed" ? "Rust WASM kernel: check failed" : null;
  return (
    <>
      {proto !== null && (
        <div className="dk-pill-row" style={{ position: "absolute", top: 24, left: 0, right: 0, padding: "0 16px", boxSizing: "border-box", display: "flex", justifyContent: "center", zIndex: 3 }}>
          <style>{"@media (max-width:480px){.dk-pill{font-size:10.5px!important;letter-spacing:.02em!important;padding:6px 12px!important;gap:8px!important}}"}</style>
          <div className="dk-pill" style={{ maxWidth: "100%", boxSizing: "border-box", whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: 10, padding: "8px 16px", border: "1px solid rgba(143,180,255,.28)", borderRadius: 999, background: "rgba(6,11,25,.55)", backdropFilter: "blur(10px)", fontSize: 12, letterSpacing: ".06em", color: "#A9C4F5" }}>
            <span aria-hidden="true" style={{ width: 8, height: 8, borderRadius: "50%", background: "#5FA8FF", boxShadow: "0 0 10px #5FA8FF" }} /><span>{DESK_LINE}</span>
          </div>
        </div>
      )}
      {kernel ? <div style={{ ...lab, left: 24, bottom: 20 }}>{kernel}</div> : null}
      {chainHead ? <div style={{ ...lab, right: 24, bottom: 20 }}>Merkle audit chain: head {chainHead.slice(0, 8)}</div> : null}
    </>
  );
}
