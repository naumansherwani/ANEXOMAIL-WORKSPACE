/**
 * Browser fingerprint (E70/E71, identity hardening) — five groups of coarse traits, each reduced in the browser to ONE SHA-256 digest.
 * The server never sees a trait, only five digests, and keeps a one-way HMAC of each (pepper = server secret, never in the browser).
 *
 *   MACHINE groups — the same on this computer whichever browser is used (so switching Chrome -> Firefox does not shake them off):
 *     hw   — what the machine is        (cores, touch, platform, screen size/depth, colour gamut, pointer type)
 *     gpu  — what the graphics card can do (WebGL limits and precision — NOT the vendor strings, which differ per browser)
 *     font — which fonts the OS has installed (probe of ~110 families, one bit each)
 *   BROWSER groups — change with the browser or its settings:
 *     gfx  — how this browser draws     (canvas, audio render, WebGL vendor/renderer/extensions, WebGPU adapter, memory, UA client hints)
 *     env  — how it is set up           (time zone, language list, calendar, numbering system)
 *
 * Why five: a browser update or a different browser can change some groups; the server counts how many MATCH (default 3 of 5).
 * Why this never blocks a person on its own: identical laptops share groups, so a match is "ask the founder" (HOLD), never a ban.
 *
 * Honesty rules baked in:
 *  - A group that is NOT stable (anti-fingerprinting browsers add noise to canvas/audio/WebGL) is dropped (null), never sent as a random value.
 *    The server notices missing groups (too few usable groups = "fingerprint hidden") and follows the founder's rule for that.
 *  - Every probe is wrapped: a missing API makes that component "na", never an error; the whole collection has a time budget and
 *    sign-up goes on without it. Nothing here touches storage, cookies or the network.
 */

export type Fingerprint = { hw: string | null; gpu: string | null; font: string | null; gfx: string | null; env: string | null };
export type FpGroup = keyof Fingerprint;

const SEP = "\u001f";
const VERSION = "v2";

/** SHA-256 hex of "<version>|<group>|<parts joined by an unprintable separator>". Pure — same input, same digest, in any browser or in tests. */
export async function groupHash(group: FpGroup, parts: ReadonlyArray<string | number | boolean | null | undefined>): Promise<string> {
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

/* ───────────────────────── hw (machine) ───────────────────────── */
// Only traits every major browser exposes the same way: no deviceMemory / userAgentData (Chromium-only) — those live in gfx.
function hwParts(): Array<string | number | null> {
  const n = typeof navigator === "undefined" ? ({} as Navigator) : navigator;
  const s = typeof screen === "undefined" ? ({} as Screen) : screen;
  const mm = (q: string) => safe(() => (typeof matchMedia === "function" ? (matchMedia(q).matches ? 1 : 0) : null), null);
  const w = Number(s.width) || 0;
  const h = Number(s.height) || 0;
  return [
    n.hardwareConcurrency ?? null,
    n.maxTouchPoints ?? null,
    n.platform ?? null,
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

/* ───────────────────────── gpu (machine) ───────────────────────── */
// Hardware limits only. Vendor/renderer STRINGS differ between Chrome and Firefox on the same card, the numeric limits mostly do not.
function gpuParts(): Array<string | number | null> | typeof NOISY {
  const read = (): Array<string | number | null> => {
    const c = document.createElement("canvas");
    const gl = (c.getContext("webgl2") || c.getContext("webgl") || c.getContext("experimental-webgl")) as WebGL2RenderingContext | null;
    if (!gl) return ["nogl"];
    const num = (p: number) => safe(() => Number(gl.getParameter(p)), null);
    const pair = (p: number) => safe(() => { const v = gl.getParameter(p) as Float32Array | Int32Array | null; return v ? `${v[0]}x${v[1]}` : null; }, null);
    const prec = (shader: number, type: number) => safe(() => { const f = gl.getShaderPrecisionFormat(shader, type); return f ? `${f.rangeMin}/${f.rangeMax}/${f.precision}` : null; }, null);
    return [
      num(gl.MAX_TEXTURE_SIZE), num(gl.MAX_RENDERBUFFER_SIZE), pair(gl.MAX_VIEWPORT_DIMS), num(gl.MAX_VERTEX_ATTRIBS),
      num(gl.MAX_VERTEX_UNIFORM_VECTORS), num(gl.MAX_FRAGMENT_UNIFORM_VECTORS), num(gl.MAX_VARYING_VECTORS), num(gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS),
      num(gl.MAX_CUBE_MAP_TEXTURE_SIZE), pair(gl.ALIASED_LINE_WIDTH_RANGE), pair(gl.ALIASED_POINT_SIZE_RANGE),
      prec(gl.VERTEX_SHADER, gl.HIGH_FLOAT), prec(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT), prec(gl.FRAGMENT_SHADER, gl.MEDIUM_FLOAT), prec(gl.FRAGMENT_SHADER, gl.HIGH_INT),
      // WebGL2-only (null on WebGL1 — still deterministic per machine+browser support)
      num((gl as WebGL2RenderingContext).MAX_3D_TEXTURE_SIZE ?? 0), num((gl as WebGL2RenderingContext).MAX_SAMPLES ?? 0), num((gl as WebGL2RenderingContext).MAX_COLOR_ATTACHMENTS ?? 0),
    ];
  };
  const a = read();
  const b = read();
  return JSON.stringify(a) === JSON.stringify(b) ? a : NOISY;
}

/* ───────────────────────── gfx (browser) ───────────────────────── */
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

function webglStrings(): Array<string | number | null> | typeof NOISY {
  const read = (): Array<string | number | null> => {
    const c = document.createElement("canvas");
    const gl = (c.getContext("webgl") || c.getContext("experimental-webgl")) as WebGLRenderingContext | null;
    if (!gl) return ["nogl"];
    const dbg = gl.getExtension("WEBGL_debug_renderer_info");
    const ext = safe(() => (gl.getSupportedExtensions() || []).slice().sort().join(","), "");
    return [
      dbg ? String(gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL)) : String(gl.getParameter(gl.VENDOR)),
      dbg ? String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL)) : String(gl.getParameter(gl.RENDERER)),
      String(gl.getParameter(gl.SHADING_LANGUAGE_VERSION)),
      ext,
    ];
  };
  const a = read();
  const b = read();
  return JSON.stringify(a) === JSON.stringify(b) ? a : NOISY;
}

