import { describe, expect, test } from "bun:test";
import { approvalMail, runNotices, type NoticeRow } from "./identity-notice";

const row = (n: number, name: string | null = "Hana Khan"): NoticeRow => ({ account_id: `acc-${n}`, to_email: `p${n}@gmail.com`, display_name: name });

describe("approvalMail", () => {
  test("greets by first name, links sign-in, states the limits, never mentions fingerprints / matches / bans", () => {
    const m = approvalMail("Hana Khan");
    expect(m.text).toContain("Hi Hana,");
    expect(m.text).toContain("https://anexomail.com/auth");
    expect(m.text).toContain("20 people");
    expect(m.text).toContain("50 messages");
    for (const bad of [/finger/i, /match/i, /ban/i, /vault/i, /suspic/i, /hold/i]) expect(m.text + m.subject).not.toMatch(bad);
  });
  test("hostile display names cannot inject lines or markup", () => {
    const m = approvalMail("Evil\r\nBcc: x@y.com <script>");
    expect(m.text.split("\n")[0]).toBe("Hi Evil,");
    expect(m.text).not.toContain("<script>");
  });
  test("no name => plain greeting", () => {
    expect(approvalMail(null).text.startsWith("Hi,\n")).toBe(true);
  });
});

describe("runNotices", () => {
  test("sends each once and reports success to SQL", async () => {
    const log: string[] = [];
    const r = await runNotices({
      pending: async () => [row(1), row(2)],
      send: async (m) => (log.push("send:" + m.to), true),
      done: async (a, ok) => void log.push(`done:${a}:${ok}`),
    });
    expect(r).toEqual({ sent: 2, failed: 0 });
    expect(log).toEqual(["send:p1@gmail.com", "done:acc-1:true", "send:p2@gmail.com", "done:acc-2:true"]);
  });
  test("a failed send is reported as failed (SQL retries later); the others still go out", async () => {
    const done: Array<[string, boolean]> = [];
    const r = await runNotices({
      pending: async () => [row(1), row(2), row(3)],
      send: async (m) => m.to !== "p2@gmail.com",
      done: async (a, ok) => void done.push([a, ok]),
    });
    expect(r).toEqual({ sent: 2, failed: 1 });
    expect(done).toEqual([["acc-1", true], ["acc-2", false], ["acc-3", true]]);
  });
  test("a throwing mailer counts as failed, never crashes the worker", async () => {
    const r = await runNotices({
      pending: async () => [row(1)],
      send: async () => { throw new Error("smtp down"); },
      done: async () => {},
    });
    expect(r).toEqual({ sent: 0, failed: 1 });
  });
  test("SQL unavailable or done() throwing => no crash", async () => {
    expect(await runNotices({ pending: async () => { throw new Error("no fn"); }, send: async () => true, done: async () => {} })).toEqual({ sent: 0, failed: 0 });
    expect(await runNotices({ pending: async () => [row(1)], send: async () => true, done: async () => { throw new Error("x"); } })).toEqual({ sent: 1, failed: 0 });
  });
});
