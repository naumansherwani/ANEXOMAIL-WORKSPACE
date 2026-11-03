import { useEffect, useMemo, useRef, useState } from "react";

import { greatCircle, projectClamped, project, unproject, type View } from "@/lib/globe-geo";
import { subsolarPoint, sunAltitude, wrapLon } from "@/lib/sun";
import { cn } from "@/lib/utils";

export type GlobePin = {
  key: string;
  label: string;
  lat: number;
  lon: number;
  home?: boolean;
  trip?: boolean;
};
export type GlobeRoute = { from: { lat: number; lon: number }; to: { lat: number; lon: number } };

type Ring = number[]; // [lon, lat, lon, lat, …] — Natural Earth 110 m land (public domain), outer rings only

const OCEAN_IN = "#12315a";
const OCEAN_OUT = "#071327";
const LAND = "#3d6a9e";
const LAND_EDGE = "#6f9bd0";
const NIGHT = [3, 8, 22]; // night shade colour (r,g,b)
const NIGHT_MAX = 0.62; // darkest night opacity
const PIN = "#ffd166";
const PIN_HOME = "#7ee0ff";
const PIN_TRIP = "#ff8fb1";
const ROUTE = "rgba(255,143,177,0.9)";
const NIGHT_RES = 110; // night mask resolution (px); scaled up smoothly

const prefersReducedMotion = () =>
  typeof window !== "undefined" &&
  typeof window.matchMedia === "function" &&
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/**
 * Day/night globe (World clock W3). Canvas 2D, orthographic projection, no WebGL and no network: land is a 19 KB (gzip) bundled
 * coastline, the terminator is plain astronomy from `lib/sun.ts`. It is loaded lazily, only when the clock popover opens.
 * Drag or use the arrow keys to turn it; with "reduce motion" on it does not spin by itself.
 */
