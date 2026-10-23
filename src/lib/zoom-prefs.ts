/**
 * In-context zoom — SIRF wahan jahan content dense ya lamba hai (founder 23 Oct 2026: "jahan zaroorat hai wahan, jahan nahi wahan nahi"):
 *   - mail padhne ki body (A- / A+)
 *   - calendar Week/Day ke ghante ki unchai (- / +)
 * Baaqi screens par koi zoom control nahi: wahan Settings -> Appearance -> Text size aur pinch-zoom kaafi hain.
 * Har choice device par yaad rehti hai (localStorage), aur ek hi jagah badalne par baaki jagah bhi turant.
 */
import { useCallback, useEffect, useState } from "react";

export const READ_ZOOMS = [85, 100, 115, 130, 150, 175] as const;
export const HOUR_PX = [36, 52, 72, 96] as const;

export type StepSpec<T extends number> = { key: string; steps: readonly T[]; base: T };
export const READ_ZOOM: StepSpec<(typeof READ_ZOOMS)[number]> = {
  key: "ax.readZoom",
  steps: READ_ZOOMS,
  base: 100,
};
export const GRID_HOUR: StepSpec<(typeof HOUR_PX)[number]> = {
  key: "ax.gridHour",
  steps: HOUR_PX,
  base: 52,
};

/** Kisi bhi galat/purani value ko list ki sabse qareebi theek value par laata hai. */
export function cleanStep<T extends number>(steps: readonly T[], base: T, v: unknown): T {
  const n = typeof v === "string" ? Number(v) : typeof v === "number" ? v : NaN;
  if (!Number.isFinite(n)) return base;
  return steps.reduce(
    (best, s) => (Math.abs(s - n) < Math.abs(best - n) ? s : best),
    steps[0] as T,
  );
}

/** dir = +1 (bada) / -1 (chhota). Kinare par ruk jata hai. */
export function stepFrom<T extends number>(steps: readonly T[], cur: T, dir: 1 | -1): T {
  const i = steps.indexOf(cur);
  const at = i < 0 ? steps.findIndex((s) => s >= cur) : i;
  const next = Math.min(steps.length - 1, Math.max(0, (at < 0 ? steps.length - 1 : at) + dir));
  return steps[next] as T;
}

export function useStoredStep<T extends number>(spec: StepSpec<T>) {
  const [value, setValue] = useState<T>(spec.base);

  const read = useCallback((): T => {
    try {
      const raw = window.localStorage.getItem(spec.key);
      return raw === null ? spec.base : cleanStep(spec.steps, spec.base, raw);
    } catch {
      return spec.base;
    }
  }, [spec]);

  useEffect(() => {
    setValue(read());
    const on = () => setValue(read());
    window.addEventListener("ax:zoom", on);
    window.addEventListener("storage", on);
    return () => {
      window.removeEventListener("ax:zoom", on);
      window.removeEventListener("storage", on);
    };
  }, [read]);

  const step = useCallback(
    (dir: 1 | -1) => {
      const next = stepFrom(spec.steps, read(), dir);
      try {
        window.localStorage.setItem(spec.key, String(next));
      } catch {
        /* private mode — is tab ke liye chalega */
      }
      setValue(next);
      window.dispatchEvent(new Event("ax:zoom"));
    },
    [read, spec],
  );

  const reset = useCallback(() => {
    try {
      window.localStorage.removeItem(spec.key);
    } catch {
      /* ignore */
    }
    setValue(spec.base);
    window.dispatchEvent(new Event("ax:zoom"));
  }, [spec]);

  const first = spec.steps[0] as T;
  const last = spec.steps[spec.steps.length - 1] as T;
  return { value, step, reset, canOut: value > first, canIn: value < last };
}
