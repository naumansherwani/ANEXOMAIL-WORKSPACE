/** Khali inbox / khali calendar — chhoti 3D tasveer (sirf jab list khali ho). */
import { useFrame } from "@react-three/fiber";
import { useRef } from "react";
import * as THREE from "three";

import { Stage } from "./Stage";
import type { SceneProps } from "./Fx3D";

function Envelope() {
  const g = useRef<THREE.Group>(null);
  const flap = useRef<THREE.Mesh>(null);
  useFrame(({ clock }) => {
    const t = clock.elapsedTime;
    if (g.current) { g.current.rotation.y = Math.sin(t * 0.7) * 0.5; g.current.position.y = Math.sin(t * 1.2) * 0.08; }
    if (flap.current) flap.current.rotation.x = -0.3 - (Math.sin(t * 1.1) * 0.5 + 0.5) * 0.9;
  });
  return (
    <group ref={g}>
      <mesh><boxGeometry args={[2, 1.3, 0.12]} /><meshStandardMaterial color="#f1f5f9" metalness={0.2} roughness={0.5} /></mesh>
      <mesh ref={flap} position={[0, 0.65, 0.07]}>
        <coneGeometry args={[1.15, 0.7, 3]} />
        <meshStandardMaterial color="#38bdf8" metalness={0.4} roughness={0.35} emissive="#0369a1" emissiveIntensity={0.3} />
      </mesh>
    </group>
  );
}

function CalendarPage() {
  const g = useRef<THREE.Group>(null);
  useFrame(({ clock }) => {
    if (g.current) { g.current.rotation.y = Math.sin(clock.elapsedTime * 0.7) * 0.55; g.current.position.y = Math.sin(clock.elapsedTime * 1.2) * 0.08; }
  });
  return (
    <group ref={g}>
      <mesh><boxGeometry args={[1.8, 1.7, 0.16]} /><meshStandardMaterial color="#f8fafc" roughness={0.5} /></mesh>
      <mesh position={[0, 0.65, 0.02]}><boxGeometry args={[1.8, 0.4, 0.18]} /><meshStandardMaterial color="#2563eb" metalness={0.4} roughness={0.35} /></mesh>
      {[-0.55, 0.55].map((x) => (
        <mesh key={x} position={[x, 0.9, 0]}><cylinderGeometry args={[0.07, 0.07, 0.35, 12]} /><meshStandardMaterial color="#cbd5e1" metalness={0.9} roughness={0.2} /></mesh>
      ))}
      {[-0.5, 0, 0.5].map((x) => [-0.1, -0.5].map((y) => (
        <mesh key={`${x}${y}`} position={[x, y, 0.1]}><boxGeometry args={[0.3, 0.26, 0.04]} /><meshStandardMaterial color="#93c5fd" /></mesh>
      )))}
    </group>
  );
}

export default function GemScene({ tier, active, variant }: SceneProps) {
  return (
    <Stage tier={tier} active={active} camera={[0, 0, 4.6]} fov={38}>
      {variant === "calendar" ? <CalendarPage /> : <Envelope />}
    </Stage>
  );
}
