// QLIVE simulation (18 Nov 2026, his order: the behaviours I could not force in his browser are PROVEN here, deterministically).
// A fake mail server (E187 semantics: gapless seq, floor, gap) + a fake live stream drive the REAL mail_api.live(): push, burst, gap, reconnect, fallback (rollback switch = no pings), hidden tab, failed read.
// Timers are scaled 1/100 (150 ms coalesce -> 1.5 ms, 5 s poll -> 50 ms, 30 s safety -> 300 ms) so the whole file runs in about a second.
import { afterAll, beforeAll, beforeEach, expect, mock, test } from "bun:test";

const BOX = "11111111-1111-4111-8111-111111111111";
type Ch = { seq: number; kind: string };
const srv = { head: 0, floor: 0, log: [] as Ch[], inbox: 0, unread: 0, calls: { counts: 0, lanes: 0, changes: 0 }, down: false };
const addMail = (kind = "arrive") => { srv.head += 1; srv.log.push({ seq: srv.head, kind }); if (kind === "arrive") { srv.inbox += 1; srv.unread += 1; } };
const answer = (after: number, limit: number) => {
  const gap = after < srv.floor || after > srv.head;
  const ch = gap ? [] : srv.log.filter((c) => c.seq > after).slice(0, limit).map((c) => ({ ...c, folder: null, message: null, thread: null, at: "2026-11-18T00:00:00Z" }));
  return { ok: true, head: srv.head, floor: srv.floor, gap, more: !gap && srv.log.filter((c) => c.seq > after).length > ch.length, changes: ch };
};
const doc = { hidden: false, ls: new Map<string, Set<() => void>>(), addEventListener(t: string, f: () => void) { (this.ls.get(t) ?? this.ls.set(t, new Set()).get(t)!).add(f); }, removeEventListener(t: string, f: () => void) { this.ls.get(t)?.delete(f); }, fire(t: string) { this.ls.get(t)?.forEach((f) => f()); } };
const mailFns = new Set<(m: { box: string; head: number }) => void>();
const stream = { status: "live" as string, subs: new Set<() => void>() };
const setStatus = (s: string) => { stream.status = s; stream.subs.forEach((f) => f()); };
const ping = () => mailFns.forEach((f) => f({ box: BOX, head: srv.head }));

mock.module("../src/api", () => ({ post: async () => ({ data: null }), get: async (path: string) => {
  if (srv.down) throw new Error("down");
  if (path.startsWith("/founder/v1/mail/counts")) { srv.calls.counts++; return { data: { connected: true, counts: { inbox: { total: srv.inbox, unread: srv.unread } } } }; }
  if (path.startsWith("/founder/v1/mail/lanes")) { srv.calls.lanes++; return { data: { connected: true, feed: { lanes: [], unread: srv.unread, ledger_head: 0, mailboxes_without_key: 0 } } }; }
  if (path.startsWith("/founder/v1/mail/changes")) { srv.calls.changes++; const u = new URL("http://x" + path); return { data: answer(Number(u.searchParams.get("after")), Number(u.searchParams.get("limit"))) }; }
  return { data: null };
} }));
mock.module("../src/kernel", () => ({ rpcAvailable: () => false, mailLedgerCheck: async () => null, anchorCheck: async () => null }));
mock.module("../src/passkey", () => ({ prove: async () => null }));
mock.module("../src/livefeed", () => ({ acquireLive: () => () => {}, onMail: (f: (m: { box: string; head: number }) => void) => { mailFns.add(f); return () => { mailFns.delete(f); }; }, live: { get: () => ({ status: stream.status }), sub: (f: () => void) => { stream.subs.add(f); return () => { stream.subs.delete(f); }; } } }));

const realSet = globalThis.setTimeout;
beforeAll(() => { (globalThis as any).document = doc; (globalThis as any).setTimeout = ((f: () => void, ms?: number) => realSet(f, Math.max(1, (ms ?? 0) / 100))) as typeof setTimeout; });
afterAll(() => { globalThis.setTimeout = realSet; delete (globalThis as any).document; });
beforeEach(() => { Object.assign(srv, { head: 0, floor: 0, log: [], inbox: 0, unread: 0, down: false, calls: { counts: 0, lanes: 0, changes: 0 } }); doc.hidden = false; doc.ls.clear(); mailFns.clear(); stream.subs.clear(); stream.status = "live"; });
const wait = (ms: number) => new Promise((r) => realSet(r, ms));

