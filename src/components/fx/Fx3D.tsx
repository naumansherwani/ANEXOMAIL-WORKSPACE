/**
 * Fx3D — har 3D scene ka darwaza. Page pehle chalta hai (fallback turant dikhta hai), 3D baad mein lazy-load hota hai.
 * Rules: Graphics OFF / calm / reduced-motion => kuch load nahi hota. Screen se bahar => render rukta hai. Tab hidden => rukta hai.
 * Koi bhi 3D error => fallback hi rehta hai (page kabhi nahi tootta). Ek page par kam se kam canvases.
 */
import { Component, lazy, Suspense, useEffect, useRef, useState, type ReactNode } from "react";

import { useFxTier, type FxTier } from "@/lib/fx";

const MailboxScene = lazy(() => import("./MailboxScene"));
const LogoScene = lazy(() => import("./LogoScene"));
const OrbScene = lazy(() => import("./OrbScene"));
const GemScene = lazy(() => import("./GemScene"));

export type SceneProps = { tier: Exclude<FxTier, "off">; active: boolean; plan?: string; variant?: "inbox" | "calendar" };
export type SceneName = "mailbox" | "logo" | "orb" | "gem";

/** Lazy scene ke mount hone par ek baar bolta hai ("3D ab screen par hai") — Suspense ke andar sirf resolve ke baad chalta hai. */
function Ready({ onReady }: { onReady: () => void }) {
  useEffect(() => {
    // 2 frame ruko: canvas ka pehla frame paint ho chuke, tab fallback hatao (khali jhalak na aaye)
    let a = requestAnimationFrame(() => {
      a = requestAnimationFrame(onReady);
    });
    return () => cancelAnimationFrame(a);
  }, [onReady]);
  return null;
}

class Guard extends Component<{ children: ReactNode; fallback: ReactNode; onBad?: () => void }, { bad: boolean }> {
  state = { bad: false };
  static getDerivedStateFromError() {
    return { bad: true };
  }
  componentDidCatch() {
    /* 3D fail ho to fallback — kuch aur nahi tootta */
    this.props.onBad?.();
  }
  render() {
    return this.state.bad ? this.props.fallback : this.props.children;
  }
}

export function Fx3D({
  scene,
  className = "",
  fallback = null,
  plan,
  variant,
  label,
  hideFallbackWhenLive = false,
}: {
  scene: SceneName;
  className?: string;
  fallback?: ReactNode;
  plan?: string;
  variant?: "inbox" | "calendar";
  label?: string;
  /** true: jab 3D asli mein chal pade to 2D fallback chhup jaye (transparent canvas ke neeche dobara logo na dikhe). 3D fail ho to fallback wapas. */
  hideFallbackWhenLive?: boolean;
}) {
  const tier = useFxTier();
  const [live3d, setLive3d] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const [seen, setSeen] = useState(false);
  const [active, setActive] = useState(false);
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const el = ref.current;
    if (!el || tier === "off") return;
    const io = new IntersectionObserver(
      ([e]) => {
        setActive(e.isIntersecting);
        if (e.isIntersecting) setSeen(true);
      },
      { rootMargin: "80px" },
    );
    io.observe(el);
    const vis = () => setVisible(document.visibilityState === "visible");
    document.addEventListener("visibilitychange", vis);
    return () => {
      io.disconnect();
      document.removeEventListener("visibilitychange", vis);
    };
  }, [tier]);

  const live = tier !== "off" && seen;
  const props: SceneProps | null = live ? { tier: tier as Exclude<FxTier, "off">, active: active && visible, plan, variant } : null;

  return (
    <div ref={ref} className={`relative ${className}`} data-fx-scene={scene} role="img" aria-label={label ?? "Decorative 3D scene"}>
      {/* fallback hamesha neeche — 3D aane tak ya na aane par bhi jagah bhari rehti hai */}
      <div
        className="absolute inset-0 flex items-center justify-center transition-opacity duration-300"
        style={hideFallbackWhenLive && live3d ? { opacity: 0 } : undefined}
        aria-hidden
      >
        {fallback}
      </div>
      {props && (
        <Guard fallback={null} onBad={() => setLive3d(false)}>
          <Suspense fallback={null}>
            <div className="absolute inset-0">
              {scene === "mailbox" && <MailboxScene {...props} />}
              {scene === "logo" && <LogoScene {...props} />}
              {scene === "orb" && <OrbScene {...props} />}
              {scene === "gem" && <GemScene {...props} />}
            </div>
            <Ready onReady={() => setLive3d(true)} />
          </Suspense>
        </Guard>
      )}
    </div>
  );
}
