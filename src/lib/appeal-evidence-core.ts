/**
 * E72 — appeal: statement (20..20,000 characters) aur saboot ki files ke SAAF (network-free) qaide.
 * Server asli faisla karta hai (Rust `evidence_core.rs` + SQL E72); yeh sirf upload / submit se PEHLE wahi jawab deta hai.
 */
import { extOf, fmtBytes } from "@/lib/mail-attachments-core";

export const STATEMENT_MIN = 20;
export const STATEMENT_MAX = 20_000;

/** Rust `evidence_core.rs` ALLOWED ke saath same rakho. */
export const EVIDENCE_EXT = new Set([
  "png",
  "jpg",
  "jpeg",
  "gif",
  "webp",
  "pdf",
  "txt",
  "csv",
  "md",
  "log",
  "eml",
  "doc",
  "docx",
  "odt",
  "rtf",
  "xls",
  "xlsx",
  "ods",
]);

/** Browser ke `accept` ke liye. */
export const EVIDENCE_ACCEPT = [...EVIDENCE_EXT].map((e) => `.${e}`).join(",");

export type EvidenceLimits = {
  eligible: boolean;
  statement_min: number;
  statement_max: number;
  max_files: number;
  max_file_bytes: number;
  max_total_bytes: number;
  staged_files?: number;
  staged_bytes?: number;
  storage_ready?: boolean;
  scanning?: boolean;
};

export type EvidenceItem = {
  key: string;
  name: string;
  size: number;
  status: "uploading" | "ready" | "error";
  progress: number;
  id?: string;
  error?: string;
  deduped?: boolean;
  scanned?: boolean;
};

export type StatementState = {
  count: number;
  remaining: number;
  tooShort: boolean;
  tooLong: boolean;
  ok: boolean;
  label: string;
};

const nf = new Intl.NumberFormat("en-US");

/** Characters gino (Urdu / emoji bhi ek-ek harf), trim ke baad. `Array.from` surrogate pairs ko ek maanta hai. */
export function countChars(text: string): number {
  return Array.from(text.trim()).length;
}

export function statementState(
  text: string,
  min = STATEMENT_MIN,
  max = STATEMENT_MAX,
): StatementState {
  const count = countChars(text);
  const tooShort = count < min;
  const tooLong = count > max;
  return {
    count,
    remaining: max - count,
    tooShort,
    tooLong,
    ok: !tooShort && !tooLong,
    label: tooLong
      ? `${nf.format(count - max)} over the ${nf.format(max)}-character limit`
      : tooShort
        ? `${nf.format(count)} / ${nf.format(max)} — at least ${nf.format(min)} characters`
        : `${nf.format(count)} / ${nf.format(max)}`,
  };
}

/** Upload se pehle: kya yeh file lag sakti hai? null = theek, warna insaan ko dikhane wali wajah. */
export function precheck(
  file: { name: string; size: number },
  current: EvidenceItem[],
  limits: EvidenceLimits,
): string | null {
  const live = current.filter((a) => a.status !== "error");
  const ext = extOf(file.name);
  if (file.size === 0) return `${file.name} is empty.`;
  if (!EVIDENCE_EXT.has(ext)) {
    return `${file.name}: ${ext ? `.${ext}` : "this"} files are not accepted. Use a screenshot (PNG/JPG), PDF, text, email (.eml) or an Office document.`;
  }
  if (live.length >= limits.max_files) return `You can attach up to ${limits.max_files} files.`;
  if (file.size > limits.max_file_bytes) {
    return `${file.name} is ${fmtBytes(file.size)}. One file can be up to ${fmtBytes(limits.max_file_bytes)}.`;
  }
  const used = live.reduce((n, a) => n + a.size, 0);
  if (used + file.size > limits.max_total_bytes) {
    return `Adding ${file.name} would make the evidence ${fmtBytes(used + file.size)}. The total can be up to ${fmtBytes(limits.max_total_bytes)}.`;
  }
  if (live.some((a) => a.name === file.name && a.size === file.size))
    return `${file.name} is already attached.`;
  return null;
}

/** Server ke error code -> insaani jumla */
export function evidenceErrorText(
  code: string | undefined,
  fallback: string,
  limitBytes?: number,
): string {
  switch (code) {
    case "file_too_large":
      return `This file is too large${limitBytes ? ` (limit ${fmtBytes(limitBytes)})` : ""}.`;
    case "total_too_large":
      return `The evidence files together are too large${limitBytes ? ` (limit ${fmtBytes(limitBytes)})` : ""}.`;
    case "too_many_files":
      return "Too many evidence files. Remove one first.";
    case "rate_limited":
      return "Too many uploads today. Try again tomorrow.";
    case "upload_in_progress":
      return "Another file is still uploading. Wait for it to finish.";
    case "busy":
      return "The server is busy with other uploads. Try again in a minute.";
    case "file_type_blocked":
    case "malware_detected":
      return fallback || "This file can't be accepted.";
    case "nothing_to_appeal":
      return "There is nothing to appeal on this account.";
    case "storage_unavailable":
      return "File storage is not available right now. Try again shortly.";
    case "empty_file":
      return "This file is empty.";
    case "upload_stalled":
      return "The upload stalled. Try again.";
    case "unauthorized":
      return "Please sign in again.";
    case "file_in_appeal":
      return "This file is already part of an appeal and cannot be removed.";
    default:
      return fallback || "Could not attach this file.";
  }
}

export function readyIds(items: EvidenceItem[]): string[] {
  return items.filter((a) => a.status === "ready" && a.id).map((a) => a.id as string);
}

export function anyUploading(items: EvidenceItem[]): boolean {
  return items.some((a) => a.status === "uploading");
}

/** Saaf draft key: appeal ka adhoora text browser mein (sirf is tab/browser mein, server par nahi). */
export const DRAFT_KEY = "ax.appeal.draft.v1";