/** Chromium-only extras: device memory + UA client hints (architecture, bitness, model, platform version). Others return nulls. */
async function chromiumExtras(budgetMs: number): Promise<Array<string | number | null>> {
  const n = typeof navigator === "undefined" ? ({} as Navigator) : navigator;
  const uad = (n as unknown as { userAgentData?: { brands?: Array<{ brand: string }>; getHighEntropyValues?: (k: string[]) => Promise<Record<string, unknown>> } }).userAgentData;
  let hi: Record<string, unknown> = {};
  if (uad?.getHighEntropyValues) {
    hi = await Promise.race([
      uad.getHighEntropyValues(["architecture", "bitness", "model", "platformVersion"]).catch(() => ({})),
      new Promise<Record<string, unknown>>((r) => setTimeout(() => r({}), budgetMs)),
    ]);
  }
  const major = String(hi.platformVersion ?? "").split(".")[0] || null;
  return [(n as unknown as { deviceMemory?: number }).deviceMemory ?? null, (hi.architecture as string) ?? null, (hi.bitness as string) ?? null, (hi.model as string) ?? null, major];
}

/** WebGPU adapter identity (where the browser has it). Never throws, bounded by the budget. */
async function webgpuInfo(budgetMs: number): Promise<Array<string | null>> {
  const gpu = (navigator as unknown as { gpu?: { requestAdapter?: () => Promise<{ info?: Record<string, string> } | null> } }).gpu;
  if (!gpu?.requestAdapter) return [null];
  const ad = await Promise.race([gpu.requestAdapter().catch(() => null), new Promise<null>((r) => setTimeout(() => r(null), budgetMs))]);
  const i = ad?.info;
  return i ? [i.vendor ?? null, i.architecture ?? null, i.device ?? null, i.description ?? null] : [null];
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

/* ───────────────────────── font (machine) / env (browser) ───────────────────────── */
const FONT_PROBE = [
  // Windows
  "Arial", "Arial Black", "Arial Narrow", "Bahnschrift", "Calibri", "Cambria", "Cambria Math", "Candara", "Comic Sans MS", "Consolas", "Constantia", "Corbel",
  "Courier New", "Ebrima", "Franklin Gothic Medium", "Gabriola", "Gadugi", "Georgia", "Impact", "Ink Free", "Javanese Text", "Leelawadee UI", "Lucida Console",
  "Lucida Sans Unicode", "Malgun Gothic", "Microsoft Himalaya", "Microsoft JhengHei", "Microsoft New Tai Lue", "Microsoft PhagsPa", "Microsoft Sans Serif",
  "Microsoft Tai Le", "Microsoft YaHei", "Microsoft Yi Baiti", "MingLiU-ExtB", "Mongolian Baiti", "MS Gothic", "MV Boli", "Myanmar Text", "Nirmala UI", "Palatino Linotype",
  "Segoe MDL2 Assets", "Segoe Print", "Segoe Script", "Segoe UI", "Segoe UI Emoji", "Segoe UI Historic", "Segoe UI Symbol", "SimSun", "Sitka Text", "Sylfaen", "Tahoma",
  "Times New Roman", "Trebuchet MS", "Verdana", "Webdings", "Wingdings", "Yu Gothic",
  // macOS / iOS
  "American Typewriter", "Andale Mono", "Apple Chancery", "Apple Color Emoji", "Apple SD Gothic Neo", "Avenir", "Avenir Next", "Baskerville", "Big Caslon", "Bradley Hand",
  "Brush Script MT", "Chalkboard SE", "Chalkduster", "Cochin", "Copperplate", "Didot", "Futura", "Geneva", "Gill Sans", "Helvetica", "Helvetica Neue", "Hoefler Text",
  "Lucida Grande", "Marker Felt", "Menlo", "Monaco", "Optima", "Palatino", "Papyrus", "PingFang SC", "San Francisco", "SF Pro Text", "Skia", "Snell Roundhand", "Zapfino",
  // Linux / Android / cross-platform
  "Cantarell", "DejaVu Sans", "DejaVu Sans Mono", "DejaVu Serif", "Droid Sans", "Droid Serif", "FreeMono", "Liberation Mono", "Liberation Sans", "Liberation Serif",
  "Noto Sans", "Noto Serif", "Noto Color Emoji", "Open Sans", "Roboto", "Roboto Mono", "Source Sans Pro", "Ubuntu", "Ubuntu Mono",
  // scripts the product's own users write in
  "Noto Nastaliq Urdu", "Jameel Noori Nastaleeq", "Alvi Nastaleeq", "Noto Naskh Arabic", "Traditional Arabic", "Simplified Arabic", "Devanagari Sangam MN", "Mangal",
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
  ];
}

