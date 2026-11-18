import { expect, test } from "bun:test";
import { arrivalExtra, coalesce, mailPart, MAIL_LIVE, pollMs, readAnswer, shouldFetch, step, titleWith, touchesList } from "./mail_change";

const BOX = "11111111-1111-4111-8111-111111111111";
const ch = (seq: number, kind: string) => ({ seq, kind, folder: null, message: null, thread: null, at: "2026-11-18T00:00:00Z" });
const ans = (o: Record<string, unknown> = {}) => ({ ok: true, head: 5, floor: 0, gap: false, more: false, changes: [], ...o });

test("the gate marker is present", () => { expect(MAIL_LIVE).toBe("mail_live_push"); });
test("mailPart reads only the promised shape", () => {
  expect(mailPart({ mail: { box: BOX, head: 7 } })).toEqual({ box: BOX, head: 7 });
  expect(mailPart({ mail: { box: BOX.toUpperCase(), head: 0 } })).toEqual({ box: BOX, head: 0 });
  for (const bad of [null, {}, { mail: null }, { mail: { box: "x", head: 1 } }, { mail: { box: BOX, head: -1 } }, { mail: { box: BOX, head: 1.5 } }, { mail: { box: BOX, head: "3" } }, { mail: { box: 5, head: 1 } }]) expect(mailPart(bad)).toBeNull();
});
test("readAnswer checks the shape, the kinds and holes", () => {
  const a = readAnswer(ans({ changes: [ch(1, "arrive"), ch(2, "read")] }));
  expect(a.ok).toBe(true); if (a.ok) { expect(a.summary).toEqual({ arrive: 1, read: 1 }); expect(a.changes.length).toBe(2); }
  expect(readAnswer(null).ok).toBe(false); expect(readAnswer({ ok: false }).ok).toBe(false);
  expect(readAnswer(ans({ changes: [ch(1, "bogus")] })).ok).toBe(false);
  expect(readAnswer(ans({ changes: [ch(1, "arrive"), ch(3, "read")] })).ok).toBe(false); // a hole inside one answer
  expect(readAnswer(ans({ head: "5" })).ok).toBe(false);
});
test("shouldFetch: a new head, a lower head (log reset) and the first time all fetch; an equal head does not", () => {
  expect(shouldFetch(null, 3)).toBe(true); expect(shouldFetch(3, 3)).toBe(false); expect(shouldFetch(3, 4)).toBe(true); expect(shouldFetch(5, 2)).toBe(true);
});
test("step: normal catch-up moves the cursor to the last change and asks for one refresh", () => {
  const s = step(2, readAnswer(ans({ head: 4, changes: [ch(3, "arrive"), ch(4, "arrive")] })));
  expect(s).toMatchObject({ cursor: 4, refresh: true, full: false, more: false, arrived: 2 });
});
test("step: nothing new = no refresh; more = the caller asks again", () => {
  expect(step(5, readAnswer(ans())).refresh).toBe(false);
  const s = step(0, readAnswer(ans({ head: 9, more: true, changes: [ch(1, "arrive"), ch(2, "arrive")] })));
  expect(s.more).toBe(true); expect(s.cursor).toBe(2);
});
test("step: a gap, a first start, a wrong shape or a jump after the cursor is a FULL refresh with the cursor at the head, never a silent hole", () => {
  expect(step(2, readAnswer(ans({ gap: true, head: 40 })))).toMatchObject({ cursor: 40, full: true, refresh: true });
  expect(step(null, readAnswer(ans({ head: 12 })))).toMatchObject({ cursor: 12, full: true });
  expect(step(2, { ok: false })).toMatchObject({ full: true, cursor: 2 });
  expect(step(null, { ok: false })).toMatchObject({ full: true, cursor: null }); // the door is down (not installed): the cursor stays unknown, the next try asks for the head again
  expect(step(2, readAnswer(ans({ head: 9, changes: [ch(5, "read")] })))).toMatchObject({ full: true, cursor: 9 });
});
test("touchesList and pollMs and titleWith", () => {
  expect(touchesList({})).toBe(false); expect(touchesList({ move: 1 })).toBe(true);
  expect(pollMs(true)).toBe(30_000); expect(pollMs(false)).toBe(5_000);
  expect(titleWith("Mail", 0)).toBe("Mail"); expect(titleWith("Mail", 3)).toBe("(3) Mail"); expect(titleWith("Mail", 250)).toBe("(99+) Mail");
});
test("coalesce: a burst of five pokes runs ONE refresh, after the last", () => {
  let n = 0; const timers: { f: () => void; id: number }[] = []; let id = 0;
  const c = coalesce(() => { n++; }, 150, (f) => { const t = { f, id: ++id }; timers.push(t); return t.id; }, (h) => { const i = timers.findIndex((t) => t.id === h); if (i >= 0) timers.splice(i, 1); });
  for (let i = 0; i < 5; i++) c.poke();
  expect(timers.length).toBe(1); timers.shift()!.f(); expect(n).toBe(1);
  c.poke(); c.cancel(); expect(timers.length).toBe(0); expect(n).toBe(1);
});
test("arrivalExtra: an arrival the counts missed is announced once, never twice", () => {
  expect(arrivalExtra(2, false)).toBe(2); expect(arrivalExtra(2, true)).toBe(0); expect(arrivalExtra(0, false)).toBe(0); expect(arrivalExtra(-1, false)).toBe(0);
});
