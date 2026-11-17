import { describe, expect, test } from "bun:test";
import { outView, reasonText } from "./outbox_pure";
import type { OutRow } from "./mail_api";
const R = (o: Partial<OutRow>): OutRow => ({ outbox_id: "o", message_id: "m", state: "queued", not_before: new Date(10_000).toISOString(), undo_until: "", rcpt: 1, attempts: 0, last_error: null, tls: null, dkim: false, finished_at: null, ...o });
describe("outbox in plain words", () => {
  test("queued counts down", () => { const v = outView(R({}), 4_000); expect(v.title).toMatch(/undo/i); expect(v.detail).toContain("6s"); expect(v.canCancel).toBe(false); });
  test("failed always carries the reason and can be cancelled", () => { const v = outView(R({ state: "failed", attempts: 2, last_error: "anexomail.com points to a private address" }), 99_000); expect(v.tone).toBe("bad"); expect(v.detail).toMatch(/internal address/); expect(v.canCancel).toBe(true); });
  test("sent shows TLS and DKIM", () => { expect(outView(R({ state: "sent", tls: "TLS 1.3", dkim: true }), 0).detail).toBe("Secured with TLS 1.3 · DKIM signed"); });
  test("cancelled and undone say where the text went", () => { expect(outView(R({ state: "cancelled" }), 0).detail).toMatch(/Drafts/); expect(outView(R({ state: "undone" }), 0).detail).toMatch(/Drafts/); });
  test("unknown reason text is shown as it is, never hidden", () => { expect(reasonText("550 5.7.1 blocked")).toBe("550 5.7.1 blocked"); expect(reasonText(null)).toBe(""); });
  test("unknown state is shown, not dropped", () => { expect(outView(R({ state: "weird" }), 0).title).toBe("weird"); });
});
