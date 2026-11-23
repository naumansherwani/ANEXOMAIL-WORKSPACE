import { describe, expect, test } from "bun:test";
import { headline, leftWords, parseBoard, personWords, signedInWords, sortedPeople, sourceWords } from "./desk_staff_pure";
const good = () => ({ counts: { staff: 4, online: 3, scheduled: 3, on_shift: 2, covered: 1, gap: 1, extra: 1, elevations: 1, breakglass: 0 },
  people: [{ name: "Aisha", role: "agent", online: true, scheduled: true, on_shift: true, signed_in_minutes: 42 }, { name: "Bilal", role: "owner", online: false, scheduled: false, on_shift: false, signed_in_minutes: null }],
  elevations: [{ who: "Aisha", relation: "lead", unit: "Support", source: "elevation", minutes_left: 25 }], spark: [...Array(21).fill(null), 1, 2, 3], trend: "up" });
describe("staff board", () => {
  test("a good answer parses", () => { const p = parseBoard(good())!; expect(p.counts.online).toBe(3); expect(p.people.length).toBe(2); expect(headline(p.counts)).toBe("3 of 4 online. 1 on shift is not online."); });
  test("fail-closed on every wrong shape", () => {
    expect(parseBoard(null)).toBeNull(); expect(parseBoard({})).toBeNull();
    const a = good(); a.counts.online = 9; expect(parseBoard(a)).toBeNull();
    const b = good(); b.counts.covered = 2; expect(parseBoard(b)).toBeNull();
    const c = good(); delete (c.counts as Record<string, unknown>).extra; expect(parseBoard(c)).toBeNull();
    const d = good(); (d.people[0] as Record<string, unknown>).role = "boss"; expect(parseBoard(d)).toBeNull();
    const e = good(); (e.people[0] as Record<string, unknown>).email = "a@b.c"; expect(parseBoard(e)).toBeNull();
    const f = good(); (f.people[0] as Record<string, unknown>).online = "yes"; expect(parseBoard(f)).toBeNull();
    const g = good(); (g.elevations[0] as Record<string, unknown>).source = "standing"; expect(parseBoard(g)).toBeNull();
    const h = good(); h.elevations[0].minutes_left = -1; expect(parseBoard(h)).toBeNull();
    const i = good(); i.spark = [1, 2] as never; expect(parseBoard(i)).toBeNull();
    const k = good(); k.trend = "sideways"; expect(parseBoard(k)).toBeNull();
    const l = good(); l.people = Array(51).fill(l.people[0]); expect(parseBoard(l)).toBeNull();
    const m = good(); m.elevations = Array(21).fill(m.elevations[0]); expect(parseBoard(m)).toBeNull();
  });
  test("headline words for the empty, quiet and covered cases", () => {
    expect(headline({ staff: 0, online: 0, scheduled: 0, on_shift: 0, covered: 0, gap: 0, extra: 0, elevations: 0, breakglass: 0 })).toBe("No active staff account yet.");
    expect(headline({ staff: 2, online: 1, scheduled: 0, on_shift: 0, covered: 0, gap: 0, extra: 0, elevations: 0, breakglass: 0 })).toBe("1 of 2 online. Nobody has a shift right now.");
    expect(headline({ staff: 2, online: 2, scheduled: 2, on_shift: 2, covered: 2, gap: 0, extra: 0, elevations: 0, breakglass: 0 })).toBe("2 of 2 online. Everyone on shift is online.");
    expect(headline({ staff: 3, online: 1, scheduled: 3, on_shift: 3, covered: 1, gap: 2, extra: 0, elevations: 0, breakglass: 0 })).toBe("1 of 3 online. 2 on shift are not online.");
  });
  test("person, time and source words", () => {
    expect(personWords({ name: "A", role: "agent", online: true, scheduled: false, on_shift: false, signed_in_minutes: 1 })).toBe("Online");
    expect(personWords({ name: "A", role: "agent", online: false, scheduled: true, on_shift: true, signed_in_minutes: null })).toBe("On shift, not online");
    expect(personWords({ name: "A", role: "agent", online: true, scheduled: true, on_shift: false, signed_in_minutes: 1 })).toBe("Online, outside shift");
    expect(signedInWords(0)).toBe("Signed in just now"); expect(signedInWords(75)).toBe("Signed in 1 h 15 min ago"); expect(signedInWords(null)).toBe("");
    expect(leftWords(0)).toBe("Ending now"); expect(leftWords(25)).toBe("25 min left"); expect(leftWords(90)).toBe("1 h 30 min left");
    expect(sourceWords("breakglass")).toBe("Break-glass"); expect(sourceWords("elevation")).toBe("Temporary access");
  });
  test("people are sorted gap first, then online, then the rest", () => {
    const p = (name: string, online: boolean, on_shift: boolean) => ({ name, role: "agent" as const, online, scheduled: on_shift, on_shift, signed_in_minutes: null });
    expect(sortedPeople([p("Z", false, false), p("B", true, true), p("A", false, true)]).map((x) => x.name)).toEqual(["A", "B", "Z"]);
  });
});
