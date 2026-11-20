import { expect, test } from "bun:test";
import { addrKey, attribution, bareSubject, forwardBody, forwardSubject, hasOthers, referencesFor, replyBody, replySubject, replyTargets, splitQuote } from "./reply_pure";
const me = ["Nauman <naumansherwani.founder@anexomail.com>"];
test("addrKey: name, brackets, case", () => { expect(addrKey("Hana <HANA@Example.org>")).toBe("hana@example.org"); expect(addrKey("a@b.com")).toBe("a@b.com"); expect(addrKey("no address")).toBe(""); });
test("subjects: Re once, Fwd once, Re[2], Fw", () => {
  expect(replySubject("Hello")).toBe("Re: Hello"); expect(replySubject("Re: Re: Hello")).toBe("Re: Hello"); expect(replySubject("RE : Hello")).toBe("Re: Hello"); expect(replySubject("Re[2]: Hello")).toBe("Re: Hello");
  expect(forwardSubject("Hello")).toBe("Fwd: Hello"); expect(forwardSubject("Fwd: Fwd: Hello")).toBe("Fwd: Hello"); expect(forwardSubject("Fw: Hello")).toBe("Fwd: Hello"); expect(forwardSubject("Re: Hello")).toBe("Fwd: Hello");
  expect(bareSubject("Re: Fwd: Re: x")).toBe("x"); expect(replySubject("")).toBe("Re:");
});
test("reply = sender only; reply-to wins", () => {
  expect(replyTargets({ from: "Hana <h@x.org>", to: ["a@b.com"], cc: ["c@d.com"], me }, false)).toEqual({ to: ["Hana <h@x.org>"], cc: [] });
  expect(replyTargets({ from: "h@x.org", to: [], cc: [], replyTo: ["list@x.org"], me }, false).to).toEqual(["list@x.org"]);
});
test("reply all: me removed, dupes removed case-insensitive, cc not repeated in to", () => {
  const r = replyTargets({ from: "Hana <h@x.org>", to: ["naumansherwani.founder@anexomail.com", "A@B.com", "a@b.com"], cc: ["H@X.org", "c@d.com", "A <a@b.com>"], me }, true);
  expect(r.to).toEqual(["Hana <h@x.org>", "A@B.com"]); expect(r.cc).toEqual(["c@d.com"]);
});
test("reply all on a mail I sent: still reaches the original To", () => {
  const r = replyTargets({ from: me[0], to: ["a@b.com"], cc: [], me }, true); expect(r.to).toEqual(["a@b.com"]);
  expect(replyTargets({ from: me[0], to: [], cc: [], me }, true).to).toEqual([me[0]]);
});
test("hasOthers only when more than one other person", () => {
  expect(hasOthers({ from: "h@x.org", to: ["naumansherwani.founder@anexomail.com"], cc: [], me })).toBe(false);
  expect(hasOthers({ from: "h@x.org", to: ["naumansherwani.founder@anexomail.com", "a@b.com"], cc: [], me })).toBe(true);
});
test("replyBody quotes every line; nested quotes get one more >; selection replaces the whole mail", () => {
  const b = replyBody({ who: "Hana", date: "20 Nov 2026", text: "Hi\n> old\n\nBye" });
  expect(b).toBe("\n\nOn 20 Nov 2026, Hana wrote:\n> Hi\n>> old\n>\n> Bye");
  const s = replyBody({ who: "Hana", date: "d", text: "WHOLE MAIL", selection: "  just this  " }); expect(s).toContain("> just this"); expect(s).not.toContain("WHOLE");
  expect(replyBody({ who: "H", date: "d", text: "x", selection: "   " })).toContain("> x");
});
test("forward block has the four header lines, Cc only when present, original text kept", () => {
  const f = forwardBody({ from: "Hana <h@x.org>", date: "20 Nov", subject: "Contract", to: ["a@b.com", "c@d.com"], text: "Body\n\n" });
  expect(f).toContain("---------- Forwarded message ----------"); expect(f).toContain("To: a@b.com, c@d.com"); expect(f).not.toContain("Cc:"); expect(f.endsWith("Body\n")).toBe(true);
  expect(forwardBody({ from: "h", date: "d", subject: "s", to: ["a@b.com"], cc: ["z@z.com"], text: "t" })).toContain("Cc: z@z.com");
});
test("splitQuote: Gmail attribution, wrapped attribution, Outlook, forwarded, trailing > block, nothing", () => {
  const g = "Thanks!\n\nOn 20 Nov, Hana wrote:\n> old\n> older"; expect(splitQuote(g).fresh.trim()).toBe("Thanks!"); expect(splitQuote(g).tail).toBe("On 20 Nov, Hana wrote:\n> old\n> older");
  const w = "Ok\nOn Fri, 20 Nov 2026 at 08:00, Hana Ortega <h@x.org>\nwrote:\n> hi"; expect(splitQuote(w).tail).toContain("wrote:");
  expect(splitQuote("Yes\n-----Original Message-----\nFrom: x").tail).toContain("Original Message");
  expect(splitQuote("See below\n---------- Forwarded message ----------\nFrom: x").tail).toContain("Forwarded");
  expect(splitQuote("Reply\n> a\n> b\n\n").tail).toBe("> a\n> b\n\n".replace(/\n+$/, "\n\n"));
  expect(splitQuote("Just text\nno quote").tail).toBeNull(); expect(splitQuote("one\n> only one quoted line").tail).toBeNull();
});
test("splitQuote never loses a character", () => {
  for (const t of ["a\nOn d, h wrote:\n> q", "x\n> a\n> b", "-----Original Message-----\nz", "plain", "", "On d, h wrote:\n> q"]) { const r = splitQuote(t); expect(r.tail === null ? r.fresh : r.fresh.replace(/\n$/, "\n") + "\u0000").toBeDefined(); const joined = r.tail === null ? r.fresh : r.fresh + r.tail; expect(joined.replace(/\s+/g, "")).toBe(t.replace(/\s+/g, "")); }
});
test("a mail that is only a quote folds entirely", () => { const r = splitQuote("On d, h wrote:\n> q"); expect(r.fresh).toBe(""); expect(r.tail).toBe("On d, h wrote:\n> q"); });
test("referencesFor: parent refs + parent id, brackets stripped, no dupes, trimmed to 20 keeping the root", () => {
  expect(referencesFor(["<a@x>", "b@x"], "<c@x>")).toEqual(["a@x", "b@x", "c@x"]); expect(referencesFor([], "c@x")).toEqual(["c@x"]); expect(referencesFor(["a@x", "a@x"], "a@x")).toEqual(["a@x"]); expect(referencesFor([" "], "")).toEqual([]);
  const many = Array.from({ length: 30 }, (_, i) => `m${i}@x`); const r = referencesFor(many, "last@x"); expect(r.length).toBe(20); expect(r[0]).toBe("m0@x"); expect(r[19]).toBe("last@x");
});
test("attribution line", () => expect(attribution("Hana", "20 Nov")).toBe("On 20 Nov, Hana wrote:"));
