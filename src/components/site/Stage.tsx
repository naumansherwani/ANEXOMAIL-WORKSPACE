import type { ReactNode } from "react";

/**
 * Rule 4 — pacing. Sections declare their own volume instead of
 * repeating one padding and one grid down the page.
 */
const tone = {
  loud: "py-28 md:py-40",
  quiet: "py-20 md:py-24",
  hush: "py-24 md:py-32",
} as const;

export function Stage({
  children,
  id,
  volume = "quiet",
  divider = true,
  className,
}: {
  children: ReactNode;
  id?: string;
  volume?: keyof typeof tone;
  divider?: boolean;
  className?: string;
}) {
  return (
    <section id={id} className={`relative ${tone[volume]} ${className ?? ""}`}>
      {divider && (
        <div aria-hidden className="ax-hairline absolute inset-x-0 top-0 h-px" />
      )}
      <div className="ax-container relative">{children}</div>
    </section>
  );
}
