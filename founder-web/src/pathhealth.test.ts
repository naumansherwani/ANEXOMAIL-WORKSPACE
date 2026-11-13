import { expect, test } from "bun:test";
import { pathFail, pathLabel, pathRetry, pathRtt, pathReset, pathState, pathUp, retrySecs, STAGE_TEXT } from "./pathhealth";

test("path health: only measured facts reach the label (connecting -> connected -> ms; a failure names its stage and age)", () => {
  pathReset(); expect(pathLabel(pathState(), 0)).toBe("QUIC · connecting");
  pathUp(1000); expect(pathLabel(pathState(), 1000)).toBe("QUIC · connected");
  pathRtt(185); pathRtt(175); pathRtt(400);
  const s = pathState(); expect(s.rttMs).toBe(400); expect(s.minMs).toBe(175); expect(s.samples).toBe(3); expect(s.avgMs).toBeCloseTo(185 + (-10 / 8) + (400 - (185 - 10 / 8)) / 8, 1);
  expect(pathLabel(s, 1)).toBe("QUIC · 175 ms"); // the chip shows the network floor (lowest), never a slow call as if it were the network
  pathFail(0, 10_000); expect(pathLabel(pathState(), 15_000)).toBe(`${STAGE_TEXT.handshake_timeout} · 5 s ago`); expect(pathState().up).toBe(false);
  pathFail(9, 20_000); expect(pathState().fail?.stage).toBe("closed"); // an unknown code is never invented into a cause
  pathUp(30_000); expect(pathState().fail).toBeNull();
});
test("path health refuses nonsense samples", () => { pathReset(); pathRtt(-1); pathRtt(Number.NaN); pathRtt(1e9); expect(pathState().samples).toBe(0); });

test("path health: the kernel's retry wait becomes a visible countdown, cleared when the path is back; silly waits are ignored", () => {
  pathReset(); pathFail(1, 1000); pathRetry(12_000, 1000); expect(retrySecs(pathState(), 1000)).toBe(12); expect(retrySecs(pathState(), 9000)).toBe(4);
  expect(pathLabel(pathState(), 3000)).toBe(`${STAGE_TEXT.connect_failed} · 2 s ago · retry in 10 s`);
  pathUp(20_000); expect(pathState().retryAt).toBeNull(); pathReset(); pathRetry(5, 0); pathRetry(1e9, 0); expect(pathState().retryAt).toBeNull();
});
