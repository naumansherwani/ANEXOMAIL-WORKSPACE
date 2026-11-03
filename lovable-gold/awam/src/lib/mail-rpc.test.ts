import { beforeEach, describe, expect, mock, test } from "bun:test";

// sandbox mein node_modules nahi: react-query in tests mein nahi chahiye
mock.module("react", () => ({ useEffect: () => undefined, useRef: () => ({ current: null }), useState: (v: unknown) => [v, () => undefined], useCallback: (f: unknown) => f, useMemo: (f: () => unknown) => f() }));
mock.module("@tanstack/react-query", () => ({ useQuery: () => null, useMutation: (o: unknown) => o, useQueryClient: () => ({ invalidateQueries: () => undefined }) }));
(globalThis as any).window = { localStorage: { getItem: () => null, setItem: () => undefined, removeItem: () => undefined } };

const { cancelScheduledSend } = await import("./compose");
const { useSendMail } = await import("./mail");

let calls: { url: string; body: unknown }[] = [];
function mockFetch(handler: (url: string) => { status: number; json: unknown }) {
  (globalThis as any).fetch = async (url: string, init?: { body?: string }) => {
    calls.push({ url: url.replace(/^https?:\/\/[^/]+/, ""), body: init?.body ? JSON.parse(init.body) : undefined });
    const r = handler(url);
    return new Response(JSON.stringify(r.json), { status: r.status });
  };
}
beforeEach(() => {
  calls = [];
});

describe("B3 mail send / undo go Rust-first", () => {
  test("undo: Rust answers, Bun is not called", async () => {
    mockFetch(() => ({ status: 200, json: { result: { data: { ok: true } } } }));
    await cancelScheduledSend("11111111-1111-4111-8111-111111111111");
    expect(calls.map((c) => c.url)).toEqual(["/rpc/mail.schedule.cancel"]);
    expect(calls[0]!.body).toEqual({ input: { id: "11111111-1111-4111-8111-111111111111" } });
  });

  test("undo: Rust not installed (404) falls back to the Bun cancel route", async () => {
    mockFetch((u) => (u.includes("/rpc/") ? { status: 404, json: null } : { status: 200, json: { ok: true } }));
    await cancelScheduledSend("11111111-1111-4111-8111-111111111111");
    expect(calls.map((c) => c.url)).toEqual(["/rpc/mail.schedule.cancel", "/api/mail/schedule/11111111-1111-4111-8111-111111111111/cancel"]);
  });

  test("undo: 'already sent' (409) is a real answer, never retried on Bun", async () => {
    mockFetch(() => ({ status: 409, json: { error: { code: "already_sent", message: "already_sent" } } }));
    await expect(cancelScheduledSend("11111111-1111-4111-8111-111111111111")).rejects.toMatchObject({ status: 409 });
    expect(calls.length).toBe(1);
  });

  test("send: Rust smtp_failed (424) is NOT retried on Bun (no duplicate mail)", async () => {
    mockFetch(() => ({ status: 424, json: { error: { code: "smtp_failed", message: "smtp_failed" } } }));
    const m = useSendMail() as unknown as { mutationFn: (p: unknown) => Promise<unknown> };
    await expect(m.mutationFn({ to: "a@b.com", subject: "s", body: "b" })).rejects.toMatchObject({ status: 424 });
    expect(calls.map((c) => c.url)).toEqual(["/rpc/mail.send"]);
  });

  test("send: Rust 501 falls back to Bun /api/mail/send with the same payload", async () => {
    mockFetch((u) => (u.includes("/rpc/") ? { status: 501, json: null } : { status: 200, json: { ok: true } }));
    const m = useSendMail() as unknown as { mutationFn: (p: unknown) => Promise<unknown> };
    await m.mutationFn({ to: "a@b.com", subject: "s", body: "b" });
    expect(calls.map((c) => c.url)).toEqual(["/rpc/mail.send", "/api/mail/send"]);
    expect(calls[1]!.body).toEqual({ to: "a@b.com", subject: "s", body: "b" });
  });
});
