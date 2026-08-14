/**
 * ANEXOChat — CINEMATIC WEATHER SCENE (Phase 7).
 *
 * Stack: React Three Fiber + drei + postprocessing + GSAP + Rapier + Tone.js.
 * FOUNDER LOCK:
 *   - Yeh scene sirf DIKHATA hai jo Open-Meteo ne bataya ya user ne chuna.
 *     Khud se kabhi weather tay nahi karta.
 *   - Calm Mode par yeh component unmount hota hai (poora dispose).
 *   - Mobile par particle count budget se aadha (chat-cinema.ts).
 */
import { Cloud, Sky, Stars } from "@react-three/drei";
import { Canvas, useFrame } from "@react-three/fiber";
import { Bloom, EffectComposer, Vignette } from "@react-three/postprocessing";
import gsap from "gsap";
import { useEffect, useMemo, useRef } from "react";
import * as THREE from "three";

import type { AtmosphereEffect, TimeBand } from "@/lib/chat-atmosphere";
import { cinemaBudget, type CinemaQuality } from "@/lib/chat-cinema";

const BAND_SUN: Record<TimeBand, [number, number, number]> = {
  dawn: [-1, 0.16, -2],
  day: [1, 1, 1],
  dusk: [1, 0.14, -2],
  night: [0, -1, 0],
};

const BAND_LIGHT: Record<TimeBand, number> = { dawn: 0.5, day: 0.9, dusk: 0.45, night: 0.18 };

/** Rain / snow particles. Rain = fast vertical streaks, snow = drifting flakes. */
function Precipitation({
  count,
  kind,
}: {
  count: number;
  kind: "rain" | "snow";
}) {
  const points = useRef<THREE.Points>(null);
  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      arr[i * 3] = (Math.random() - 0.5) * 26;
      arr[i * 3 + 1] = Math.random() * 18;
      arr[i * 3 + 2] = (Math.random() - 0.5) * 14;
    }
    return arr;
  }, [count]);

  const speed = kind === "rain" ? 16 : 1.8;

  useFrame((_, delta) => {
    const geo = points.current?.geometry as THREE.BufferGeometry | undefined;
    if (!geo) return;
    const attr = geo.getAttribute("position") as THREE.BufferAttribute;
    const arr = attr.array as Float32Array;
    for (let i = 0; i < count; i += 1) {
      const y = i * 3 + 1;
      const cur = arr[y] ?? 0;
      const next = cur - speed * delta * (0.7 + Math.random() * 0.6);
      arr[y] = next;
      if (kind === "snow") arr[i * 3] = (arr[i * 3] ?? 0) + Math.sin(next * 0.6) * delta * 0.35;
      if (next < -2) {
        arr[y] = 18;
        arr[i * 3] = (Math.random() - 0.5) * 26;
      }
    }
    attr.needsUpdate = true;
  });

  return (
    <points ref={points}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial
        transparent
        depthWrite={false}
        size={kind === "rain" ? 0.055 : 0.11}
        color={kind === "rain" ? "#cfe4ff" : "#ffffff"}
        opacity={kind === "rain" ? 0.55 : 0.8}
      />
    </points>
  );
}

/** GSAP-driven lightning: random timeline flashes, cleaned up on unmount. */
function Lightning() {
  const light = useRef<THREE.PointLight>(null);
  useEffect(() => {
    if (!light.current) return;
    const target = light.current;
    const tl = gsap.timeline({ repeat: -1, repeatDelay: 4.5 });
    tl.to(target, { intensity: 26, duration: 0.06 })
      .to(target, { intensity: 0, duration: 0.09 })
      .to(target, { intensity: 18, duration: 0.05, delay: 0.09 })
      .to(target, { intensity: 0, duration: 0.22 });
    return () => {
      tl.kill();
    };
  }, []);
  return <pointLight ref={light} position={[4, 9, 2]} intensity={0} color="#dbe9ff" />;
}

function Aurora() {
  const mesh = useRef<THREE.Mesh>(null);
  useFrame(({ clock }) => {
    if (!mesh.current) return;
    mesh.current.position.x = Math.sin(clock.elapsedTime * 0.12) * 2.2;
    (mesh.current.material as THREE.MeshBasicMaterial).opacity =
      0.1 + Math.abs(Math.sin(clock.elapsedTime * 0.25)) * 0.12;
  });
  return (
    <mesh ref={mesh} position={[0, 7, -9]} rotation={[0, 0, 0.18]}>
      <planeGeometry args={[34, 9, 1, 1]} />
      <meshBasicMaterial color="#4de2c0" transparent opacity={0.14} depthWrite={false} />
    </mesh>
  );
}

export default function Scene({
  band,
  effect,
  quality,
}: {
  band: TimeBand;
  effect: AtmosphereEffect;
  quality: CinemaQuality;
}) {
  const budget = useMemo(() => cinemaBudget(quality, effect, band), [quality, effect, band]);
  const rain = effect === "rain" || effect === "storm";
  const snow = effect === "snow";

  return (
    <Canvas
      dpr={budget.dpr}
      frameloop="always"
      camera={{ position: [0, 3.2, 12], fov: 55 }}
      gl={{ antialias: budget.quality === "high", powerPreference: "low-power" }}
      style={{ position: "absolute", inset: 0 }}
    >
      <ambientLight intensity={BAND_LIGHT[band]} />
      <directionalLight position={BAND_SUN[band]} intensity={band === "night" ? 0.1 : 0.7} />

      {band === "night" ? (
        <>
          <Stars radius={70} depth={30} count={budget.stars} factor={3} fade speed={0.6} />
          <mesh position={[-6, 8, -14]}>
            <sphereGeometry args={[1.1, 24, 24]} />
            <meshBasicMaterial color="#f4f1e4" />
          </mesh>
          <Aurora />
        </>
      ) : (
        <Sky
          sunPosition={BAND_SUN[band]}
          turbidity={effect === "storm" ? 18 : effect === "rain" ? 12 : 4}
          rayleigh={band === "dawn" || band === "dusk" ? 3.2 : 1.2}
        />
      )}

      {budget.clouds ? (
        <Cloud position={[0, 8, -6]} opacity={effect === "storm" ? 0.5 : 0.3} speed={0.2} />
      ) : null}

      {rain && budget.particles > 0 ? <Precipitation count={budget.particles} kind="rain" /> : null}
      {snow && budget.particles > 0 ? <Precipitation count={budget.particles} kind="snow" /> : null}
      {effect === "storm" ? <Lightning /> : null}

      {budget.bloom ? (
        <EffectComposer>
          <Bloom intensity={effect === "sunny" ? 0.9 : 0.35} luminanceThreshold={0.35} mipmapBlur />
          <Vignette eskil={false} offset={0.24} darkness={band === "night" ? 0.75 : 0.4} />
        </EffectComposer>
      ) : null}
    </Canvas>
  );
}
