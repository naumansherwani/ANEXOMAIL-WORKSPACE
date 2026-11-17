import { describe, expect, test } from "bun:test";
import { addText, asciiDomain, chipOf, chipsOf, cleanAddr, cleanName, explain, joinChips, label, looksComplete, parseAddrs, pieces, removeChip, takenMap } from "./recipients";

describe("recipients: the address grammar of the compose form", () => {
  test("a plain address becomes a lower-case chip", () => {
    const c = chipOf(" Hostflow.AI+x@Gmail.COM "); expect(c.addr).toBe("hostflow.ai+x@gmail.com"); expect(c.reason).toBe(""); expect(c.raw).toBe("hostflow.ai+x@gmail.com");
  });
  test("Name <addr> keeps the name for display and the address for the server", () => {
    const c = chipOf("Nauman Sherwani <n@x.com>"); expect(c.addr).toBe("n@x.com"); expect(c.name).toBe("Nauman Sherwani"); expect(label(c)).toBe("Nauman Sherwani"); expect(c.raw).toBe("Nauman Sherwani <n@x.com>");
  });
  test("a quoted name with a comma stays ONE chip and survives a round trip", () => {
    const list = chipsOf('"Doe, John" <j@x.com>, b@y.org'); expect(list.length).toBe(2); expect(list[0].addr).toBe("j@x.com"); expect(list[0].name).toBe("Doe, John");
    const again = chipsOf(joinChips(list)); expect(again.map((c) => c.addr)).toEqual(["j@x.com", "b@y.org"]); expect(again[0].name).toBe("Doe, John");
  });
  test("separators: comma, semicolon, new line and spaces", () => {
    expect(chipsOf("a@x.com, b@y.org; c@z.net\nd@w.io e@v.co").map((c) => c.addr)).toEqual(["a@x.com", "b@y.org", "c@z.net", "d@w.io", "e@v.co"]);
  });
  test("the old parseAddrs test still holds (bare <addr> and a bad word)", () => {
    expect(parseAddrs("A@x.com, b@y.org; a@x.com <c@z.net> nope")).toEqual({ ok: ["a@x.com", "b@y.org", "c@z.net"], bad: ["nope"] });
  });
  test("every refusal has a reason in plain words", () => {
    const cases: [string, string][] = [["nope", "Missing @"], ["a@@b.com", "More than one @"], ["@x.com", "Nothing before the @"], ["a@", "Nothing after the @"], ["a@b", "The domain needs a dot, like example.com"],
      ["a b@x.com", "A space or special character is not allowed before the @"], ["a@x..com", "The domain has an empty part"], ["a@-x.com", "A domain part cannot start or end with a dash"], ["a@x.123", "The ending after the last dot is not valid"],
      ['"a"@x.com', "Quoted addresses are not accepted"], ["a@[127.0.0.1]", "An IP address instead of a domain is not accepted"], [".a@x.com", "A dot cannot start, end or double up before the @"], ["é@x.com", "Letters outside English before the @ are not supported yet"]];
    for (const [s, why] of cases) { expect(cleanAddr(s)).toBeNull(); expect(explain(s)).toBe(why); }
    expect(explain("a@" + "x".repeat(300) + ".com")).not.toBe("Not a valid address");
  });
  test("an internationalised domain becomes punycode, the server only ever sees ASCII", () => {
    expect(asciiDomain("münchen.de")).toBe("xn--mnchen-3ya.de"); expect(cleanAddr("a@MÜNCHEN.de")).toBe("a@xn--mnchen-3ya.de"); expect(cleanAddr("a@例え.jp")).toMatch(/^a@xn--.+\.jp$/);
  });
  test("control, zero-width and bidi characters never enter a chip or a name (spoofing)", () => {
    expect(cleanAddr("a​@x.com")).toBe("a@x.com"); expect(cleanAddr("a@x.com\r\nBcc: z@z.com")).toBeNull();
    expect(cleanName('Bo‮b "x" <y>\\')).toBe("Bob x y"); expect(chipOf("x\u0007y@z.com").addr).toBe("xy@z.com");
  });
  test("a name that is itself an address does not hide the real one", () => {
    const c = chipOf("boss@bank.com <evil@x.com>"); expect(c.addr).toBe("evil@x.com"); expect(c.name).toBe("");
  });
  test("pieces keeps angle brackets and quotes together", () => {
    expect(pieces('"A, B" <a@x.com>; <c@y.org>')).toEqual(['"A, B" <a@x.com>', "<c@y.org>"]);
  });
  test("addText: duplicates are said, not silent, inside a field and across fields", () => {
    const first = addText([], "a@x.com, b@y.org", "To", {}); expect(first.added.length).toBe(2);
    const dup = addText(first.chips, "A@X.com c@z.net", "To", { "a@x.com": "To", "b@y.org": "To" }); expect(dup.added.map((c) => c.addr)).toEqual(["c@z.net"]); expect(dup.skipped).toEqual([{ piece: "a@x.com", reason: "Already in To" }]);
    const cross = addText([], "a@x.com", "Cc", { "a@x.com": "To" }); expect(cross.chips.length).toBe(0); expect(cross.skipped[0].reason).toBe("Already in To");
  });
  test("a bad piece is still added as a red chip (so the person sees and fixes it) and blocks nothing silently", () => {
    const r = addText([], "ok@x.com nope", "To", {}); expect(r.chips.map((c) => c.addr)).toEqual(["ok@x.com", null]); expect(r.chips[1].reason).toBe("Missing @");
  });
  test("removeChip by address or by raw text; takenMap across To/Cc/Bcc; looksComplete", () => {
    const c = chipsOf("a@x.com, nope"); expect(removeChip(c, "a@x.com").map((x) => x.raw)).toEqual(["nope"]); expect(removeChip(c, "nope").map((x) => x.raw)).toEqual(["a@x.com"]);
    expect(takenMap({ To: "a@x.com", Cc: "b@y.org, a@x.com", Bcc: "" })).toEqual({ "a@x.com": "To", "b@y.org": "Cc" });
    expect(looksComplete("a@x.com")).toBe(true); expect(looksComplete("john smith")).toBe(false); expect(looksComplete('"x" <a@x.com>')).toBe(false); expect(looksComplete("")).toBe(false);
  });
  test("a thousand pasted pieces stay fast and capped by the caller (no crash, no quadratic blow-up)", () => {
    const big = Array.from({ length: 1000 }, (_, i) => `u${i}@x.com`).join(", "); const t = performance.now(); const r = addText([], big, "To", {}); expect(r.added.length).toBe(1000); expect(performance.now() - t).toBeLessThan(500);
  });
});
