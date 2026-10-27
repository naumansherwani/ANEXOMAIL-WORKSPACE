import { readFileSync } from "node:fs";
import { describe, expect, test } from "bun:test";

import { Kernel } from "./kernel/kernel";
import { KERNEL_PIN } from "./kernel/pin.gen";
import { countWords, duration, money, ownText, recipientList } from "./outcomes";

describe("outcomes helpers", () => {
  test("quoted history is not counted or scanned", () => {
    const body = "I will send it by Friday.\n> I will send it by Monday.\n> long old text here";
    expect(ownText(body)).toBe("I will send it by Friday.");
    expect(countWords(body)).toBe(6);
    expect(countWords("")).toBe(0);
  });
  test("recipients are parsed from to/cc/bcc, deduped, lowercased", () => {
    expect(recipientList("A <a@x.com>, b@y.org", "A@X.com; c@z.io", "")).toEqual([
      "a@x.com",
      "b@y.org",
      "c@z.io",
    ]);
    expect(recipientList("not an address", "")).toEqual([]);
  });
  test("money and duration read like a person would say them", () => {
    expect(money(3278, "GBP")).toBe("£32.78");
    expect(money(12000, "GBP")).toBe("£120");
    expect(duration(45)).toBe("45s");
    expect(duration(1180)).toBe("20 min");
    expect(duration(7500)).toBe("2 h 5 min");
  });
  test("end to end: kernel on a real email body ignores the quoted part and prices 10 recipients", async () => {
    const k = await Kernel.load({
      bytes: readFileSync(`public${KERNEL_PIN.url}`),
      sha256: KERNEL_PIN.sha256,
    });
    const body =
      "Hi team,\nI will deliver the report by Friday.\n> I will deliver the report by Monday.";
    expect(k.intentScan(ownText(body), 1_793_102_400, 300).promises.length).toBe(1);
    const c = k.intentCost(countWords(body), 10, 6000);
    expect(c.seconds_total).toBe((Math.ceil((countWords(body) * 60) / 220) + 8) * 10);
  });
});
