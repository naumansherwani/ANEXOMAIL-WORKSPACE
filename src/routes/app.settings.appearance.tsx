import { createFileRoute } from "@tanstack/react-router";
import { Sparkles } from "lucide-react";

import { SettingsScope } from "@/components/app/settings/SettingsBits";
import { Segmented, Toggle } from "@/components/app/premium/PremiumBits";
import { celebrate, useExperience, type Animations, type Speed } from "@/lib/experience";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/settings/appearance")({
  component: AppearancePage,
});

/**
 * Phase 29 — the motion and delight switches live on the device, not the server:
 * they must apply instantly with no round trip and no reload.
 */
function AppearancePage() {
  const exp = useExperience();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 pt-8 md:px-8">
        <p className="ax-eyebrow inline-flex items-center gap-1.5">
          <Sparkles className="size-3.5" aria-hidden="true" /> This device
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Motion & delight</h2>
        <p className="ax-caption mt-1 text-muted-foreground">
          Applies the moment you tap it — no save button, no reload. Your operating system's
          reduced-motion setting always wins on top of this.
        </p>

        <div className="mt-ax-4 grid gap-ax-2">
          <Segmented<Animations>
            label="Animations"
            hint="Full keeps the whole motion language · Reduced fades only, nothing travels · None is complete stillness (calm mode)."
            value={exp.animations}
            options={[
              { value: "full", label: "Full" },
              { value: "reduced", label: "Reduced" },
              { value: "none", label: "None" },
            ]}
            onChange={(v) => {
              exp.set({ animations: v });
              notify.done(
                v === "none"
                  ? "Calm mode on — the workspace is still"
                  : v === "reduced"
                    ? "Reduced animations — fades only"
                    : "Full motion restored",
              );
            }}
          />
          <Segmented<Speed>
            label="Transitions"
            hint="The tempo of every panel, hover and reveal. Fast is 0.6× the standard clock, slow is 1.5×."
            value={exp.speed}
            options={[
              { value: "fast", label: "Fast" },
              { value: "normal", label: "Normal" },
              { value: "slow", label: "Slow" },
            ]}
            onChange={(v) => exp.set({ speed: v })}
          />
          <Toggle
            label="Celebration (earned delight)"
            hint="On by default. Fires only when work is genuinely finished — inbox zero, a promise kept, your domain proven green."
            checked={exp.delight}
            onChange={(v) => {
              exp.set({ delight: v });
              if (v && !exp.calm) celebrate("inbox-zero");
            }}
            disabled={exp.calm}
            disabledNote="Animations are set to None — celebration stays silent until you allow motion again."
          />
          <Toggle
            label="High-contrast focus ring"
            hint="Makes the keyboard position unmistakable — useful on projectors and for accessibility reviews."
            checked={exp.focusAudit}
            onChange={(v) => exp.set({ focusAudit: v })}
          />
        </div>

        <p className="mt-ax-3 text-[11px] text-muted-foreground">
          Operating system reduced-motion:{" "}
          <span className="text-foreground">{exp.osReduced ? "on — motion suppressed" : "off"}</span> · motion currently{" "}
          <span className="text-foreground">{exp.motionAllowed ? "allowed" : "suppressed"}</span>
        </p>
      </div>

      <SettingsScope
        scope="appearance"
        title="Appearance"
        blurb="Density and theme, stored on your account. Instant, no reload, no layout jump."
      />
    </div>
  );
}
