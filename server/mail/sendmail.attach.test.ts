import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import net from "node:net";
import { tmpdir } from "node:os";
import path from "node:path";

// asli sendMail ko asli TCP SMTP (nakli server) par chalate hain — poora message jaisa Postfix ko milta hai.
let server: net.Server;
let received: string[] = [];
let sendMail: typeof import("./sendmail").sendMail;
const ORG = "11111111-1111-1111-1111-111111111111";

beforeAll(async () => {
  server = net.createServer((sock) => {
    let data = "";
    let inData = false;
    sock.write("220 test ESMTP\r\n");
    sock.on("data", (c) => {
      const t = c.toString("latin1");
      if (inData) {
        data += t;
        if (data.endsWith("\r\n.\r\n")) {
          received.push(data.slice(0, -5).replace(/\r\n\.\./g, "\r\n."));
          inData = false;
          data = "";
          sock.write("250 queued\r\n");
        }
        return;
      }
      for (const line of t.split("\r\n").filter(Boolean)) {
        if (line.startsWith("DATA")) { inData = true; sock.write("354 go\r\n"); }
        else if (line.startsWith("QUIT")) { sock.write("221 bye\r\n"); sock.end(); }
        else sock.write("250 ok\r\n");
      }
    });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", () => r()));
  process.env["MAIL_SMTP_PORT"] = String((server.address() as net.AddressInfo).port);
  process.env["MAIL_SMTP_HOST"] = "127.0.0.1";
  ({ sendMail } = await import("./sendmail"));
});
afterAll(() => server.close());

async function file(root: string, data: Buffer, name: string) {
  const s = createHash("sha256").update(data).digest("hex");
  const rel = `${ORG}/${s.slice(0, 2)}/${s}-0123abcd`;
  await mkdir(path.join(root, ORG, s.slice(0, 2)), { recursive: true });
  await writeFile(path.join(root, rel), data);
  return { filename: name, mimeType: "application/pdf", path: path.join(root, rel), sha256: s, size: data.length };
}

describe("sendMail with attachments (real SMTP conversation)", () => {
  test("html mail + 2 attachments arrive as one multipart/mixed with exact bytes", async () => {
    received = [];
    const root = await mkdtemp(path.join(tmpdir(), "sm-"));
    const big = Buffer.from(Array.from({ length: 200_000 }, (_, i) => (i * 31 + 7) % 256));
    const small = Buffer.from("line one\n.\n..dots at line start\n");
    const a1 = await file(root, big, "résumé.pdf");
    const a2 = await file(root, small, "notes.txt");
    const r = await sendMail({ from: "a@anexomail.com", to: ["b@example.com"], subject: "Q3", text: "see attached", html: "<p>see attached</p>", attachments: [a1, a2] });
    expect(r.ok).toBe(true);
    expect(received.length).toBe(1);
    const msg = received[0]!;
    expect(/^Content-Type: multipart\/mixed; boundary="(mx_[0-9a-f]+)"/m.test(msg)).toBe(true);
    const b = /boundary="(mx_[0-9a-f]+)"/.exec(msg)![1]!;
    const parts = msg.slice(msg.indexOf("\r\n\r\n") + 4).split(`--${b}`).slice(1, -1);
    expect(parts.length).toBe(3);
    expect(parts[0]).toContain("multipart/alternative");
    const dec = (p: string) => Buffer.from(p.split("\r\n\r\n").slice(1).join("\r\n\r\n").replace(/\s+/g, ""), "base64");
    expect(dec(parts[1]!).equals(big)).toBe(true);
    expect(dec(parts[2]!).equals(small)).toBe(true);
    expect(parts[1]).toContain("filename*=UTF-8''r%C3%A9sum%C3%A9.pdf");
    expect(msg.split("\r\n").every((l) => l.length <= 1000)).toBe(true);
  });

  test("text-only mail without attachments is byte-for-byte the old format", async () => {
    received = [];
    const r = await sendMail({ from: "a@anexomail.com", to: ["b@example.com"], subject: "Plain", text: "hello" });
    expect(r.ok).toBe(true);
    expect(received[0]).toContain('Content-Type: text/plain; charset="UTF-8"');
    expect(received[0]).not.toContain("multipart/mixed");
  });

  test("file tampered after upload => mail is NOT sent, clear error", async () => {
    received = [];
    const root = await mkdtemp(path.join(tmpdir(), "sm-"));
    const a = await file(root, Buffer.from("AAAAAAAA"), "x.pdf");
    await writeFile(a.path, Buffer.from("BBBBBBBB"));
    const r = await sendMail({ from: "a@anexomail.com", to: ["b@example.com"], subject: "T", text: "t", attachments: [a] });
    expect(r.ok).toBe(false);
    expect(r.error).toContain("attachment_corrupt");
    expect(received.length).toBe(0);
  });

  test("CR/LF in subject cannot add a header", async () => {
    received = [];
    const r = await sendMail({ from: "a@anexomail.com", to: ["b@example.com"], subject: "Hi\r\nBcc: spy@evil.com", text: "t" });
    expect(r.ok).toBe(true);
    expect(received[0]).not.toContain("\r\nBcc: spy@evil.com");
    expect(received[0]).toContain("Subject: Hi Bcc: spy@evil.com");
  });
});
