/**
 * FxAmbient — workspace ka "cinematic" ambient layer (founder 21 Oct 2026: graphics real aur live hon, toggle se on/off).
 * Sirf CSS (GPU transform/opacity) — phone/tablet par bhi halka. Plan ke rang mein:
 *   Basic neela · Pro jamuni · Business sunehri · Business Pro Imperial Ruby + Platinum.
 * Settings -> Appearance -> Graphics OFF / calm mode / OS reduced-motion => css (styles.css, "FX AMBIENT") isay chhupa/rok deti hai.
 */
import { orbFor } from "@/lib/fx";

export function FxAmbient({ plan }: { plan?: string | null }) {
  const o = orbFor(plan);
  return (
    <div
      aria-hidden
      className="ax-fx-ambient pointer-events-none fixed inset-0 z-[5]"
      style={{ ["--fx-core" as string]: o.core, ["--fx-glow" as string]: o.glow, ["--fx-ring" as string]: o.ring ?? o.glow }}
    >
      <span className="ax-fx-edge" />
    </div>
  );
}
