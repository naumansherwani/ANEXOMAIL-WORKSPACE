/**
 * G38 — bheji jane wali mail ke attachments: browser ki taraf ke SAAF (network-free) qaide. Server asli faisla karta hai
 * (Rust `attach_core.rs` + SQL E48); yeh sirf user ko upload se PEHLE wahi jawab de deta hai taake bekar upload na ho.
 */

/** Rust `attach_core.rs` BLOCKED_EXT ke saath same rakho (Gmail jaisi list). */
export const BLOCKED_EXT = new Set([
  "ade", "adp", "apk", "appx", "appxbundle", "bat", "cab", "chm", "cmd", "com", "cpl", "dll", "dmg", "ex", "ex_", "exe", "hta", "ins",
  "isp", "iso", "jar", "js", "jse", "lib", "lnk", "mde", "msc", "msi", "msix", "msixbundle", "mst", "nsh", "pif", "ps1", "scr",
  "sct", "shb", "sys", "vb", "vbe", "vbs", "vxd", "wsc", "wsf", "wsh",
]);

export type AttachLimits = { message_cap_bytes: number; max_files: number };

export type AttachItem = {
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

export function extOf(name: string): string {
  const clean = name.trim().replace(/[. ]+$/, "");
  const i = clean.lastIndexOf(".");
  return i > 0 ? clean.slice(i + 1).toLowerCase() : "";
}

export function fmtBytes(n: number): string {
  if (!Number.isFinite(n) || n < 0) return "—";
  if (n < 1000) return `${n} B`;
  if (n < 1_000_000) return `${(n / 1000).toFixed(n < 10_000 ? 1 : 0)} kB`;
  return `${(n / 1_000_000).toFixed(n < 10_000_000 ? 1 : 0)} MB`;
}

/** Upload se pehle: kya yeh file lag sakti hai? null = theek, warna insaan ko dikhane wali wajah. */
export function precheck(file: { name: string; size: number }, current: AttachItem[], limits: AttachLimits): string | null {
  const live = current.filter((a) => a.status !== "error");
  if (file.size === 0) return `${file.name} is empty.`;
  if (BLOCKED_EXT.has(extOf(file.name))) {
    return `${file.name}: .${extOf(file.name)} files can't be sent because they can run on the receiver's computer. Put it in a .zip if you really need to send it.`;
  }
  if (live.length >= limits.max_files) return `You can attach up to ${limits.max_files} files to one message.`;
  if (file.size > limits.message_cap_bytes) {
    return `${file.name} is ${fmtBytes(file.size)}. One message can carry up to ${fmtBytes(limits.message_cap_bytes)}.`;
  }
  const used = live.reduce((n, a) => n + a.size, 0);
  if (used + file.size > limits.message_cap_bytes) {
    return `Adding ${file.name} would make this message ${fmtBytes(used + file.size)}. One message can carry up to ${fmtBytes(limits.message_cap_bytes)} in total.`;
  }
  return null;
}

/** Server ke error code -> insaani jumla */
export function attachErrorText(code: string | undefined, fallback: string, limitBytes?: number): string {
  switch (code) {
    case "file_too_large":
    case "attachments_too_large":
      return `Too large for one message${limitBytes ? ` (limit ${fmtBytes(limitBytes)})` : ""}.`;
    case "file_type_blocked":
      return fallback || "This type of file can't be sent.";
    case "malware_detected":
      return fallback || "Blocked: this file looks malicious.";
    case "org_quota_full":
      return "Your workspace attachment storage is full.";
    case "too_many_staged":
      return "Too many files waiting to be sent. Send or remove some first.";
    case "storage_unavailable":
      return "File storage is not available right now. Try again shortly.";
    case "account_blocked":
      return "This account can't send files.";
    case "empty_file":
      return "This file is empty.";
    case "upload_stalled":
      return "The upload stalled. Try again.";
    case "unauthorized":
      return "Please sign in again.";
    default:
      return fallback || "Could not attach this file.";
  }
}

export function readyIds(items: AttachItem[]): string[] {
  return items.filter((a) => a.status === "ready" && a.id).map((a) => a.id as string);
}

export function anyUploading(items: AttachItem[]): boolean {
  return items.some((a) => a.status === "uploading");
}
