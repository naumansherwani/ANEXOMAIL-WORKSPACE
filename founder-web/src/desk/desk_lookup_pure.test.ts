import { expect, test } from "bun:test";
import { LOOKUP_PATH, parseLookupView, UNAVAILABLE, UNAVAILABLE_TEXT } from "./desk_lookup_pure";
const data = (body: unknown) => JSON.stringify({ state: "data", body: typeof body === "string" ? body : JSON.stringify(body) });
test("the words for no answer are fixed and plain", () => { expect(UNAVAILABLE_TEXT).toBe("Data unavailable"); expect(LOOKUP_PATH).toBe("/desk/v1/customer/lookup"); });
test("good kernel data becomes a data state with only what was signed", () => {
  const s = parseLookupView(data({ request_id: "r1", company_ref: "acme-1234", answered_at: 1000, fields: { service_state: "active" } }));
  expect(s).toEqual({ state: "data", requestId: "r1", answeredAt: 1000, fields: { service_state: "active" } });
});
test("refused stays refused", () => { expect(parseLookupView('{"state":"refused"}')).toEqual({ state: "refused" }); });
test("every surprise is unavailable, never data", () => {
  for (const x of ["", "null", "not json", "{}", '{"state":"unavailable"}', '{"state":"data"}', '{"state":"data","body":5}', '{"state":"DATA","body":"{}"}', '{"state":"fresh","body":"{}"}', data("not json"),
    data({ request_id: 1, answered_at: 1, fields: {} }), data({ request_id: "r", answered_at: "1", fields: {} }), data({ request_id: "r", answered_at: 1 }), data({ request_id: "r", answered_at: 1, fields: null }), data({ request_id: "r", answered_at: 1, fields: [1] })])
    expect(parseLookupView(x)).toEqual(UNAVAILABLE);
});
