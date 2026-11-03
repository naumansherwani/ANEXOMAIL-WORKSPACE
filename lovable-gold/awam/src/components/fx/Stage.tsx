import { Canvas } from "@react-three/fiber";
import type { ReactNode } from "react";

/** Shared transparent canvas: dpr capped, render only while visible, no shadows/post-processing (light on phones). */
export function Stage({
  tier,
  active,
  children,
  camera = [0, 0, 5],
  fov = 40,
}: {
  tier: "lite" | "full";
  active: boolean;
  children: ReactNode;
  camera?: [number, number, number];
  fov?: number;
}) {
  return (
    <Canvas
      frameloop={active ? "always" : "never"}
      dpr={tier === "full" ? [1, 1.75] : 1}
      camera={{ position: camera, fov }}
      gl={{ alpha: true, antialias: tier === "full", powerPreference: tier === "full" ? "high-performance" : "low-power" }}
      style={{ background: "transparent" }}
    >
      <ambientLight intensity={0.55} />
      <directionalLight position={[3, 4, 5]} intensity={1.6} />
      <pointLight position={[-4, -2, 3]} intensity={18} color="#7dd3fc" />
      {children}
    </Canvas>
  );
}
