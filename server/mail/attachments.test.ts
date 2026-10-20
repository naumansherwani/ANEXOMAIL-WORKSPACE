import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { commitAttached, loadStaged, normaliseIds, readAttachments, relPathValid, toOutAttachments, wrapWithAttachments, type StagedFile } from "./attachments";

const ORG = "11111111-1111-1111-1111-111111111111";
const sha = (b: Buffer) => createHash("sha256").update(b).digest("hex");

async function stageOnDisk(root: string, data: Buffer, name = "report.pdf"): Promise<StagedFile> {
  const s = sha(data);
  const rel = `${ORG}/${s.slice(0, 2)}/${s}-0123abcd`;
  await mkdir(path.join(root, ORG, s.slice(0, 2)), { recursive: true });
  await writeFile(path.join(root, rel), data);
  return { id: "22222222-2222-2222-2222-222222222222", filename: name, mime_type: "application/pdf", size_bytes: data.length, sha256: s, rel_path: rel };
}

// kachcha message jaisa sendmail.ts ka buildMessage deta hai
const plain = ["From: a@anexomail.com", "To: b@x.com", "Subject: Hi", "MIME-Version: 1.0", 'Content-Type: text/plain; charset="UTF-8"', "Content-Transfer-Encoding: 8bit", "", "hello body", ""].join("\r\n");
const alt = ["From: a@anexomail.com", "To: b@x.com", "Subject: Hi", "MIME-Version: 1.0", 'Content-Type: multipart/alternative; boundary="ax_1"', "", "--ax_1", "Content-Type: text/plain", "", "t", "--ax_1", "Content-Type: text/html", "", "<p>h</p>", "--ax_1--", ""].join("\r\n");

function parseMixed(msg: string) {
  const ct = /Content-Type: multipart\/mixed; boundary="([^"]+)"/.exec(msg)!;
  const b = ct[1]!;
  const body = msg.slice(msg.indexOf("\r\n\r\n") + 4);
  const parts = body.split(`--${b}`).slice(1, -1).map((p) => p.replace(/^\r\n/, "").replace(/\r\n$/, ""));
  return { b, parts, tail: body.endsWith(`--${b}--\r\n`) };
}

describe("wrapWithAttachments", () => {
  test("plain text mail becomes multipart/mixed, attachment bytes round-trip", async () => {
    const data = Buffer.from(Array.from({ length: 5000 }, (_, i) => (i * 7) % 256));
    const msg = wrapWithAttachments(plain, [{ att: { filename: "report.pdf", mimeType: "application/pdf", path: "x", sha256: sha(data), size: data.length }, data }]);
    const m = parseMixed(msg);
    expect(m.tail).toBe(true);
    expect(m.parts.length).toBe(2);
    expect(m.parts[0]).toContain('Content-Type: text/plain; charset="UTF-8"');
    expect(m.parts[0]).toContain("hello body");
    const head = msg.slice(0, msg.indexOf("\r\n\r\n"));
    expect(head).toContain("From: a@anexomail.com");
    expect(head).toContain("MIME-Version: 1.0");
    expect(head.match(/Content-Type:/gi)!.length).toBe(1); // sirf mixed; text wala hissa pehle part mein chala gaya
    const [h, ...rest] = m.parts[1]!.split("\r\n\r\n");
    expect(h).toContain("Content-Disposition: attachment");
    expect(h).toContain("Content-Transfer-Encoding: base64");
    const b64 = rest.join("\r\n\r\n");
    for (const line of b64.split("\r\n")) expect(line.length).toBeLessThanOrEqual(76);
    expect(Buffer.from(b64.replace(/\r\n/g, ""), "base64").equals(data)).toBe(true);
  });

  test("alternative (html) mail keeps its own nested boundary intact", () => {
    const data = Buffer.from("PK\x03\x04zip");
    const msg = wrapWithAttachments(alt, [{ att: { filename: "a.zip", mimeType: "application/zip", path: "x", sha256: sha(data), size: data.length }, data }]);
    const m = parseMixed(msg);
    expect(m.parts[0]).toContain('Content-Type: multipart/alternative; boundary="ax_1"');
    expect(m.parts[0]).toContain("--ax_1--");
    expect(m.b).not.toBe("ax_1");
  });

  test("hostile file names cannot inject headers or break quoting", () => {
    const data = Buffer.from("x");
    const evil = 'a"\r\nBcc: spy@evil.com\r\n.pdf';
    const msg = wrapWithAttachments(plain, [{ att: { filename: evil, mimeType: "text/plain\r\nX: y", path: "x", sha256: sha(data), size: 1 }, data }]);
    expect(msg).not.toContain("\r\nBcc: spy@evil.com");
    expect(msg).toContain("Content-Type: application/octet-stream; name=");
    const disp = /Content-Disposition: ([^\r\n]+)/.exec(msg)![1]!;
    expect(disp.startsWith("attachment; filename=")).toBe(true);
  });

  test("non-ASCII name goes out as RFC 2231 with ASCII fallback", () => {
    const data = Buffer.from("x");
    const msg = wrapWithAttachments(plain, [{ att: { filename: "résumé 2026.pdf", mimeType: "application/pdf", path: "x", sha256: sha(data), size: 1 }, data }]);
    expect(msg).toContain('filename="r_sum_ 2026.pdf"');
    expect(msg).toContain("filename*=UTF-8''r%C3%A9sum%C3%A9%202026.pdf");
  });

  test("no attachments => message untouched", () => {
    expect(wrapWithAttachments(plain, [])).toBe(plain);
  });
});

