/** Login / workspace loader — ghoomta hua 3D "A" logo (platinum + neela chamak). */
import { useFrame } from "@react-three/fiber";
import { useMemo, useRef } from "react";
import * as THREE from "three";

import { Stage } from "./Stage";
import type { SceneProps } from "./Fx3D";

function A() {
  const ref = useRef<THREE.Group>(null);
  const geo = useMemo(() => {
    const s = new THREE.Shape();
    s.moveTo(-1, -1.1); s.lineTo(-0.28, 1.1); s.lineTo(0.28, 1.1); s.lineTo(1, -1.1); s.lineTo(0.5, -1.1);
    s.lineTo(0.33, -0.6); s.lineTo(-0.33, -0.6); s.lineTo(-0.5, -1.1); s.closePath();
    const hole = new THREE.Path();
    hole.moveTo(-0.17, -0.12); hole.lineTo(0, 0.45); hole.lineTo(0.17, -0.12); hole.closePath();
    s.holes.push(hole);
    const g = new THREE.ExtrudeGeometry(s, { depth: 0.4, bevelEnabled: true, bevelSize: 0.05, bevelThickness: 0.05, bevelSegments: 3 });
    g.center();
    return g;
  }, []);
  useFrame(({ clock }) => {
    if (ref.current) {
      ref.current.rotation.y = clock.elapsedTime * 0.9;
      ref.current.position.y = Math.sin(clock.elapsedTime * 1.4) * 0.06;
    }
  });
  return (
    <group ref={ref}>
      <mesh geometry={geo}>
        <meshStandardMaterial color="#e5e7eb" metalness={0.9} roughness={0.22} emissive="#1d4ed8" emissiveIntensity={0.18} />
      </mesh>
    </group>
  );
}

export default function LogoScene({ tier, active }: SceneProps) {
  return (
    <Stage tier={tier} active={active} camera={[0, 0, 5.2]} fov={36}>
      <A />
    </Stage>
  );
}
