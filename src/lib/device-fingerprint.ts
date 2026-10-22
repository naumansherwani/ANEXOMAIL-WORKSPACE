/**
 * Browser fingerprint (E70, identity hardening) — three groups of coarse browser/hardware traits, each reduced in the browser
 * to ONE SHA-256 digest. The server never sees a trait, only three digests, and keeps a one-way HMAC of each (pepper = server secret).
 *
 *   hw  — what the machine is        (cores, memory, touch, screen size/depth, platform, colour gamut, pointer type)
 *   gfx — how the machine draws      (canvas render, WebGL vendor/renderer/limits, audio render)
 *   env — how the browser is set up  (time zone, language list, installed-font probe, Intl defaults)
 *
 * Why three: a browser update can change one group; "two of three still match" survives that. Why this never blocks a person on its own:
 * identical phones/laptops share a fingerprint, so the server treats a match as "ask the founder" (HOLD), never as a ban.
 *
 * Honesty rules baked in:
 *  - A group that is NOT stable (anti-fingerprinting browsers add noise to canvas/audio) is dropped (null), never sent as a random value.
 *  - Every probe is wrapped: a missing API makes that component "na", never an error; the whole collection has a time budget and
 *    sign-up goes on without it. Nothing here touches storage, cookies or the network.
 */

export type Fingerprint = { hw: string | null; gfx: string | null; env: string | null };

const SEP = "\u001f";
const VERSION = "v1";

/** SHA-256 hex of "<version>|<group>|<parts joined by an unprintable separator>". Pure — same input, same digest, in any browser or in tests. */
export async function groupHash(group: "hw" | "gfx" | "env", parts: ReadonlyArray<string | number | boolean | null | undefined>): Promise<string> {
  const text = `anexomail/fp/${VERSION}|${group}|${parts.map((p) => (p == null ? "na" : String(p))).join(SEP)}`;
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** A probe is trustworthy only if two reads agree; a probe whose two reads differ (noise injection) is marked NOISY.
 *  A group containing a NOISY component is never sent — a random digest would only pollute the vault. */
export const NOISY = Symbol("noisy");
export function hasNoise(parts: ReadonlyArray<unknown>): boolean {
  return parts.some((p) => p === NOISY);
}

const safe = <T>(fn: () => T, fallback: T): T => {
  try {
    return fn();
  } catch {
    return fallback;
  }
};

/* ───────────────────────── hw ───────────────────────── */
function hwParts(): Array<string | number | null> {
  const n = typeof navigator === "undefined" ? ({} as Navigator) : navigator;
  const s = typeof screen === "undefined" ? ({} as Screen) : screen;
  const uad = (n as unknown as { userAgentData?: { platform?: string } }).userAgentData;
  const mm = (q: string) => safe(() => (typeof matchMedia === "function" ? (matchMedia(q).matches ? 1 : 0) : null), null);
  const w = Number(s.width) || 0;
  const h = Number(s.height) || 0;
  return [
    n.hardwareConcurrency ?? null,
    (n as unknown as { deviceMemory?: number }).deviceMemory ?? null,
    n.maxTouchPoints ?? null,
    uad?.platform ?? n.platform ?? null,
    Math.max(w, h), // orientation-proof: a rotated phone is the same phone
    Math.min(w, h),
    s.colorDepth ?? null,
    mm("(color-gamut: p3)"),
    mm("(color-gamut: rec2020)"),
    mm("(dynamic-range: high)"),
    mm("(pointer: coarse)"),
    mm("(hover: none)"),
  ];
}

/* ───────────────────────── gfx ───────────────────────── */
function canvasRead(): string | typeof NOISY | null {
  const draw = (): string | null => {
    const c = document.createElement("canvas");
    c.width = 220;
    c.height = 40;
    const g = c.getContext("2d");
    if (!g) return null;
    g.textBaseline = "alphabetic";
    g.fillStyle = "#f60";
    g.fillRect(8, 4, 60, 22);
    g.fillStyle = "#069";
    g.font = "15px 'Arial', sans-serif";
    g.fillText("Anexo ✓ mail ∑ 0123", 4, 28);
    g.strokeStyle = "rgba(102,204,0,0.7)";
    g.beginPath();
    g.arc(160, 20, 14, 0, Math.PI * 2, true);
    g.stroke();
    return c.toDataURL();
  };
  const a = draw();
  const b = draw();
  if (a == null || b == null) return null;
  return a === b ? a : NOISY;
}

function webglRead(): Array<string | number | null> | typeof NOISY {
  const read = (): Array<string | number | null> => {
    const c = document.createElement("canvas");
    const gl = (c.getContext("webgl") || c.getContext("experimental-webgl")) as WebGLRenderingContext | null;
    if (!gl) return ["nogl"];
    const dbg = gl.getExtension("WEBGL_debug_renderer_info");
    const vp = gl.getParameter(gl.MAX_VIEWPORT_DIMS) as Int32Array | null;
    return [
      dbg ? String(gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL)) : String(gl.getParameter(gl.VENDOR)),
      dbg ? String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL)) : String(gl.getParameter(gl.RENDERER)),
      Number(gl.getParameter(gl.MAX_TEXTURE_SIZE)),
      Number(gl.getParameter(gl.MAX_RENDERBUFFER_SIZE)),
      vp ? `${vp[0]}x${vp[1]}` : null,
      Number(gl.getParameter(gl.MAX_VERTEX_ATTRIBS)),
      String(gl.getParameter(gl.SHADING_LANGUAGE_VERSION)),
    ];
  };
  const a = read();
  const b = read();
  return JSON.stringify(a) === JSON.stringify(b) ? a : NOISY;
}

