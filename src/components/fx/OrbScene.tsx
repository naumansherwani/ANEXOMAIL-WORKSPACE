/** Dashboard hero — plan ke rang ka 3D orb. Basic neela · Pro jamuni · Business sunehri · Business Pro Imperial Ruby + Platinum. */
import { useFrame } from "@react-three/fiber";
import { useMemo, useRef } from "react";
import * as THREE from "three";

import { orbFor } from "@/lib/fx";
import { Stage } from "./Stage";
import type { SceneProps } from "./Fx3D";

function Orb({ plan, full }: { plan?: string; full: boolean }) {
  const o = orbFor(plan);
  const core = useRef<THREE.Mesh>(null);
  const ring1 = useRef<THREE.Mesh>(null);
  const ring2 = useRef<THREE.Mesh>(null);
  const halo = useRef<THREE.Points>(null);
  const seg = full ? 48 : 24;
  const haloGeo = useMemo(() => {
    const n = full ? 140 : 60;
    const a = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      const r = 1.5 + Math.random() * 0.5, th = Math.random() * Math.PI * 2, ph = Math.acos(2 * Math.random() - 1);
      a[i * 3] = r * Math.sin(ph) * Math.cos(th); a[i * 3 + 1] = r * Math.cos(ph); a[i * 3 + 2] = r * Math.sin(ph) * Math.sin(th);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(a, 3));
    return g;
  }, [full]);
  useFrame(({ clock }) => {
    const t = clock.elapsedTime;
    if (core.current) { core.current.rotation.y = t * 0.5; core.current.rotation.x = Math.sin(t * 0.6) * 0.15; core.current.scale.setScalar(1 + Math.sin(t * 1.6) * 0.025); }
    if (ring1.current) ring1.current.rotation.z = t * 0.6;
    if (ring2.current) ring2.current.rotation.x = Math.PI / 2.4 + Math.sin(t * 0.5) * 0.2;
    if (halo.current) halo.current.rotation.y = -t * 0.18;
  });
  const royal = o.layers >= 4;
  return (
    <group>
      <mesh ref={core}>
        {royal ? <icosahedronGeometry args={[1, full ? 2 : 1]} /> : <sphereGeometry args={[1, seg, seg]} />}
        <meshPhysicalMaterial color={o.core} metalness={royal ? 0.85 : 0.35} roughness={royal ? 0.18 : 0.28} clearcoat={1} clearcoatRoughness={0.1} emissive={o.core} emissiveIntensity={royal ? 0.3 : 0.22} flatShading={royal} />
      </mesh>
      {o.layers >= 2 && (
        <mesh scale={1.22}>
          <sphereGeometry args={[1, seg, seg]} />
          <meshBasicMaterial color={o.glow} transparent opacity={0.13} side={THREE.BackSide} blending={THREE.AdditiveBlending} depthWrite={false} />
        </mesh>
      )}
      {o.ring && (
        <mesh ref={ring1} rotation={[Math.PI / 2.2, 0, 0]}>
          <torusGeometry args={[1.45, royal ? 0.045 : 0.03, 12, full ? 96 : 48]} />
          <meshStandardMaterial color={o.ring} metalness={1} roughness={0.15} emissive={o.ring} emissiveIntensity={0.25} />
        </mesh>
      )}
      {royal && (
        <mesh ref={ring2} rotation={[Math.PI / 2.4, 0.5, 0]}>
          <torusGeometry args={[1.72, 0.025, 12, full ? 96 : 48]} />
          <meshStandardMaterial color="#E5E4E2" metalness={1} roughness={0.12} />
        </mesh>
      )}
      {royal && (
        <points ref={halo} geometry={haloGeo}>
          <pointsMaterial color="#fecdd3" size={full ? 0.035 : 0.05} transparent opacity={0.8} sizeAttenuation depthWrite={false} />
        </points>
      )}
    </group>
  );
}

export default function OrbScene({ tier, active, plan }: SceneProps) {
  return (
    <Stage tier={tier} active={active} camera={[0, 0, 5.6]} fov={34}>
      <Orb plan={plan} full={tier === "full"} />
    </Stage>
  );
}