export function GlobeView({
  pins,
  now,
  route,
  className,
}: {
  pins: GlobePin[];
  now: Date;
  route?: GlobeRoute | null;
  className?: string;
}) {
  const canvas = useRef<HTMLCanvasElement | null>(null);
  const wrap = useRef<HTMLDivElement | null>(null);
  const [land, setLand] = useState<Ring[] | null>(null);
  const home = pins.find((p) => p.home) ?? pins[0];
  const view = useRef<View>({ lat: 18, lon: home?.lon ?? 0 });
  const drag = useRef<{ x: number; y: number; lat: number; lon: number } | null>(null);
  const nowRef = useRef(now);
  const pinsRef = useRef(pins);
  const routeRef = useRef(route ?? null);
  const [tick, setTick] = useState(0);
  nowRef.current = now;
  pinsRef.current = pins;
  routeRef.current = route ?? null;

  useEffect(() => {
    let alive = true;
    void import("@/assets/land-110m.json").then((m) => {
      if (alive) setLand((m.default ?? m) as unknown as Ring[]);
    });
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    const el = canvas.current;
    const box = wrap.current;
    if (!el || !box || !land) return;
    const ctx = el.getContext("2d");
    if (!ctx) return;
    const mask = document.createElement("canvas");
    mask.width = mask.height = NIGHT_RES;
    const mctx = mask.getContext("2d");
    const still = prefersReducedMotion();
    let raf = 0;
    let last = 0;
    let size = 0;

    const fit = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      size = Math.max(120, Math.round(box.clientWidth));
      el.width = size * dpr;
      el.height = size * dpr;
      el.style.width = `${size}px`;
      el.style.height = `${size}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    const draw = () => {
      const c = view.current;
      const r = size / 2 - 3;
      const cx = size / 2;
      const cy = size / 2;
      const sun = subsolarPoint(nowRef.current);
      ctx.clearRect(0, 0, size, size);

      // ocean + soft rim
      const g = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.35, r * 0.1, cx, cy, r);
      g.addColorStop(0, OCEAN_IN);
      g.addColorStop(1, OCEAN_OUT);
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.fillStyle = g;
      ctx.fill();

      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.clip();

      // land
      ctx.fillStyle = LAND;
      ctx.strokeStyle = LAND_EDGE;
      ctx.lineWidth = 0.6;
      for (const ring of land) {
        let any = false;
        ctx.beginPath();
        for (let i = 0; i < ring.length; i += 2) {
          const p = projectClamped(ring[i + 1], ring[i], c);
          if (p.visible) any = true;
          const x = cx + p.x * r;
          const y = cy + p.y * r;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        if (!any) continue;
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }

      // night: per-pixel sun altitude on a small mask, smoothed up. Twilight (−6°…0°) fades in, deep night is darkest.
      if (mctx) {
        const img = mctx.createImageData(NIGHT_RES, NIGHT_RES);
        for (let py = 0; py < NIGHT_RES; py++) {
          for (let px = 0; px < NIGHT_RES; px++) {
            const x = ((px + 0.5) / NIGHT_RES) * 2 - 1;
            const y = ((py + 0.5) / NIGHT_RES) * 2 - 1;
            const u = unproject(x, y, c);
            if (!u) continue;
            const alt = sunAltitude(u.lat, u.lon, sun);
            const k = alt >= 0 ? 0 : alt <= -12 ? 1 : -alt / 12;
            const o = (py * NIGHT_RES + px) * 4;
            img.data[o] = NIGHT[0];
            img.data[o + 1] = NIGHT[1];
            img.data[o + 2] = NIGHT[2];
            img.data[o + 3] = Math.round(k * NIGHT_MAX * 255);
          }
        }
        mctx.putImageData(img, 0, 0);
        ctx.imageSmoothingEnabled = true;
        ctx.drawImage(mask, cx - r, cy - r, r * 2, r * 2);
      }
      ctx.restore();

      // rim light
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.strokeStyle = "rgba(160,200,255,0.35)";
      ctx.lineWidth = 1;
      ctx.stroke();

      // trip route: the great circle between the two cities the person typed (a line on a map, not a tracked position)
      const rt = routeRef.current;
      if (rt) {
        ctx.save();
        ctx.setLineDash([4, 4]);
        ctx.strokeStyle = ROUTE;
        ctx.lineWidth = 1.5;
        let pen = false;
        ctx.beginPath();
        for (const [la, lo] of greatCircle(rt.from, rt.to, 64)) {
          const q = project(la, lo, c);
          if (!q.visible) {
            pen = false;
            continue;
          }
          const x = cx + q.x * r;
          const y = cy + q.y * r;
          if (pen) ctx.lineTo(x, y);
          else ctx.moveTo(x, y);
          pen = true;
        }
        ctx.stroke();
        ctx.restore();
      }

      // pins (only those facing us)
      ctx.font = "600 10px Inter, system-ui, sans-serif";
      ctx.textBaseline = "middle";
      for (const pin of pinsRef.current) {
        const p = project(pin.lat, pin.lon, c);
        if (!p.visible) continue;
        const x = cx + p.x * r;
        const y = cy + p.y * r;
        ctx.beginPath();
        ctx.arc(x, y, pin.home ? 4.5 : 3.5, 0, Math.PI * 2);
        ctx.fillStyle = pin.home ? PIN_HOME : pin.trip ? PIN_TRIP : PIN;
        ctx.fill();
        ctx.strokeStyle = "rgba(0,0,0,0.55)";
        ctx.lineWidth = 1.5;
        ctx.stroke();
        const left = x > cx + r * 0.45;
        ctx.textAlign = left ? "right" : "left";
        const tx = x + (left ? -7 : 7);
        ctx.lineWidth = 3;
        ctx.strokeStyle = "rgba(4,10,24,0.85)";
        ctx.strokeText(pin.label, tx, y);
        ctx.fillStyle = "#f3f7ff";
        ctx.fillText(pin.label, tx, y);
      }
    };

    const loop = (t: number) => {
      raf = requestAnimationFrame(loop);
      if (document.hidden) return;
      if (t - last < 66) return; // ~15 fps is plenty for a clock face and keeps the main thread free (INP)
      const dt = last ? (t - last) / 1000 : 0;
      last = t;
      if (!still && !drag.current)
        view.current = { ...view.current, lon: wrapLon(view.current.lon + 4 * dt) };
      draw();
    };

    fit();
    draw();
    if (!still) raf = requestAnimationFrame(loop);
    const ro = new ResizeObserver(() => {
      fit();
      draw();
    });
    ro.observe(box);
    const redraw = () => draw();
    el.addEventListener("globe-redraw", redraw);
    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      el.removeEventListener("globe-redraw", redraw);
    };
  }, [land, tick]);

  const redraw = () => canvas.current?.dispatchEvent(new Event("globe-redraw"));
  // the clock ticks every 15 s: repaint the terminator even when the globe is still (reduced motion)
  useEffect(() => {
    redraw();
  }, [now]);
  const turn = (dLon: number, dLat: number) => {
    const v = view.current;
    view.current = { lat: Math.max(-80, Math.min(80, v.lat + dLat)), lon: wrapLon(v.lon + dLon) };
    redraw();
  };

  const sun = useMemo(() => subsolarPoint(now), [now]);
  const label = `Day and night on Earth at ${now.toISOString().slice(11, 16)} UTC. The sun is overhead near ${Math.abs(Math.round(sun.lat))}° ${sun.lat >= 0 ? "north" : "south"}, ${Math.abs(Math.round(sun.lon))}° ${sun.lon >= 0 ? "east" : "west"}. ${pins.length} ${pins.length === 1 ? "city" : "cities"} pinned.`;

  return (
    <div className={cn("space-y-1.5", className)}>
      <div
        ref={wrap}
        className="relative mx-auto aspect-square w-full max-w-[min(18rem,32vh)] touch-pan-y select-none"
      >
        {!land && (
          <div
            className="absolute inset-0 animate-pulse rounded-full bg-secondary/60"
            aria-hidden="true"
          />
        )}
        <canvas
          ref={canvas}
          role="img"
          aria-label={label}
          tabIndex={0}
          className="ax-focus block cursor-grab rounded-full active:cursor-grabbing"
          onPointerDown={(e) => {
            (e.target as HTMLElement).setPointerCapture(e.pointerId);
            drag.current = {
              x: e.clientX,
              y: e.clientY,
              lat: view.current.lat,
              lon: view.current.lon,
            };
          }}
          onPointerMove={(e) => {
            const d = drag.current;
            if (!d) return;
            const k = 120 / (canvas.current?.clientWidth || 240); // degrees per pixel
            view.current = {
              lat: Math.max(-80, Math.min(80, d.lat + (e.clientY - d.y) * k)),
              lon: wrapLon(d.lon - (e.clientX - d.x) * k),
            };
            redraw();
          }}
          onPointerUp={() => {
            drag.current = null;
          }}
          onPointerCancel={() => {
            drag.current = null;
          }}
          onKeyDown={(e) => {
            const step = e.shiftKey ? 30 : 10;
            if (e.key === "ArrowLeft") turn(-step, 0);
            else if (e.key === "ArrowRight") turn(step, 0);
            else if (e.key === "ArrowUp") turn(0, step);
            else if (e.key === "ArrowDown") turn(0, -step);
            else return;
            e.preventDefault();
          }}
        />
      </div>
      <div className="flex items-center justify-between gap-2 text-[11px] text-muted-foreground">
        <span>Dark side = night right now. Drag or use arrow keys to turn.</span>
        {home && (
          <button
            type="button"
            className="ax-press ax-tap ax-focus shrink-0 rounded px-1 font-semibold text-foreground underline-offset-4 hover:underline"
            onClick={() => {
              view.current = { lat: 18, lon: home.lon };
              setTick((n) => n + 1);
            }}
          >
            Face {home.label}
          </button>
        )}
      </div>
    </div>
  );
}
