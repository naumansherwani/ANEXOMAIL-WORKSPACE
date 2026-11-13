// KP3 step 3: the path round trip, measured by a tiny GET /healthz over the kernel's own QUIC session every 15 s while the tab is visible (the server answers "ok" with no work, so the time is the path).
import { kernelRpc, rpcAvailable } from "./kernel";
import { pathProbe } from "./pathhealth";
const EVERY_MS = 15_000;
let started = false;
export async function probeOnce(now: () => number = () => performance.now()): Promise<boolean> {
  if (!rpcAvailable()) return false;
  const t = now(); const r = await kernelRpc("GET", "/healthz", {}, null, 5000);
  if (!r || r.status !== 200) return false;
  pathProbe(Math.max(0, Math.round(now() - t))); return true;
}
export function startPathProbe(): void {
  if (started) return; started = true;
  const tick = () => { if (!document.hidden) void probeOnce().catch(() => undefined); };
  setTimeout(tick, 1500); setInterval(tick, EVERY_MS);
}