async function audioRead(budgetMs: number): Promise<string | typeof NOISY | null> {
  const Ctor = (globalThis as unknown as { OfflineAudioContext?: typeof OfflineAudioContext; webkitOfflineAudioContext?: typeof OfflineAudioContext }).OfflineAudioContext
    ?? (globalThis as unknown as { webkitOfflineAudioContext?: typeof OfflineAudioContext }).webkitOfflineAudioContext;
  if (!Ctor) return null;
  const render = async (): Promise<string | null> => {
    const ctx = new Ctor(1, 5000, 44100);
    const osc = ctx.createOscillator();
    osc.type = "triangle";
    osc.frequency.value = 10000;
    const comp = ctx.createDynamicsCompressor();
    for (const [k, v] of [["threshold", -50], ["knee", 40], ["ratio", 12], ["attack", 0], ["release", 0.25]] as const) {
      const p = (comp as unknown as Record<string, AudioParam>)[k];
      if (p) p.value = v;
    }
    osc.connect(comp);
    comp.connect(ctx.destination);
    osc.start(0);
    const out = await Promise.race([ctx.startRendering(), new Promise<null>((r) => setTimeout(() => r(null), budgetMs))]);
    if (!out) return null;
    const data = out.getChannelData(0);
    let sum = 0;
    for (let i = 4500; i < 5000; i++) sum += Math.abs(data[i] ?? 0);
    return sum.toFixed(6);
  };
  const a = await render();
  if (a == null) return null;
  const b = await render();
  return b == null ? null : a === b ? a : NOISY;
}

/* ───────────────────────── env ───────────────────────── */
const FONT_PROBE = [
  "Arial", "Arial Black", "Calibri", "Cambria", "Candara", "Comic Sans MS", "Consolas", "Courier New", "Georgia", "Impact", "Lucida Console",
  "Palatino Linotype", "Segoe UI", "Tahoma", "Times New Roman", "Trebuchet MS", "Verdana", "Helvetica", "Helvetica Neue", "Menlo", "Monaco",
  "Optima", "Gill Sans", "Futura", "Avenir", "San Francisco", "Roboto", "Noto Sans", "Ubuntu", "DejaVu Sans", "Liberation Sans", "Droid Sans",
  "Noto Nastaliq Urdu", "Jameel Noori Nastaleeq", "Nirmala UI", "Microsoft YaHei", "MS Gothic", "Malgun Gothic",
];

function fontMask(): string {
  const span = document.createElement("span");
  span.textContent = "mmmmmmmmmmlliWQ0123 Aaبجد";
  span.style.cssText = "position:absolute;left:-9999px;top:-9999px;font-size:72px;visibility:hidden;white-space:nowrap";
  document.body.appendChild(span);
  try {
    const bases = ["monospace", "sans-serif", "serif"];
    const base: Record<string, number> = {};
    for (const b of bases) {
      span.style.fontFamily = b;
      base[b] = span.offsetWidth;
    }
    let bits = "";
    for (const f of FONT_PROBE) {
      let hit = 0;
      for (const b of bases) {
        span.style.fontFamily = `'${f}',${b}`;
        if (span.offsetWidth !== base[b]) {
          hit = 1;
          break;
        }
      }
      bits += hit;
    }
    return bits;
  } finally {
    span.remove();
  }
}

function envParts(): Array<string | number | null> {
  const n = typeof navigator === "undefined" ? ({} as Navigator) : navigator;
  const dtf = safe(() => Intl.DateTimeFormat().resolvedOptions(), null);
  const nf = safe(() => Intl.NumberFormat().resolvedOptions(), null);
  return [
    dtf?.timeZone ?? null,
    dtf?.calendar ?? null,
    nf?.numberingSystem ?? null,
    safe(() => (n.languages && n.languages.length ? [...n.languages].join(",") : n.language ?? null), null),
    safe(() => fontMask(), null),
  ];
}

/* ───────────────────────── collect ───────────────────────── */
/**
 * Collect the three digests. `budgetMs` bounds the slow part (audio); everything else is synchronous and a few milliseconds.
 * Returns null when there is no browser (SSR/tests) or when not a single group could be formed.
 */
export async function collectFingerprint(budgetMs = 900): Promise<Fingerprint | null> {
  try {
    if (typeof window === "undefined" || typeof document === "undefined" || !window.crypto?.subtle) return null;
    const hw = await groupHash("hw", safe(hwParts, []));

    const canvas = safe(canvasRead, null);
    const gl = safe(webglRead, null);
    const audio = await audioRead(budgetMs).catch(() => null);
    const gfxParts: unknown[] = [canvas, gl, audio];
    // a noisy component (anti-fingerprinting browser) would make the digest random: drop the whole group instead of sending noise
    const gfx = hasNoise(gfxParts) || (canvas == null && gl == null && audio == null)
      ? null
      : await groupHash("gfx", [canvas as string | null, JSON.stringify(gl), audio as string | null]);

    const env = await groupHash("env", safe(envParts, []));
    return { hw, gfx, env };
  } catch {
    return null;
  }
}
