/**
 * ANEXOChat · PHASE 11 — LOTTIE TICK STATES
 *
 * waiting/sending = Lottie (lottie-react) pulsing dot, sent/delivered/read =
 * GSAP stroke-draw check(s). Text label saath rehta hai (a11y + sach), lekin
 * state ab dikhai bhi deti hai. Koi state invent nahi hoti — `messageState()`
 * hi source hai.
 */
import gsap from "gsap";
import Lottie from "lottie-react";
import { useEffect, useRef } from "react";

import { STATE_LABEL, type MessageState } from "@/lib/chat";

/** Chhota inline Lottie — koi network fetch, koi extra asset nahi. */
const PULSE = {
  v: "5.7.4",
  fr: 30,
  ip: 0,
  op: 30,
  w: 24,
  h: 24,
  nm: "pulse",
  ddd: 0,
  assets: [],
  layers: [
    {
      ddd: 0,
      ind: 1,
      ty: 4,
      nm: "dot",
      sr: 1,
      ao: 0,
      ks: {
        o: {
          a: 1,
          k: [
            { t: 0, s: [100], e: [30] },
            { t: 15, s: [30], e: [100] },
            { t: 30 },
          ],
        },
        r: { a: 0, k: 0 },
        p: { a: 0, k: [12, 12, 0] },
        a: { a: 0, k: [0, 0, 0] },
        s: {
          a: 1,
          k: [
            { t: 0, s: [100, 100, 100], e: [55, 55, 100] },
            { t: 15, s: [55, 55, 100], e: [100, 100, 100] },
            { t: 30 },
          ],
        },
      },
      shapes: [
        {
          ty: "gr",
          it: [
            { ty: "el", p: { a: 0, k: [0, 0] }, s: { a: 0, k: [12, 12] } },
            { ty: "fl", c: { a: 0, k: [0.55, 0.58, 0.63, 1] }, o: { a: 0, k: 100 } },
            {
              ty: "tr",
              p: { a: 0, k: [0, 0] },
              a: { a: 0, k: [0, 0] },
              s: { a: 0, k: [100, 100] },
              r: { a: 0, k: 0 },
              o: { a: 0, k: 100 },
            },
          ],
        },
      ],
      ip: 0,
      op: 30,
      st: 0,
      bm: 0,
    },
  ],
} as const;

function Checks({ double, read }: { double: boolean; read: boolean }) {
  const ref = useRef<SVGSVGElement>(null);

  useEffect(() => {
    const paths = ref.current?.querySelectorAll("path");
    if (!paths?.length) return;
    const tween = gsap.fromTo(
      paths,
      { strokeDasharray: 24, strokeDashoffset: 24 },
      { strokeDashoffset: 0, duration: 0.32, stagger: 0.07, ease: "power2.out" },
    );
    return () => {
      tween.kill();
    };
  }, [double, read]);

  return (
    <svg
      ref={ref}
      viewBox="0 0 20 12"
      className={"size-3.5 " + (read ? "text-primary" : "text-muted-foreground")}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M1 7.2 4.2 10.4 10.6 2.2" />
      {double ? <path d="M8.4 7.2 11.6 10.4 18 2.2" /> : null}
    </svg>
  );
}

export function Tick({ state }: { state: MessageState }) {
  const label = STATE_LABEL[state];

  if (state === "sending" || state === "waiting") {
    return (
      <span className="inline-flex items-center gap-1" title={label}>
        <Lottie animationData={PULSE} loop autoplay style={{ width: 14, height: 14 }} />
        <span className="sr-only">{label}</span>
      </span>
    );
  }

  if (state === "failed") {
    return (
      <span className="inline-flex size-3.5 items-center justify-center rounded-full border border-destructive text-[9px] font-bold text-destructive" title={label}>
        !
      </span>
    );
  }

  return (
    <span className="inline-flex items-center" title={label}>
      <Checks double={state === "delivered" || state === "read"} read={state === "read"} />
      <span className="sr-only">{label}</span>
    </span>
  );
}
