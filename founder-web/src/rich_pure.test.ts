import { describe, expect, test } from "bun:test";
import { cleanName, fill, htmlIsEmpty, knownVars, pickSignature, placeholders, slashMatches, textToHtml } from "./rich_pure";
import { sendTarget } from "./mail_pure";
describe("rich_pure (twin of fmail_rich.rs)", () => {
  test("names", () => { expect(cleanName(" /Thanks-1 ")).toBe("thanks-1"); expect(cleanName("a b")).toBeNull(); expect(cleanName("")).toBeNull(); expect(cleanName("x".repeat(41))).toBeNull(); });
  test("placeholders in order, no repeats", () => { expect(placeholders("Hi {first_name}, {x} {first_name} {Bad} {}")).toEqual(["first_name", "x"]); });
  test("fill: known filled, unknown stays and is reported, a value cannot bring a new placeholder", () => {
    const r = fill("Hi {first_name}, {offer}", { first_name: "Ali {offer}" }); expect(r.text).toBe("Hi Ali {offer}, {offer}"); expect(r.open).toEqual(["offer"]);
    expect(fill("{a}", { a: "" }).open).toEqual(["a"]);
  });
  test("known vars", () => { const v = knownVars({ toName: "Ali Khan", myName: "Nauman", now: new Date(2026, 10, 20) }); expect(v).toEqual({ first_name: "Ali", my_name: "Nauman", date: "20 Nov 2026" }); });
  test("slash", () => { expect(slashMatches("/th", ["thanks", "other", "nothing", "zzz"])).toEqual(["thanks", "other", "nothing"]); expect(slashMatches("", ["a"])).toEqual(["a"]); });
  test("signature per From, else default", () => { const s = [{ from: "", fallback: true, id: 1 }, { from: "A@x.com", fallback: false, id: 2 }]; expect(pickSignature(s, "a@x.com")?.id).toBe(2); expect(pickSignature(s, "b@x.com")?.id).toBe(1); expect(pickSignature([{ from: "q@x.com", fallback: false }], "b@x.com")).toBeNull(); });
  test("text to html escapes and links only http(s)", () => { expect(textToHtml("a<b>\nsee https://x.com/p.\n\njavascript:alert(1)")).toBe('<p>a&lt;b&gt;<br>see <a href="https://x.com/p">https://x.com/p</a>.</p><p>javascript:alert(1)</p>'); });
  test("empty html", () => { expect(htmlIsEmpty("<p></p><p>&nbsp; </p>")).toBe(true); expect(htmlIsEmpty("<p>x</p>")).toBe(false); });
  test("send target: html binds only when present (old golden vectors unchanged)", async () => {
    const c = { to: ["a@x.com"], cc: [], bcc: [], subject: "Hi", text: "body" };
    expect(await sendTarget("mb1", c, "")).toBe("9ffbc152919d43cc0c97cc688c722fb24361db540ebde020685ca9e6fe36f523");
    expect(await sendTarget("mb1", { ...c, html: "" }, "")).toBe("9ffbc152919d43cc0c97cc688c722fb24361db540ebde020685ca9e6fe36f523");
    expect(await sendTarget("mb1", { ...c, html: "<p>body</p>" }, "")).not.toBe("9ffbc152919d43cc0c97cc688c722fb24361db540ebde020685ca9e6fe36f523");
  });
});
