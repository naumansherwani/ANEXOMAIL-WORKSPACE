// G5c: the "Time anchor" gauge. The server only DELIVERS the evidence (RFC 3161 tokens, OpenTimestamps proofs); this browser re-derives what each one claims with the
// WASM kernel (anchor@1) and only counts a claim the kernel re-derived itself. Wording rule (founder): "time-anchored", never "witnessed" (no outside party watched the log).
// Honest limit shown on the page: the TSA's CMS signature is checked by the founder server (ring); the kernel checks the digest binding, the times and the signer pin.
export type Ev = { provider: string; kind: "rfc3161" | "ots"; stage: "tsa_token" | "ots_pending" | "ots_bitcoin"; evidence_hex: string; parsed: Record<string, unknown> };
export type AnchorView = { cp_id: number; signed_ms: number; note: string; digest_hex: string; level: string; evidence: Ev[]; pulse: Record<string, any> };
/** kernel = text out of anchor_inspect (null = kernel refused, undefined = kernel could not run). */
export type Checked = { ev: Ev; kernel: string | null | undefined };
export type AnchorVerdict = { state: "ok" | "warn" | "fail" | "unknown"; text: string; chip?: string };

export function asAnchorView(d: any): AnchorView | null {
  if (!d || d.connected !== true || !d.anchor || d.anchor.found !== true || !d.pulse) return null;
  const a = d.anchor;
  if (typeof a.note !== "string" || !/^[0-9a-f]{64}$/.test(a.digest_hex || "") || !Array.isArray(a.evidence)) return null;
  const ev = a.evidence.filter((e: any) => e && /^[0-9a-f]+$/.test(e.evidence_hex || "") && (e.kind === "rfc3161" || e.kind === "ots"));
  return { cp_id: Number(a.cp_id), signed_ms: Number(a.signed_ms), note: a.note, digest_hex: a.digest_hex, level: String(a.level), evidence: ev, pulse: d.pulse };
}

/** Does the kernel's re-derived claim agree with what the server stored? A disagreement is a FAIL (the stored summary would be lying). */
export function claimAgrees(c: Checked): boolean | null {
  if (c.kernel === undefined) return null;
  if (c.kernel === null) return false;
  const p = c.ev.parsed, f = c.kernel.split("|");
  if (c.ev.stage === "tsa_token") return f.length === 5 && f[0] === String(p.gen_time_ms) && f[2] === p.signer_pin;
  if (c.ev.stage === "ots_bitcoin") return f[0] === "bitcoin" && f[1] === String(p.btc_height) && f[2] === p.commit_hex;
  return (f[0] === "pending" || f[0] === "bitcoin") && f[2] === p.commit_hex;
}

export function judgeAnchor(v: AnchorView | null, digestOk: boolean | null, checked: Checked[], fmt: (ms: number) => string, routeDown = false): AnchorVerdict {
  if (routeDown) return { state: "fail", text: "Not answering" };
  if (!v) return { state: "unknown", text: "Install the E124 SQL step (time anchors)", chip: "Install" };
  if (digestOk === false) return { state: "fail", text: "The anchored digest is NOT the hash of the signed note" };
  const bad = checked.filter((c) => claimAgrees(c) === false);
  if (bad.length) return { state: "fail", text: `${bad[0].ev.provider}: the kernel does not get the same claim from the evidence` };
  const na = checked.some((c) => claimAgrees(c) === null) || digestOk === null;
  const tsa = checked.filter((c) => c.ev.stage === "tsa_token" && claimAgrees(c) === true);
  const btc = checked.filter((c) => c.ev.stage === "ots_bitcoin" && claimAgrees(c) === true);
  const pend = checked.filter((c) => c.ev.stage === "ots_pending" && claimAgrees(c) === true);
  const parts: string[] = [];
  if (tsa.length) parts.push(`${tsa.length} TSA, earliest ${fmt(Math.min(...tsa.map((c) => Number(c.ev.parsed.gen_time_ms))))}`);
  if (btc.length) parts.push(`Bitcoin block ${Math.min(...btc.map((c) => Number(c.ev.parsed.btc_height)))}`);
  if (!tsa.length && !btc.length && pend.length) parts.push(`${pend.length} OpenTimestamps proof${pend.length === 1 ? "" : "s"} waiting for Bitcoin`);
  const lvl = v.pulse.level as string, anchored = tsa.length + btc.length > 0;
  const state: AnchorVerdict["state"] = na ? "unknown" : lvl === "fail" ? "fail" : lvl === "warn" ? "warn" : lvl === "off" ? "unknown" : anchored ? "ok" : "warn";
  const head = anchored ? `Seal ${v.cp_id} time-anchored` : `Seal ${v.cp_id} not time-anchored yet`;
  const why = lvl !== "ok" && v.pulse.why ? ` — ${v.pulse.why}` : "";
  return { state, text: `${head}${parts.length ? `: ${parts.join(", ")}` : ""}${na ? " (kernel could not run here)" : ""}${why}`, chip: btc.length && tsa.length ? "Strong" : anchored ? "Anchored" : undefined };
}
