import { useEffect, useState } from "react";

import { BrandMark } from "@/components/site/BrandMark";

type Props = {
  open: boolean;
  onDone?: () => void;
};

/**
 * Cinematic sign-in "move-in" moment.
 * Shown after every successful authentication before routing the user into
 * the workspace. Replaces the default spinner with the ANEXOMAIL mark,
 * key light, grain and a quiet exit to the next surface.
 */
export function CinematicSplash({ open, onDone }: Props) {
  const [phase, setPhase] = useState<"closed" | "enter" | "hold" | "exit">("closed");

  useEffect(() => {
    if (!open) {
      setPhase("closed");
      return;
    }
    setPhase("enter");
    const hold = setTimeout(() => setPhase("hold"), 700);
    const exit = setTimeout(() => setPhase("exit"), 2200);
    return () => {
      clearTimeout(hold);
      clearTimeout(exit);
    };
  }, [open]);

  useEffect(() => {
    if (phase !== "exit") return;
    const done = setTimeout(() => {
      onDone?.();
      setPhase("closed");
    }, 600);
    return () => clearTimeout(done);
  }, [phase, onDone]);

  if (phase === "closed") return null;

  return (
    <div
      aria-hidden
      className={`ax-splash-stage fixed inset-0 z-[100] flex flex-col items-center justify-center bg-background ${
        phase === "exit" ? "ax-splash-exit" : "ax-splash-enter"
      }`}
    >
      <div className="ax-splash-vignette pointer-events-none absolute inset-0" />
      <div className="ax-splash-grain pointer-events-none absolute inset-0" />
      <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
        <div className="ax-splash-keylight h-[28rem] w-[28rem] rounded-full blur-[120px] md:h-[32rem] md:w-[32rem]" />
      </div>

      <div className="ax-splash-logo relative z-10 flex flex-col items-center">
        <div className="scale-[2.2] md:scale-[2.6]">
          <BrandMark />
        </div>
        <h2 className="ax-platinum-text mt-ax-7 text-center text-[1.625rem] font-extrabold tracking-[-0.03em] md:text-[2rem]">
          ANEXOMAIL Workspace
        </h2>
        <p className="ax-body mt-ax-2 max-w-[16rem] text-center md:max-w-[18rem]">
          Your mail, people, calendar and work — one surface.
        </p>
      </div>

      <div className="absolute bottom-ax-6 left-0 right-0 text-center">
        <p className="ax-caption text-steel">Opening your workspace…</p>
      </div>
    </div>
  );
}
