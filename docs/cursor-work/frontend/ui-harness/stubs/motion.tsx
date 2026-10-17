// Harness stand-in for motion/react + framer-motion: renders the FINAL (revealed) state of every motion element
// so layout can be audited at 390/820/1440. Animation props are dropped; nothing here is shipped.
import * as React from "react";

const DROP = new Set([
  "initial", "animate", "exit", "transition", "variants", "whileInView", "whileHover", "whileTap", "whileFocus",
  "whileDrag", "viewport", "layout", "layoutId", "layoutDependency", "onAnimationComplete", "onAnimationStart",
  "custom", "drag", "dragConstraints", "dragElastic", "onViewportEnter", "onViewportLeave", "inherit",
]);
const cache = new Map<string, React.ComponentType<Record<string, unknown>>>();
const make = (tag: string) => {
  let c = cache.get(tag);
  if (!c) {
    c = React.forwardRef<unknown, Record<string, unknown>>((props, ref) => {
      const rest: Record<string, unknown> = {};
      for (const k of Object.keys(props)) if (!DROP.has(k)) rest[k] = props[k];
      // MotionValue-driven styles are not reproduced; keep only plain values.
      if (rest.style && typeof rest.style === "object") {
        const st: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(rest.style as Record<string, unknown>)) if (typeof v !== "object" || v === null) st[k] = v;
        rest.style = st;
      }
      return React.createElement(tag, { ...rest, ref });
    }) as unknown as React.ComponentType<Record<string, unknown>>;
    cache.set(tag, c);
  }
  return c;
};
export const motion = new Proxy({}, { get: (_t, tag: string) => make(tag) }) as Record<string, React.ComponentType<Record<string, unknown>>>;
export const AnimatePresence = ({ children }: { children?: React.ReactNode }) => <>{children}</>;
export const MotionConfig = ({ children }: { children?: React.ReactNode }) => <>{children}</>;
export const LayoutGroup = MotionConfig;
const mv = (v: unknown) => ({ get: () => v, set: () => undefined, on: () => () => undefined });
export const useMotionValue = (v: unknown) => mv(v);
export const useSpring = (v: unknown) => mv(v);
export const useTransform = () => mv(0);
export const useScroll = () => ({ scrollY: mv(0), scrollYProgress: mv(0), scrollX: mv(0), scrollXProgress: mv(0) });
export const useInView = () => true;
export const useReducedMotion = () => false;
export const useAnimation = () => ({ start: async () => undefined, stop: () => undefined });
export type HTMLMotionProps<T extends string> = React.HTMLAttributes<HTMLElement> & { _t?: T };
