/** Landing hero — dak ke packets ek 3D mailbox mein girte hain (ConvergenceCanvas ka 3D version). */
import { useFrame } from "@react-three/fiber";
import { useMemo, useRef } from "react";
import * as THREE from "three";

import { Stage } from "./Stage";
import type { SceneProps } from "./Fx3D";

function Mailbox({ full }: { full: boolean }) {
  const g = useRef<THREE.Group>(null);
  const flag = useRef<THREE.Mesh>(null);
  useFrame(({ pointer, clock }) => {
    const t = clock.elapsedTime;
    if (g.current) {
      const tx = full ? pointer.x * 0.35 : Math.sin(t * 0.4) * 0.18;
      g.current.rotation.y += (tx - 0.25 - g.current.rotation.y) * 0.05;
      g.current.rotation.x += ((full ? -pointer.y * 0.12 : 0) - g.current.rotation.x) * 0.05;
    }
    if (flag.current) flag.current.rotation.z = -0.2 + Math.sin(t * 1.8) * 0.12;
  });
  return (
    <group ref={g} position={[0, -0.95, 0]}>
      <mesh position={[0, 0.55, 0]}>
        <boxGeometry args={[1.5, 1.1, 1.9]} />
        <meshStandardMaterial color="#1e3a8a" metalness={0.55} roughness={0.35} />
      </mesh>
      <mesh position={[0, 1.1, 0]} rotation={[Math.PI / 2, 0, 0]} scale={[1, 1, 1]}>
        <cylinderGeometry args={[0.75, 0.75, 1.9, full ? 32 : 16, 1, false, 0, Math.PI]} />
        <meshStandardMaterial color="#2563eb" metalness={0.6} roughness={0.3} side={THREE.DoubleSide} />
      </mesh>
      <mesh position={[0, 1.55, 0]}>
        <boxGeometry args={[0.9, 0.04, 0.5]} />
        <meshStandardMaterial color="#0b1220" />
      </mesh>
      <mesh position={[0, -0.1, 0]}>
        <boxGeometry args={[0.35, 1.0, 0.35]} />
        <meshStandardMaterial color="#475569" metalness={0.7} roughness={0.4} />
      </mesh>
      <mesh ref={flag} position={[0.8, 1.0, 0.2]}>
        <boxGeometry args={[0.07, 0.55, 0.12]} />
        <meshStandardMaterial color="#38bdf8" emissive="#0ea5e9" emissiveIntensity={0.6} />
      </mesh>
    </group>
  );
}

function Packets({ count }: { count: number }) {
  const refs = useRef<(THREE.Mesh | null)[]>([]);
  const seeds = useMemo(
    () => Array.from({ length: count }, (_, i) => ({ x: (Math.random() - 0.5) * 2.6, z: (Math.random() - 0.5) * 0.8, off: (i / count) * 3.2, spin: Math.random() * 2 + 0.5 })),
    [count],
  );
  useFrame(({ clock }) => {
    const t = clock.elapsedTime;
    seeds.forEach((s, i) => {
      const m = refs.current[i];
      if (!m) return;
      const p = ((t * 0.55 + s.off) % 3.2) / 3.2; // 0..1 girne ka safar
      const e = p * p; // gravity jaisa tez hota hua
      m.position.set(s.x * (1 - e), 3.2 - e * 4.1, s.z * (1 - e));
      m.rotation.set(p * s.spin * 4, p * s.spin * 3, p * 2);
      const sc = p > 0.82 ? Math.max(0, 1 - (p - 0.82) / 0.18) : 1; // slot mein ghul jata hai
      m.scale.setScalar(0.38 * sc);
    });
  });
  return (
    <>
      {seeds.map((_, i) => (
        <mesh key={i} ref={(el) => void (refs.current[i] = el)}>
          <boxGeometry args={[1, 0.66, 0.08]} />
          <meshStandardMaterial color={i % 3 === 0 ? "#38bdf8" : "#f8fafc"} emissive={i % 3 === 0 ? "#0284c7" : "#94a3b8"} emissiveIntensity={0.35} />
        </mesh>
      ))}
    </>
  );
}

export default function MailboxScene({ tier, active }: SceneProps) {
  return (
    <Stage tier={tier} active={active} camera={[0, 0.4, 6]} fov={38}>
      <Mailbox full={tier === "full"} />
      <Packets count={tier === "full" ? 16 : 7} />
    </Stage>
  );
}
