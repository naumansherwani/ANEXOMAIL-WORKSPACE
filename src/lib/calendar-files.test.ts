import { describe, expect, it } from "bun:test";

import { baseEventId, eventFilePrecheck } from "./calendar-files";

const lim = { max_files: 10, cap_bytes: 7_000_000 };

describe("meeting files (client)", () => {
  it("accepts an ordinary file", () => {
    expect(eventFilePrecheck({ name: "agenda.pdf", size: 120_000 }, 0, lim)).toBeNull();
  });
  it("refuses empty, blocked types, too many, too large — with a plain reason", () => {
    expect(eventFilePrecheck({ name: "a.pdf", size: 0 }, 0, lim)).toContain("empty");
    expect(eventFilePrecheck({ name: "setup.EXE", size: 10 }, 0, lim)).toContain(".exe");
    expect(eventFilePrecheck({ name: "x.pdf", size: 10 }, 10, lim)).toContain("up to 10");
    expect(eventFilePrecheck({ name: "big.zip", size: 8_000_000 }, 0, lim)).toContain("up to");
    expect(
      eventFilePrecheck({ name: "big.zip", size: 8_000_000 }, 0, { max_files: 10 }),
    ).toBeNull();
  });
  it("a repeating meeting's day maps to the series id", () => {
    expect(baseEventId("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b~1790000000")).toBe(
      "0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b",
    );
    expect(baseEventId("0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b")).toBe(
      "0b1d2f3a-4c5d-4e6f-8a9b-0c1d2e3f4a5b",
    );
  });
});
