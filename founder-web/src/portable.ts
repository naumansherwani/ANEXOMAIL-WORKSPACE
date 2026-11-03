// G5d part 3: the "Portable pin" gauge. A brand-new browser (nothing remembered) can still check the ledger: the server hands over ONE bundle (oldest outside-dated seal =
// the horizon, the head seal, one RFC 9162 consistency proof). The WASM kernel (portable@1) judges all of it; this file only shapes the answer and writes the sentence.
// Wording rule (founder): "time-anchored", never "witnessed". Honest limit shown: rows before the horizon are not covered by this proof.
import type { PortableReport } from "./kernel";

export type PortableView = { text: string; sha: string; rustOk: boolean | null; horizonCp: number; headCp: number };
export type PortableVerdict = { state: "ok" | "warn" | "fail" | "unknown"; text: string; chip?: string };

const HEX64 = /^[0-9a-f]{64}$/;

/** What the route said. "none" = connected but no bundle yet / E138 not installed; null = unusable answer. Anything off-shape is never handed to the kernel. */
export function asPortableView(d: any): PortableView | "none" | null {
  if (!d || typeof d !== "object") return null;
  if (d.connected !== true || d.found !== true) return "none";
  if (typeof d.bundle_text !== "string" || d.bundle_text.length < 2 || d.bundle_text.length > 2_000_000 || typeof d.bundle_sha !== "string" || !HEX64.test(d.bundle_sha)) return null;
  const rc = d.rust_check && typeof d.rust_check.ok === "boolean" ? d.rust_check.ok : null;
  return { text: d.bundle_text, sha: d.bundle_sha, rustOk: rc, horizonCp: Number(d.horizon_cp) || 0, headCp: Number(d.head_cp) || 0 };
}

const STEP: Record<string, string> = {
  sha256: "the bundle does not match its hash", shape: "the bundle is malformed", horizon_note: "the horizon seal signature", head_note: "the head seal signature",
  outside_time: "the outside time evidence", consistency: "the proof that the head extends the horizon",
};

/** view: asPortableView result; report: the kernel's answer (undefined = the kernel could not run, never reported as a refusal). */
export function judgePortable(view: PortableView | "none" | null, report: PortableReport | undefined, fmt: (ms: number) => string, routeDown = false): PortableVerdict {
  if (routeDown) return { state: "fail", text: "Not answering" };
  if (view === null) return { state: "warn", text: "The portable proof came in an unusable shape", chip: "Check" };
  if (view === "none") return { state: "unknown", text: "No portable proof yet (needs a dated seal)" };
  if (!report) return { state: "unknown", text: "The security kernel could not check the portable proof just now" };
  if (!report.ok) return { state: "fail", text: `Portable proof REFUSED by the kernel at ${STEP[report.failed_step ?? ""] ?? "an unknown step"}${report.problem ? `: ${report.problem}` : ""}` };
  if (view.rustOk === false) return { state: "fail", text: "The kernel accepted the portable proof but the server's own re-check refused it: they disagree" };
  const f = report.facts;
  if (!f) return { state: "warn", text: "The kernel accepted the proof but gave no details", chip: "Check" };
  const who = f.bitcoin ? `${f.tsa} time authorit${f.tsa === 1 ? "y" : "ies"} and Bitcoin` : `${f.tsa} time authorities`;
  const gap = f.not_covered_rows > 0 ? ` The first ${f.not_covered_rows} entr${f.not_covered_rows === 1 ? "y is" : "ies are"} before the horizon and not covered.` : "";
  return { state: "ok", chip: "Portable", text: `Any browser can check this: seal #${f.head_cp} extends seal #${f.horizon_cp} unchanged, time-anchored by ${who} (${fmt(f.anchored_ms)}).${gap}` };
}
