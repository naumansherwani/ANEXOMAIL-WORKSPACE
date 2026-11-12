// LA-3: the one line under the orb ("HTTP/3 QUIC · Hardware key · ML-DSA-65"). Pure: turns what the server already reports about THIS session into words.
// Nothing is guessed: a part whose value is unknown is left out; if every part is unknown there is no line at all.
export type OrbLineIn = { protocol?: string | null; keySource?: string | null; psrc?: string | null };
export type OrbPart = { text: string; tone: "ok" | "warn" };
export type OrbLine = { parts: OrbPart[]; text: string; sr: string; tone: "ok" | "warn" };

const NET: Record<string, OrbPart> = {
  quic: { text: "HTTP/3 QUIC", tone: "ok" }, h3: { text: "HTTP/3 QUIC", tone: "ok" },
  h2: { text: "HTTP/2 (fallback)", tone: "warn" }, h1: { text: "HTTP/1.1 (fallback)", tone: "warn" },
};
const KEY: Record<string, OrbPart> = {
  dbsc: { text: "Hardware key", tone: "ok" }, webcrypto: { text: "Browser key", tone: "ok" }, none: { text: "No device key", tone: "warn" },
};

export function orbLine(x: OrbLineIn): OrbLine | null {
  const parts: OrbPart[] = [];
  const n = NET[(x.protocol ?? "").toLowerCase()]; if (n) parts.push(n);
  const k = KEY[(x.keySource ?? "").toLowerCase()]; if (k) parts.push(k);
  if (x.psrc === "webcrypto") parts.push({ text: "ML-DSA-65", tone: "ok" });
  else if (x.psrc === "kernel") parts.push({ text: "ML-DSA-65 (software)", tone: "warn" });
  if (!parts.length) return null;
  const tone = parts.some((p) => p.tone === "warn") ? "warn" : "ok";
  const text = parts.map((p) => p.text).join(" · ");
  return { parts, text, tone, sr: `Connection: ${parts.map((p) => p.text).join(", ")}.` };
}

const KEY_OFF = "orbline.off";
export const orbLineHidden = (): boolean => { try { return window.localStorage.getItem(KEY_OFF) === "1"; } catch { return false; } };
export const setOrbLineHidden = (v: boolean): void => { try { if (v) window.localStorage.setItem(KEY_OFF, "1"); else window.localStorage.removeItem(KEY_OFF); window.dispatchEvent(new Event("orbline-change")); } catch { /* private window: the switch simply does not persist */ } };
