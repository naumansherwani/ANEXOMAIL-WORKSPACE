/**
 * FX — ek hi jagah jahan tay hota hai ke 3D / graphics chalein ya nahi (founder 21 Oct 2026).
 *
 * Tier:
 *   "off"  — user ne Settings → Appearance mein Graphics band ki, ya calm / OS reduced-motion, ya Data-saver, ya WebGL nahi.
 *   "lite" — phone / tablet / kamzor device: kam polygons, kam particles, dpr 1.
 *   "full" — laptop / desktop: poora scene, pointer parallax.
 * Sab scenes lazy-load hote hain (pehle page, phir 3D) aur sirf tab chalte hain jab screen par dikhein.
 */
import { useEffect, useState } from "react";

import { useExperience } from "@/lib/experience";

export type FxTier = "off" | "lite" | "full";

/** Plan -> orb rang (PLAN-3D-PARKED.md, CEO faisla 21 Oct 2026). */
export const PLAN_ORB: Record<string, { core: string; glow: string; ring?: string; layers: number; label: string }> = {
  basic: { core: "#3B82F6", glow: "#60A5FA", layers: 1, label: "Basic" },
  pro: { core: "#8B5CF6", glow: "#A78BFA", layers: 2, label: "Pro" },
  business: { core: "#D4A017", glow: "#F2C94C", ring: "#F2D58A", layers: 3, label: "Business" },
  business_pro: { core: "#9B1B30", glow: "#E11D48", ring: "#E5E4E2", layers: 4, label: "Business Pro" },
};

export function orbFor(plan: string | null | undefined) {
  const k = String(plan || "basic").toLowerCase().replace(/[\s-]+/g, "_");
  return PLAN_ORB[k] ?? PLAN_ORB.basic;
}

function webglOk(): boolean {
  try {
    const c = document.createElement("canvas");
    return !!(c.getContext("webgl2") || c.getContext("webgl"));
  } catch {
    return false;
  }
}

function measure(): FxTier {
  if (typeof window === "undefined") return "off";
  const nav = navigator as Navigator & { connection?: { saveData?: boolean }; deviceMemory?: number };
  if (nav.connection?.saveData) return "off";
  if (!webglOk()) return "off";
  const small = window.matchMedia("(max-width: 1023px)").matches;
  const coarse = window.matchMedia("(pointer: coarse)").matches;
  const weak = (nav.deviceMemory ?? 8) <= 2 || (navigator.hardwareConcurrency ?? 8) <= 2;
  return small || coarse || weak ? "lite" : "full";
}

/** Current FX tier; re-evaluates on resize/rotation and whenever Settings change. */
export function useFxTier(): FxTier {
  const exp = useExperience();
  const [tier, setTier] = useState<FxTier>("off");
  useEffect(() => {
    const run = () => setTier(measure());
    run();
    window.addEventListener("resize", run);
    return () => window.removeEventListener("resize", run);
  }, []);
  if (!exp.graphics || !exp.motionAllowed) return "off";
  return tier;
}
