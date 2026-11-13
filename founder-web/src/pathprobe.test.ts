import { expect, mock, test } from "bun:test";
let avail = true, reply: { status: number } | null = { status: 200 }, called: string[] = [];
mock.module("./kernel", () => ({ rpcAvailable: () => avail, kernelRpc: async (m: string, p: string) => { called.push(`${m} ${p}`); return reply; } }));
const { probeOnce } = await import("./pathprobe");
const { pathReset, pathState } = await import("./pathhealth");

test("probe: a 200 from /healthz over the kernel becomes the path round trip; no session, a refused or a failed ping records nothing", async () => {
  pathReset(); let t = 1000; const clock = () => (t += 180);
  expect(await probeOnce(clock)).toBe(true); expect(called).toEqual(["GET /healthz"]); expect(pathState().probeMs).toBe(180);
  avail = false; expect(await probeOnce(clock)).toBe(false); avail = true; reply = { status: 503 }; expect(await probeOnce(clock)).toBe(false); reply = null; expect(await probeOnce(clock)).toBe(false);
  expect(pathState().probes).toBe(1);
});