async function start() {
  const { live } = await import("../src/mail_api");
  const ev: { event: string; data: any }[] = []; const st: string[] = [];
  const stop = live(BOX, (m) => ev.push(m), (s) => st.push(s));
  await wait(40); // first catch-up + first snapshot
  return { ev, st, stop };
}
const kinds = (ev: { event: string }[]) => ev.map((e) => e.event);

test("PUSH: a ping after a new mail refreshes the screen and says 'arrival' (no 5 s wait)", async () => {
  const { ev, stop } = await start(); const n0 = ev.length;
  addMail(); ping(); await wait(25);
  expect(kinds(ev).slice(n0)).toContain("counts"); expect(kinds(ev).slice(n0)).toContain("arrival");
  expect(ev.find((e) => e.event === "arrival")!.data).toMatchObject({ new: 1, inbox_total: 1 });
  stop();
});
test("BURST: ten mails and ten pings make ONE refresh (coalescing), nothing lost", async () => {
  const { ev, stop } = await start(); await wait(10); const before = srv.calls.counts;
  for (let i = 0; i < 10; i++) { addMail(); ping(); }
  await wait(30);
  expect(srv.calls.counts - before).toBeLessThanOrEqual(2); // one burst refresh (+ at most one safety tick)
  expect(ev.filter((e) => e.event === "arrival").reduce((a, e) => a + e.data.new, 0)).toBe(10);
  stop();
});
test("GAP: the log was pruned past the cursor -> a FULL refresh, the cursor jumps to the head, no silent hole", async () => {
  const { ev, stop } = await start(); addMail(); ping(); await wait(25);
  for (let i = 0; i < 5; i++) addMail(); srv.floor = srv.head; srv.log = []; // everything older is gone
  const c0 = srv.calls.counts; ping(); await wait(30);
  expect(srv.calls.counts).toBeGreaterThan(c0); expect([...ev].reverse().find((e) => e.data?.counts)!.data.counts.inbox.total).toBe(6); // the screen shows the truth
  const c1 = srv.calls.changes; addMail(); ping(); await wait(25);
  expect(srv.calls.changes).toBeGreaterThan(c1); expect(ev.some((e) => e.event === "changes")).toBe(true); // and normal catch-up works again from the new head
  stop();
});
test("RECONNECT: mails that arrived while the stream was down are picked up when it comes back", async () => {
  const { ev, stop } = await start(); setStatus("reconnecting");
  addMail(); addMail(); addMail(); // no pings: the stream is down
  await wait(10); setStatus("live"); await wait(30);
  expect(ev.filter((e) => e.event === "arrival").reduce((a, e) => a + e.data.new, 0)).toBe(3);
  stop();
});
test("FALLBACK / ROLLBACK SWITCH (FOUNDER_MAIL_LIVE=off = no pings at all): the 5 s read still brings the new mail", async () => {
  const { ev, stop } = await start(); setStatus("polling");
  addMail(); // never pinged
  await wait(150); // 5 s scaled = 50 ms per poll; the 30 s safety timer is cut to 5 s when the stream drops
  expect(ev.some((e) => e.event === "arrival")).toBe(true);
  stop();
});
test("SAFETY: even while the stream is live and a ping was LOST, the 30 s read catches the mail", async () => {
  const { ev, stop } = await start(); addMail(); // lost ping
  await wait(450); // 30 s scaled = 300 ms
  expect(ev.some((e) => e.event === "arrival")).toBe(true);
  stop();
});
test("HIDDEN TAB: no calls while hidden; becoming visible does one catch-up", async () => {
  const { ev, stop } = await start(); await wait(10); doc.hidden = true; addMail(); ping(); await wait(60);
  const idle = { ...srv.calls }; await wait(60); expect(srv.calls).toEqual(idle); // nothing happens while hidden
  doc.hidden = false; doc.fire("visibilitychange"); await wait(30);
  expect(ev.some((e) => e.event === "arrival")).toBe(true);
  stop();
});
test("FAILED READ: the door is down -> the screen says reconnecting and the mail is NOT lost when it is back", async () => {
  const { ev, st, stop } = await start(); srv.down = true; addMail(); ping(); await wait(30);
  expect(st).toContain("reconnecting"); srv.down = false; ping(); await wait(40);
  expect(ev.some((e) => e.event === "arrival")).toBe(true);
  stop();
});
test("OWN MAILBOX ONLY: a ping for another mailbox does nothing", async () => {
  const { stop } = await start(); await wait(10); const c = srv.calls.changes;
  mailFns.forEach((f) => f({ box: "22222222-2222-4222-8222-222222222222", head: 99 })); await wait(25);
  expect(srv.calls.changes).toBe(c);
  stop();
});
