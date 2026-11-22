// ADMIN DESK desk_lookup_pure.ts (D5a-5, phase 1i, 23 Nov 2026): the three states a customer lookup can have on a screen. Pure, no network, no kernel call.
// The kernel (Rust WASM lookup_view) decides; this file only turns its one-line answer into a state. Anything unknown = unavailable (fail closed).
export const LOOKUP_PATH = "/desk/v1/customer/lookup";
/** The ONLY words for "no trustworthy answer". Never a cause, never an old value. */
export const UNAVAILABLE_TEXT = "Data unavailable";
export type LookupState =
  | { state: "data"; requestId: string; answeredAt: number; fields: Record<string, unknown> }
  | { state: "refused" }
  | { state: "unavailable" };
export const UNAVAILABLE: LookupState = { state: "unavailable" };

/** Turn the kernel's line ({"state":"data","body":"{...}"} | {"state":"refused"} | {"state":"unavailable"}) into a state. Any surprise = unavailable. */
export function parseLookupView(line: string): LookupState {
  try {
    const v = JSON.parse(line) as { state?: string; body?: string };
    if (v.state === "refused") return { state: "refused" };
    if (v.state !== "data" || typeof v.body !== "string") return UNAVAILABLE;
    const b = JSON.parse(v.body) as { request_id?: unknown; answered_at?: unknown; fields?: unknown };
    if (typeof b.request_id !== "string" || typeof b.answered_at !== "number" || b.fields === null || typeof b.fields !== "object" || Array.isArray(b.fields)) return UNAVAILABLE;
    return { state: "data", requestId: b.request_id, answeredAt: b.answered_at, fields: b.fields as Record<string, unknown> };
  } catch { return UNAVAILABLE; }
}
