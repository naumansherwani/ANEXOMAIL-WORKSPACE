import { motion, type HTMLMotionProps } from "motion/react";

const EASE = [0.16, 1, 0.3, 1] as const;

/**
 * Rule 3 — reveal, not slide. A curtain opens from the baseline.
 * One easing, one duration band across the whole site.
 */
export function Reveal({
  delay = 0,
  duration = 0.7,
  ...rest
}: HTMLMotionProps<"div"> & { delay?: number; duration?: number }) {
  return (
    <motion.div
      initial={{ clipPath: "inset(0 0 100% 0)", opacity: 0 }}
      whileInView={{ clipPath: "inset(0 0 0% 0)", opacity: 1 }}
      viewport={{ once: true, margin: "-12% 0px" }}
      transition={{ duration, delay, ease: EASE }}
      {...rest}
    />
  );
}

export { EASE };
