import { describe, expect, test } from "bun:test";
import { hiddenWords, minutes, parseReport, slaWords, sum } from "./desk_reports_pure";
const good = () => ({ generated_at: "2026-11-23T09:00:00Z", queues_counted: 2, queues_hidden: 2, backlog: { new: 1, open: 1, waiting: 3 },
  daily: { created: Array(14).fill(2), solved: Array(14).fill(1), backlog: [...Array(13).fill(3), 5] },
  first_reply: { cases: 10, replied: 8, unanswered: 2, median_min: 12, p90_min: 95 }, resolution: { solved: 4, median_min: 300, p90_min: 1400 }, reopened_30d: 1,
  priority: { total: 3, in_time: 2, late: 0, waiting: 1 }, queues: [{ queue: "general", created: 3, solved: 1, backlog: 2 }, { queue: "support", created: 7, solved: 3, backlog: 3 }] });
describe("parseReport", () => {
  test("good shape", () => { const r = parseReport(good()); expect(r?.first_reply.p90).toBe(95); expect(r?.queues.length).toBe(2); });
  test("empty desk is real data, medians null", () => {
    const z: any = good(); z.backlog = { new: 0, open: 0, waiting: 0 }; z.daily = { created: Array(14).fill(0), solved: Array(14).fill(0), backlog: Array(14).fill(0) };
    z.first_reply = { cases: 0, replied: 0, unanswered: 0, median_min: null, p90_min: null }; z.resolution = { solved: 0, median_min: null, p90_min: null };
    z.reopened_30d = 0; z.priority = { total: 0, in_time: 0, late: 0, waiting: 0 }; z.queues = [{ queue: "support", created: 0, solved: 0, backlog: 0 }]; z.queues_counted = 1; z.queues_hidden = 3;
    expect(parseReport(z)?.first_reply.median).toBeNull();
    z.first_reply.median_min = 3; expect(parseReport(z)).toBeNull();
  });
  test("bad sums refused", () => {
    for (const f of [(v: any) => (v.first_reply.unanswered = 3), (v: any) => (v.priority.waiting = 0), (v: any) => (v.queues[1].backlog = 4), (v: any) => (v.daily.backlog[13] = 9), (v: any) => (v.queues_hidden = 1), (v: any) => (v.first_reply.p90_min = 1)]) { const v = good(); f(v); expect(parseReport(v)).toBeNull(); }
  });
  test("bad shapes refused", () => {
    for (const f of [(v: any) => (v.daily.created = [1]), (v: any) => (v.queues[0].queue = "secret"), (v: any) => (v.queues[0].subject = "x"), (v: any) => (v.extra = 1), (v: any) => (v.backlog.new = -1), (v: any) => (v.queues = [v.queues[1], v.queues[0]])]) { const v = good(); f(v); expect(parseReport(v)).toBeNull(); }
    expect(parseReport(null)).toBeNull(); expect(parseReport({})).toBeNull();
  });
});
describe("words", () => {
  test("minutes", () => { expect(minutes(null)).toBe("No cases yet"); expect(minutes(0)).toBe("0 min"); expect(minutes(45)).toBe("45 min"); expect(minutes(200)).toBe("3 h 20 min"); expect(minutes(120)).toBe("2 h"); expect(minutes(3000)).toBe("2 d 2 h"); });
  test("notes", () => { const r = parseReport(good())!; expect(hiddenWords(r)).toContain("2 of 4"); expect(slaWords(r.priority)).toContain("2 in time"); expect(sum([1, 2, 3])).toBe(6); });
});
