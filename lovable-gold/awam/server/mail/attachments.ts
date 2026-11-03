/**
 * ANEXOMAIL — G38: bheji jane wali mail ke attachments (Bun ka hissa).
 *
 * Rust (`attach_glue.rs`) upload, virus-check, org-ke-andar SHA-256 dedup aur quota sambhalta hai. Yeh file sirf teen kaam karti hai:
 *   1. bhejne se pehle file ids ko DB se parakhna (`mail_attach_stage_check`: sab ids isi user ki, isi org ki, limit ke andar)
 *   2. file ko disk se padhna, SHA-256 DB wale se milana (kharab/badli hui file kabhi nahi jati), aur mojooda sender ke banaye message ko
 *      `multipart/mixed` mein lapetna (mojooda `buildMessage` ko haath nahi lagaya)
 *   3. mail sach-much chali jane ke BAAD `mail_attach_commit` (Sent mein asli rows)
 * Bytes `/mnt/anexomail-box/attachments` par hain (ATTACH_DIR). SQL: docs/cursor-work/sql/E48_outgoing_attachments.sql
 */
import { createHash, randomUUID } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";

export const ATTACH_ROOT = (process.env["ATTACH_DIR"] || "/mnt/anexomail-box/attachments").replace(/\/+$/, "");

export type StagedFile = {
  id: string;
  filename: string;
  mime_type: string | null;
  size_bytes: number;
  sha256: string;
  rel_path: string;
};

export type OutAttachment = { filename: string; mimeType: string; path: string; sha256: string; size: number };

export type LoadResult =
  | { ok: true; files: StagedFile[]; total: number }
  | { ok: false; status: number; error: string; detail?: Record<string, unknown> };

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REL_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[0-9a-f]{2}\/[0-9a-f]{64}-[0-9a-f]{8}$/;

export function relPathValid(rel: string): boolean {
  return REL_RE.test(rel) && rel.split("/")[2]!.startsWith(rel.split("/")[1]!);
}

/** Client se aaya `attachment_ids` -> saaf uuid list (ya error). */
export function normaliseIds(raw: unknown): { ok: true; ids: string[] } | { ok: false; error: string } {
  if (raw === undefined || raw === null || raw === "") return { ok: true, ids: [] };
  if (!Array.isArray(raw)) return { ok: false, error: "attachment_ids_invalid" };
  if (raw.length > 50) return { ok: false, error: "too_many_attachments" };
  const out: string[] = [];
  for (const v of raw) {
    if (typeof v !== "string" || !UUID_RE.test(v)) return { ok: false, error: "attachment_ids_invalid" };
    const id = v.toLowerCase();
    if (!out.includes(id)) out.push(id);
  }
  return { ok: true, ids: out };
}

type Db = { rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: any; error: any }> };

const STATUS: Record<string, number> = {
  attachment_not_found: 400,
  too_many_attachments: 400,
  attachments_too_large: 413,
  account_blocked: 403,
  no_workspace: 409,
  unauthorized: 401,
};

export async function loadStaged(db: Db, orgId: string, userId: string, rawIds: unknown): Promise<LoadResult> {
  const n = normaliseIds(rawIds);
  if (!n.ok) return { ok: false, status: 400, error: n.error };
  if (!n.ids.length) return { ok: true, files: [], total: 0 };
  const { data, error } = await db.rpc("mail_attach_stage_check", { _user: userId, _org: orgId, _ids: n.ids });
  if (error) return { ok: false, status: 503, error: "attachments_unavailable", detail: { message: String(error.message || error).slice(0, 200) } };
  if (!data || data.ok !== true) {
    const code = String(data?.error || "attachments_unavailable");
    const detail: Record<string, unknown> = {};
    for (const k of ["limit_bytes", "total_bytes", "limit"]) if (data && data[k] !== undefined) detail[k] = data[k];
    return { ok: false, status: STATUS[code] ?? 400, error: code, detail };
  }
  const files = (data.files || []) as StagedFile[];
  for (const f of files) if (!relPathValid(String(f.rel_path))) return { ok: false, status: 500, error: "attachment_path_invalid" };
  return { ok: true, files, total: Number(data.total_bytes || 0) };
}

/** Mail chali gayi — ab Sent mein asli rows. Fail ho to mail ka natija nahi badalta (sirf log). */
export async function commitAttached(db: Db, orgId: string, userId: string, ids: string[], messageId: string): Promise<boolean> {
  if (!ids.length) return true;
  try {
    const { data, error } = await db.rpc("mail_attach_commit", { _user: userId, _org: orgId, _ids: ids, _message: messageId });
    if (error || !data || data.ok !== true) {
      console.error("[attach] commit failed:", error?.message || data?.error);
      return false;
    }
    return true;
  } catch (e) {
    console.error("[attach] commit error:", e);
    return false;
  }
}

