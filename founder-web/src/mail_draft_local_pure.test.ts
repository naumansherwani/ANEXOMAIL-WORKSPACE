import { describe, expect, test } from "bun:test";
import { decodeDraft, draftAad, encodeDraft, pendingOf, restoreLine, slotOf, type LocalRec } from "./mail_draft_local_pure";
const R = (o: Partial<LocalRec>): LocalRec => ({ box: "b", slot: "new", key_id: "k", wrap: "", nonce: "", sealed: "", saved_ms: 1000, synced: false, ...o });
describe("sealed local draft", () => {
  test("aad binds box and slot", () => { expect(draftAad("B", "new")).toEqual(["fmail-draft-local-v1", "b", "new"]); expect(draftAad("b", "x")).not.toEqual(draftAad("b", "y")); });
  test("slot", () => { expect(slotOf(undefined)).toBe("new"); expect(slotOf("nope")).toBe("new"); expect(slotOf("0A0B0C0D-0000-4000-8000-000000000000")).toBe("0a0b0c0d-0000-4000-8000-000000000000"); });
  test("round trip and refusal", () => {
    const d = { to: ["a@x.com"], cc: [], bcc: [], subject: "Hi", text: "Salaam", html: "<p>Salaam</p>" };
    expect(decodeDraft(encodeDraft(d))).toEqual(d);
    expect(decodeDraft(new TextEncoder().encode("{}"))).toBeNull(); expect(decodeDraft(new Uint8Array([1, 2]))).toBeNull();
    expect(decodeDraft(new TextEncoder().encode(JSON.stringify({ to: [1], cc: [], bcc: [], subject: "", text: "" })))).toBeNull();
  });
  test("pending is the newest unsynced copy of that box", () => {
    expect(pendingOf([R({ saved_ms: 5 }), R({ saved_ms: 9, slot: "n2" }), R({ saved_ms: 20, synced: true }), R({ box: "o", saved_ms: 99 })], "B")?.slot).toBe("n2");
    expect(pendingOf([R({ synced: true })], "b")).toBeNull();
  });
  test("words", () => { expect(restoreLine(R({}), 1000 + 5 * 60_000)).toContain("5 min ago"); expect(restoreLine(R({}), 1000)).toContain("a moment ago"); expect(restoreLine(R({}), 1000 + 3 * 3_600_000)).toContain("3 h ago"); });
});
