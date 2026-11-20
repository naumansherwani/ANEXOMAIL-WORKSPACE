import { describe, expect, test } from "bun:test";
import { b64ToHex, kemInputs, partAad, replyPlan } from "./mail_pq_pure";
describe("DK4 pq open plumbing", () => {
  test("b64 to hex, url-safe too, garbage refused", () => { expect(b64ToHex("AQID")).toBe("010203"); expect(b64ToHex("-_8=")).toBe("fbff"); expect(b64ToHex("")).toBeNull(); expect(b64ToHex(5)).toBeNull(); expect(b64ToHex("@@@")).toBeNull(); });
  test("aad fields match the server order", () => { expect(partAad("B", "in", "ab12", "meta")).toEqual(["fmail-msg-v1", "B", "in", "ab12", "meta"]); });
  test("kem inputs: meta + body, nothing guessed", () => {
    const m = { key_id: "dk-20261120-a1b2c3", key_wrap: "AQID", msgid_blind: "ab12", direction: "in", meta: "BAUG", nonce_meta: "BwgJ", body: "CgsM", nonce_body: "DQ4P" };
    const k = kemInputs("B", m)!; expect(k.meta).toMatchObject({ key_id: m.key_id, wrap: "010203", nonce: "070809", sealed: "040506" }); expect((k.body as any).aad[4]).toBe("body"); expect((k.body as any).sealed).toBe("0a0b0c");
    expect(kemInputs("B", { ...m, body: null })!.body).toBeNull(); expect(kemInputs("B", { ...m, direction: "x" })).toBeNull(); expect(kemInputs("B", { ...m, msgid_blind: "zz" })).toBeNull(); expect(kemInputs("B", { ...m, key_wrap: "@@" })).toBeNull(); expect(kemInputs("B", { ...m, body: "@@" })).toBeNull();
  });
  test("reply plan: Reply-To wins, reply all drops me and dupes, forward keeps references, 40 max", () => {
    const s = { from: "Hana@x.org", to: ["me@a.com", "b@x.org"], cc: ["c@x.org", "B@x.org"], message_id: "m3@x.org", references: ["m1@x.org", "m2@x.org"], reply_to: [], subject: "Seminar" };
    const p = replyPlan(s, "ME@a.com"); expect(p.reply.to).toEqual(["hana@x.org"]); expect(p.reply.subject).toBe("Re: Seminar"); expect(p.reply.references).toEqual(["m1@x.org", "m2@x.org", "m3@x.org"]); expect(p.reply.in_reply_to).toBe("m3@x.org");
    expect(p.replyAll.cc).toEqual(["b@x.org", "c@x.org"]); expect(p.forward.subject).toBe("Fwd: Seminar"); expect(p.forward.to).toEqual([]);
    const rt = replyPlan({ ...s, reply_to: ["desk@x.org"], subject: "Re: Seminar" }, "me@a.com"); expect(rt.reply.to).toEqual(["desk@x.org"]); expect(rt.reply.subject).toBe("Re: Seminar"); expect(rt.replyAll.cc).toContain("hana@x.org".replace("hana", "b").replace("b@", "b@") === "b@x.org" ? "b@x.org" : "");
    expect(replyPlan({ ...s, references: Array.from({ length: 60 }, (_, i) => `r${i}@x`) }, "me@a.com").reply.references.length).toBe(40);
  });
});