/* ───────────────────────── collect ───────────────────────── */
/**
 * Collect the five digests. `budgetMs` bounds the slow parts (audio, UA hints, WebGPU), which run in parallel; everything else is
 * synchronous and a few milliseconds. Returns null when there is no browser (SSR/tests) or when not a single group could be formed.
 */
export async function collectFingerprint(budgetMs = 900): Promise<Fingerprint | null> {
  try {
    if (typeof window === "undefined" || typeof document === "undefined" || !window.crypto?.subtle) return null;
    const hw = await groupHash("hw", safe(hwParts, []));

    const gpuP = safe(gpuParts, null);
    const gpu = gpuP == null || hasNoise([gpuP]) ? null : await groupHash("gpu", safe(() => (gpuP as unknown[]).map((x) => (x == null ? null : String(x))), []));

    const font = await groupHash("font", [safe(fontMask, null)]);

    const canvas = safe(canvasRead, null);
    const gl = safe(webglStrings, null);
    const [audio, extras, wgpu] = await Promise.all([
      audioRead(budgetMs).catch(() => null),
      chromiumExtras(Math.min(budgetMs, 500)).catch(() => [] as Array<string | number | null>),
      webgpuInfo(Math.min(budgetMs, 500)).catch(() => [null] as Array<string | null>),
    ]);
    const gfxParts: unknown[] = [canvas, gl, audio];
    // a noisy component (anti-fingerprinting browser) would make the digest random: drop the whole group instead of sending noise
    const gfx = hasNoise(gfxParts) || (canvas == null && gl == null && audio == null)
      ? null
      : await groupHash("gfx", [canvas as string | null, JSON.stringify(gl), audio as string | null, JSON.stringify(extras), JSON.stringify(wgpu)]);

    const env = await groupHash("env", safe(envParts, []));
    return { hw, gpu, font, gfx, env };
  } catch {
    return null;
  }
}
