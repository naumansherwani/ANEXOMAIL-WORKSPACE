import { describe, expect, test } from "bun:test";

import { normalizeThread } from "./mail";

describe("normalizeThread", () => {
  test("missing or null lists never crash the page", () => {
    const t = normalizeThread({
      id: "t1",
      subject: null,
      messages: [{ id: "m1", from_address: "a@b.c", to: null, attachments: undefined }, null],
    });
    expect(t.subject).toBe("");
    expect(t.messages.length).toBe(1); // null message is dropped
    expect(t.messages[0]?.to).toEqual([]);
    expect(t.messages[0]?.cc).toEqual([]);
    expect(t.messages[0]?.attachments).toEqual([]);
    expect(t.labels).toEqual([]);
  });
  test("garbage in gives an empty thread, not an exception", () => {
    expect(normalizeThread(undefined).messages).toEqual([]);
    expect(normalizeThread("x").messages).toEqual([]);
  });
  test("good data is kept", () => {
    const t = normalizeThread({
      id: "t2",
      subject: "Hi",
      status: "open",
      messages: [
        {
          id: "m",
          direction: "out",
          from_address: "x@y.z",
          to: ["a@b.c"],
          cc: ["d@e.f"],
          attachments: [{ id: "a1" }],
          sent_at: "2026-10-23T00:00:00Z",
        },
      ],
    });
    expect(t.messages[0]?.direction).toBe("out");
    expect(t.messages[0]?.to).toEqual(["a@b.c"]);
    expect(t.messages[0]?.attachments.length).toBe(1);
  });
});
