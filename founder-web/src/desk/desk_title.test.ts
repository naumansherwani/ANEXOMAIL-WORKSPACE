import { describe, expect, test } from "bun:test";
import { fitSpacing, titleLetters } from "./DeskTitle";

describe("command center title pure helpers", () => {
  test("letters get a running index across both lines", () => {
    const t = titleLetters(["AB", "CD EF"]);
    expect(t[0]).toEqual([{ word: "AB", i: 0 }]);
    expect(t[1]).toEqual([{ word: "CD", i: 2 }, { word: "EF", i: 4 }]);
  });
  test("small line spacing fills the big line, never below 2px", () => {
    expect(fitSpacing(400, 8, 100, 15)).toBeCloseTo((400 - 8 - 100) / 14, 5);
    expect(fitSpacing(50, 8, 100, 15)).toBe(2);
    expect(fitSpacing(400, 0, 100, 1)).toBe(2);
  });
});
