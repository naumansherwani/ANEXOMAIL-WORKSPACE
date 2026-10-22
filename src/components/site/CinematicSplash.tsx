import { useEffect, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";

import { BrandMark } from "@/components/site/BrandMark";

type Props = {
  open: boolean;
  /** false = the next surface is not ready yet (sign-in still working): keep holding, never exit early. Default true. */
  ready?: boolean;
  onDone?: () => void;
};

/**
 * Cinematic sign-in "move-in" moment.
 * Shown after every successful authentication before routing the user into
 * the workspace. Replaces the default spinner with the ANEXOMAIL mark,
 * key light, grain and a quiet exit to the next surface.
 */
export function CinematicSplash({ open, ready = true, onDone }: Props) {
  const [phase, setPhase] = useState<"closed" | "enter" | "hold" | "exit">("closed");
  const homeClicked = useRef(false);
  const startedAt = useRef(0);

  useEffect(() => {
    if (!open) {
      setPhase("closed");
      homeClicked.current = false;
      return;
    }
    startedAt.current = Date.now();
    setPhase("enter");
    const hold = setTimeout(() => setPhase((p) => (p === "enter" ? "hold" : p)), 700);
    return () => clearTimeout(hold);
  }, [open]);

  // Exit only after the minimum show time AND when the destination is ready — so a slow sign-in holds the splash
  // instead of flashing away and leaving a blank gap.
  useEffect(() => {
    if (!open || !ready || phase === "closed" || phase === "exit") return;
    const wait = Math.max(0, 2200 - (Date.now() - startedAt.current));
    const exit = setTimeout(() => setPhase("exit"), wait);
    return () => clearTimeout(exit);
  }, [open, ready, phase]);

  useEffect(() => {
    if (phase !== "exit") return;
    const done = setTimeout(() => {
      if (!homeClicked.current) onDone?.();
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
        <Link
          to="/"
          className="ax-focus scale-[2.2] rounded-sm md:scale-[2.6]"
          aria-label="ANEXOMAIL — go to landing"
          onClick={() => {
            homeClicked.current = true;
          }}
        >
          <BrandMark home={false} />
        </Link>
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
