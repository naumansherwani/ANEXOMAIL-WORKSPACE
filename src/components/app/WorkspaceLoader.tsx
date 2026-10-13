import { BrandMark } from "@/components/site/BrandMark";
import { useLocale } from "@/lib/i18n";

/**
 * WorkspaceLoader — cinematic "the workspace assembles" loading scene.
 *
 * Original idea: the product IS a three-panel surface, so loading shows the
 * three panels (rail · list · reading) flying in from depth and snapping into
 * place — pure CSS 3D (transform + opacity only, GPU cheap, no WebGL).
 * Runs while /app confirms the session. Respects calm / reduced-motion.
 */
export function WorkspaceLoader({ label }: { label?: string }) {
  const { t } = useLocale();
  return (
    <div
      role="status"
      aria-live="polite"
      className="ax-loader-stage flex min-h-screen flex-col items-center justify-center overflow-hidden bg-background"
    >
      {/* Atmosphere — same light language as the sign-in splash */}
      <div className="ax-splash-vignette pointer-events-none fixed inset-0" />
      <div className="ax-splash-grain pointer-events-none fixed inset-0" />
      <div className="pointer-events-none fixed inset-0 flex items-center justify-center">
        <div className="ax-splash-keylight h-[26rem] w-[26rem] rounded-full blur-[120px]" />
      </div>

      {/* 3D scene — three panels assemble into the workspace */}
      <div className="ax-loader-scene relative" aria-hidden>
        <div className="ax-loader-panel ax-loader-rail">
          <span className="ax-loader-dot" />
          <span className="ax-loader-dot" />
          <span className="ax-loader-dot" />
          <span className="ax-loader-dot" />
        </div>
        <div className="ax-loader-panel ax-loader-list">
          <span className="ax-loader-row" />
          <span className="ax-loader-row" />
          <span className="ax-loader-row" />
          <span className="ax-loader-row" />
          <span className="ax-loader-row" />
        </div>
        <div className="ax-loader-panel ax-loader-read">
          <span className="ax-loader-row ax-loader-row--title" />
          <span className="ax-loader-row" />
          <span className="ax-loader-row" />
          <span className="ax-loader-row ax-loader-row--short" />
        </div>
        <div className="ax-loader-sweep" />
      </div>

      {/* Brand + status */}
      <div className="ax-loader-brand relative z-10 mt-10 flex flex-col items-center">
        <BrandMark home={false} />
        <p className="ax-caption mt-4 text-steel">{label ?? t("Opening your workspace")}</p>
        <div className="ax-loader-progress mt-3" aria-hidden>
          <span />
        </div>
      </div>
    </div>
  );
}
