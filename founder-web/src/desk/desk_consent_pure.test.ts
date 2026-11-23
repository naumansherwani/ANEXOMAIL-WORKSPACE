import { expect, test } from "bun:test";
import { buildRequest, caseRefOk, leftWords, parseBoard, parseOpened, parseRequested, reasonProblem, statusWords } from "./desk_consent_pure";
const ID = "123e4567-e89b-12d3-a456-426614174000";
test("a request needs a clean case ref, a known scope and a real reason", () => {
  expect(buildRequest({ caseRef: " CASE-1 ", scope: "metadata", reason: "customer asked us to look at the delay" })).toEqual({ case_ref: "CASE-1", scope: "metadata", reason: "customer asked us to look at the delay" });
  expect(buildRequest({ caseRef: "a b", scope: "metadata", reason: "customer asked us to look at the delay" })).toBeNull();
  expect(buildRequest({ caseRef: "CASE-1", scope: "all" as never, reason: "customer asked us to look at the delay" })).toBeNull();
  expect(buildRequest({ caseRef: "CASE-1", scope: "content", reason: "short" })).toBeNull();
  expect(reasonProblem("x".repeat(301))).not.toBeNull(); expect(reasonProblem("line\nbreak " + "y".repeat(20))).not.toBeNull(); expect(caseRefOk("ab")).toBe(false);
});
test("the board accepts only the exact shape and a time exists exactly while approved", () => {
  const row = { id: ID, case: "CASE-1", scope: "metadata", status: "approved", seconds_left: 125 };
  expect(parseBoard({ waiting: 0, live: 1, mine: [row] })?.mine[0].secondsLeft).toBe(125);
  expect(parseBoard({ waiting: 0, live: 1, mine: [{ ...row, seconds_left: null }] })).toBeNull();
  expect(parseBoard({ waiting: 1, live: 0, mine: [{ ...row, status: "requested", seconds_left: 5 }] })).toBeNull();
  expect(parseBoard({ waiting: 1, live: 0, mine: [{ ...row, status: "requested", seconds_left: null }] })?.waiting).toBe(1);
  expect(parseBoard({ waiting: 0, live: 0, mine: [{ ...row, status: "approved-by-me" }] })).toBeNull();
  expect(parseBoard({ waiting: "0", live: 0, mine: [] })).toBeNull(); expect(parseBoard(null)).toBeNull(); expect(parseBoard({ waiting: 0, live: 0, mine: [{ ...row, id: "x" }] })).toBeNull();
});
test("answers of the request and open doors are checked", () => {
  expect(parseRequested({ consent_id: ID, status: "requested" })).toEqual({ id: ID }); expect(parseRequested({ consent_id: ID, status: "approved" })).toBeNull(); expect(parseRequested({ consent_id: "1", status: "requested" })).toBeNull();
  expect(parseOpened({ scope: "headers", seconds_left: 30 })).toEqual({ scope: "headers", secondsLeft: 30 }); expect(parseOpened({ scope: "x", seconds_left: 30 })).toBeNull(); expect(parseOpened({ scope: "headers", seconds_left: -1 })).toBeNull();
});
test("words are plain and the clock reads well", () => {
  expect(leftWords(125)).toBe("2 min 05 s left"); expect(leftWords(9)).toBe("9 s left"); expect(statusWords("requested")).toContain("Company Admin"); expect(statusWords("denied")).toContain("no");
});
