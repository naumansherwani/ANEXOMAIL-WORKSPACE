/** Plans page — cards par halka 3D tilt (pointer / touch). FX off ho to seedha ek normal wrapper. */
import { useRef, type ReactNode } from "react";

import { useFxTier } from "@/lib/fx";

export function TiltCard({ children, className = "" }: { children: ReactNode; className?: string }) {
  const tier = useFxTier();
  const ref = useRef<HTMLDivElement>(null);
  const max = tier === "full" ? 7 : 4;
  const move = (e: React.PointerEvent) => {
    const el = ref.current;
    if (!el || tier === "off") return;
    const r = el.getBoundingClientRect();
    const px = (e.clientX - r.left) / r.width - 0.5;
    const py = (e.clientY - r.top) / r.height - 0.5;
    el.style.transform = `perspective(900px) rotateX(${(-py * max).toFixed(2)}deg) rotateY(${(px * max).toFixed(2)}deg) translateZ(0)`;
  };
  const reset = () => {
    if (ref.current) ref.current.style.transform = "";
  };
  return (
    <div
      ref={ref}
      onPointerMove={move}
      onPointerLeave={reset}
      onPointerUp={reset}
      onPointerCancel={reset}
      className={`${className} ${tier === "off" ? "" : "transition-transform duration-200 ease-out will-change-transform"}`}
    >
      {children}
    </div>
  );
}
