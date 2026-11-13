import { expect, test } from "bun:test";
import { pathFail, pathLabel, pathRtt, pathReset, pathState, pathUp, STAGE_TEXT } from "./pathhealth";

test("path health: only measured facts reach the label (connecting -> connected -> ms; a failure names its stage and age)", () => {
  pathReset(); expect(pathLabel(pathState(), 0)).toBe("QUIC · connecting");
  pathUp(1000); expect(pathLabel(pathState(), 1000)).toBe("QUIC · connected");
  pathRtt(185); pathRtt(175); pathRtt(400);
  const s = pathState(); expect(s.rttMs).toBe(400); expect(s.minMs).toBe(175); expect(s.samples).toBe(3); expect(s.avgMs).toBeCloseTo(185 + (-10 / 8) + (400 - (185 - 10 / 8)) / 8, 1);
  expect(pathLabel(s, 1)).toBe("QUIC · 400 ms");
  pathFail(0, 10_000); expect(pathLabel(pathState(), 15_000)).toBe(`${STAGE_TEXT.handshake_timeout} · 5 s ago`); expect(pathState().up).toBe(false);
  pathFail(9, 20_000); expect(pathState().fail?.stage).toBe("closed"); // an unknown code is never invented into a cause
  pathUp(30_000); expect(pathState().fail).toBeNull();
});
test("path health refuses nonsense samples", () => { pathReset(); pathRtt(-1); pathRtt(Number.NaN); pathRtt(1e9); expect(pathState().samples).toBe(0); });