describe("disk checks", () => {
  test("good file passes, bytes read back match the DB hash", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "att-"));
    const f = await stageOnDisk(root, Buffer.from("hello attachments"));
    const out = await toOutAttachments([f], root);
    const read = await readAttachments(out);
    expect(read[0]!.data.toString()).toBe("hello attachments");
  });
  test("file changed on disk (same size, different bytes) is refused", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "att-"));
    const f = await stageOnDisk(root, Buffer.from("AAAAAAAA"));
    await writeFile(path.join(root, f.rel_path), Buffer.from("BBBBBBBB"));
    const out = await toOutAttachments([f], root);
    await expect(readAttachments(out)).rejects.toThrow("attachment_corrupt");
  });
  test("size changed is refused before reading", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "att-"));
    const f = await stageOnDisk(root, Buffer.from("AAAAAAAA"));
    await writeFile(path.join(root, f.rel_path), Buffer.from("A"));
    await expect(toOutAttachments([f], root)).rejects.toThrow("attachment_changed");
  });
  test("missing file is a clear error", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "att-"));
    const f = await stageOnDisk(root, Buffer.from("zzz"));
    await Bun.write(path.join(root, f.rel_path), "");
    const { rm } = await import("node:fs/promises");
    await rm(path.join(root, f.rel_path));
    await expect(toOutAttachments([f], root)).rejects.toThrow("attachment_missing");
  });
  test("path traversal in rel_path is refused", async () => {
    const root = await mkdtemp(path.join(tmpdir(), "att-"));
    const bad: StagedFile = { id: "x", filename: "p", mime_type: null, size_bytes: 1, sha256: "a".repeat(64), rel_path: `../../etc/passwd` };
    await expect(toOutAttachments([bad], root)).rejects.toThrow("attachment_path_invalid");
    expect(relPathValid(`${ORG}/aa/${"a".repeat(64)}-0123abcd`)).toBe(true);
    expect(relPathValid(`${ORG}/bb/${"a".repeat(64)}-0123abcd`)).toBe(false);
    expect(relPathValid(`/${ORG}/aa/${"a".repeat(64)}-0123abcd`)).toBe(false);
  });
});

describe("ids + db", () => {
  test("normaliseIds", () => {
    expect(normaliseIds(undefined)).toEqual({ ok: true, ids: [] });
    expect(normaliseIds(["22222222-2222-2222-2222-222222222222", "22222222-2222-2222-2222-222222222222"])).toEqual({ ok: true, ids: ["22222222-2222-2222-2222-222222222222"] });
    expect(normaliseIds("abc").ok).toBe(false);
    expect(normaliseIds(["not-uuid"]).ok).toBe(false);
    expect(normaliseIds(Array.from({ length: 51 }, () => "22222222-2222-2222-2222-222222222222")).ok).toBe(false);
  });
  test("loadStaged maps DB errors to HTTP codes", async () => {
    const mk = (data: any, error: any = null) => ({ rpc: async () => ({ data, error }) });
    const id = ["22222222-2222-2222-2222-222222222222"];
    expect(await loadStaged(mk({ ok: false, error: "attachments_too_large", limit_bytes: 7000000, total_bytes: 9000000 }), ORG, "u", id)).toMatchObject({ ok: false, status: 413, error: "attachments_too_large" });
    expect(await loadStaged(mk({ ok: false, error: "attachment_not_found" }), ORG, "u", id)).toMatchObject({ ok: false, status: 400 });
    expect(await loadStaged(mk({ ok: false, error: "account_blocked" }), ORG, "u", id)).toMatchObject({ ok: false, status: 403 });
    expect(await loadStaged(mk(null, { message: "boom" }), ORG, "u", id)).toMatchObject({ ok: false, status: 503 });
    expect(await loadStaged(mk(null), ORG, "u", [])).toMatchObject({ ok: true, files: [] });
    const bad = await loadStaged(mk({ ok: true, files: [{ rel_path: "../x", filename: "a", size_bytes: 1, sha256: "" }], total_bytes: 1 }), ORG, "u", id);
    expect(bad).toMatchObject({ ok: false, error: "attachment_path_invalid" });
  });
  test("commitAttached never throws and reports failure", async () => {
    expect(await commitAttached({ rpc: async () => ({ data: { ok: true }, error: null }) }, ORG, "u", ["x"], "m")).toBe(true);
    expect(await commitAttached({ rpc: async () => ({ data: { ok: false, error: "message_not_in_org" }, error: null }) }, ORG, "u", ["x"], "m")).toBe(false);
    expect(await commitAttached({ rpc: async () => { throw new Error("net"); } }, ORG, "u", ["x"], "m")).toBe(false);
    expect(await commitAttached({ rpc: async () => ({ data: null, error: null }) }, ORG, "u", [], "m")).toBe(true);
  });
});