function cleanMime(m: string | null | undefined): string {
  const v = String(m || "").split(";")[0]!.trim().toLowerCase();
  return /^[a-z0-9][a-z0-9.+-]*\/[a-z0-9][a-z0-9.+_-]*$/.test(v) && v.length <= 100 ? v : "application/octet-stream";
}

function cleanName(n: string): string {
  // eslint-disable-next-line no-control-regex
  const s = String(n || "").replace(/[\u0000-\u001f\u007f​-‏‪-‮⁠-⁩﻿"\\/]/g, "_").trim();
  return s || "file";
}

/** DB ki file list -> disk par parakhi hui OutAttachment (path root ke andar, size + sha256 DB se mel khate hain). */
export async function toOutAttachments(files: StagedFile[], root: string = ATTACH_ROOT): Promise<OutAttachment[]> {
  const out: OutAttachment[] = [];
  for (const f of files) {
    if (!relPathValid(String(f.rel_path))) throw new Error("attachment_path_invalid");
    const full = path.join(root, f.rel_path);
    if (!full.startsWith(root + path.sep)) throw new Error("attachment_path_invalid");
    let st;
    try {
      st = await stat(full);
    } catch {
      throw new Error(`attachment_missing: ${cleanName(f.filename)}`);
    }
    if (!st.isFile() || st.size !== Number(f.size_bytes)) throw new Error(`attachment_changed: ${cleanName(f.filename)}`);
    out.push({ filename: cleanName(f.filename), mimeType: cleanMime(f.mime_type), path: full, sha256: f.sha256, size: st.size });
  }
  return out;
}

function pct(s: string): string {
  return Array.from(new TextEncoder().encode(s))
    .map((b) => (/[A-Za-z0-9\-_.~]/.test(String.fromCharCode(b)) ? String.fromCharCode(b) : "%" + b.toString(16).toUpperCase().padStart(2, "0")))
    .join("");
}

function asciiName(n: string): string {
  return n.replace(/[^\x20-\x7e]/g, "_").replace(/"/g, "_");
}

function b64Lines(buf: Buffer): string {
  const b64 = buf.toString("base64");
  const lines: string[] = [];
  for (let i = 0; i < b64.length; i += 76) lines.push(b64.slice(i, i + 76));
  return lines.join("\r\n");
}

/** Files padho, sha256 milao (badli hui/kharab file par error), `{att, data}` wapas. */
export async function readAttachments(atts: OutAttachment[]): Promise<{ att: OutAttachment; data: Buffer }[]> {
  const out: { att: OutAttachment; data: Buffer }[] = [];
  for (const a of atts) {
    const data = await readFile(a.path);
    if (data.length !== a.size) throw new Error(`attachment_changed: ${a.filename}`);
    const sum = createHash("sha256").update(data).digest("hex");
    if (sum !== a.sha256) throw new Error(`attachment_corrupt: ${a.filename}`);
    out.push({ att: a, data });
  }
  return out;
}

/**
 * `buildMessage` (sendmail.ts) ka bana hua message -> multipart/mixed. Original ka Content-Type / Content-Transfer-Encoding pehle hisse mein
 * chala jata hai (alternative ho ya plain), baqi headers jaise the waise.
 */
export function wrapWithAttachments(base: string, files: { att: OutAttachment; data: Buffer }[]): string {
  if (!files.length) return base;
  const cut = base.indexOf("\r\n\r\n");
  if (cut < 0) throw new Error("message_shape_unexpected");
  const headLines = base.slice(0, cut).split("\r\n");
  const body = base.slice(cut + 4);
  const keep: string[] = [];
  const moved: string[] = [];
  for (const l of headLines) {
    if (/^content-type:/i.test(l) || /^content-transfer-encoding:/i.test(l)) moved.push(l);
    else keep.push(l);
  }
  if (!moved.length) throw new Error("message_shape_unexpected");
  const mx = `mx_${randomUUID().replace(/-/g, "")}`;
  keep.push(`Content-Type: multipart/mixed; boundary="${mx}"`);
  const parts: string[] = [];
  parts.push(`--${mx}\r\n${moved.join("\r\n")}\r\n\r\n${body.replace(/(\r\n)+$/, "")}`);
  for (const { att, data } of files) {
    const n = cleanName(att.filename);
    const asc = asciiName(n);
    const enc = `UTF-8''${pct(n)}`;
    parts.push(
      `--${mx}\r\n` +
        `Content-Type: ${cleanMime(att.mimeType)}; name="${asc}"; name*=${enc}\r\n` +
        `Content-Disposition: attachment; filename="${asc}"; filename*=${enc}\r\n` +
        `Content-Transfer-Encoding: base64\r\n\r\n` +
        b64Lines(data),
    );
  }
  return `${keep.join("\r\n")}\r\n\r\n${parts.join("\r\n")}\r\n--${mx}--\r\n`;
}
