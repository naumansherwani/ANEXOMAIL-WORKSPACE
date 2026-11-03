/**
 * Orthographic globe projection (World clock W3). Pure maths so it can be unit-tested; the canvas only draws.
 * `c` is the point at the centre of the disc. Output is in the unit disc: x right, y DOWN, radius 1.
 */
const RAD = Math.PI / 180;
const DEG = 180 / Math.PI;

export type View = { lat: number; lon: number };
export type Projected = { x: number; y: number; visible: boolean };

export function project(lat: number, lon: number, c: View): Projected {
  const phi = lat * RAD;
  const phi0 = c.lat * RAD;
  const dl = (lon - c.lon) * RAD;
  const cosc = Math.sin(phi0) * Math.sin(phi) + Math.cos(phi0) * Math.cos(phi) * Math.cos(dl);
  const x = Math.cos(phi) * Math.sin(dl);
  const y = Math.cos(phi0) * Math.sin(phi) - Math.sin(phi0) * Math.cos(phi) * Math.cos(dl);
  return { x, y: -y, visible: cosc >= 0 };
}

/** Same point, but a hidden one is slid onto the rim — keeps coastlines closed instead of leaving holes at the horizon. */
export function projectClamped(lat: number, lon: number, c: View): Projected {
  const p = project(lat, lon, c);
  if (p.visible) return p;
  const r = Math.hypot(p.x, p.y) || 1;
  return { x: p.x / r, y: p.y / r, visible: false };
}

/** Inverse: unit-disc point -> lat/lon, or null outside the disc. */
export function unproject(x: number, yDown: number, c: View): { lat: number; lon: number } | null {
  const y = -yDown;
  const rho = Math.hypot(x, y);
  if (rho > 1) return null;
  if (rho === 0) return { lat: c.lat, lon: c.lon };
  const cc = Math.asin(rho);
  const phi0 = c.lat * RAD;
  const lat = Math.asin(Math.cos(cc) * Math.sin(phi0) + (y * Math.sin(cc) * Math.cos(phi0)) / rho);
  const lon =
    c.lon * RAD +
    Math.atan2(
      x * Math.sin(cc),
      rho * Math.cos(phi0) * Math.cos(cc) - y * Math.sin(phi0) * Math.sin(cc),
    );
  return { lat: lat * DEG, lon: ((((lon * DEG + 180) % 360) + 360) % 360) - 180 };
}

/**
 * Points along the shortest path between two places (spherical interpolation), as [lat, lon] pairs, `n + 1` of them including both ends.
 * Same place twice -> just that point. Used for the dashed trip line on the globe.
 */
export function greatCircle(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number },
  n = 48,
): [number, number][] {
  const vec = (p: { lat: number; lon: number }): [number, number, number] => {
    const la = p.lat * RAD;
    const lo = p.lon * RAD;
    return [Math.cos(la) * Math.cos(lo), Math.cos(la) * Math.sin(lo), Math.sin(la)];
  };
  const va = vec(a);
  const vb = vec(b);
  const dot = Math.max(-1, Math.min(1, va[0] * vb[0] + va[1] * vb[1] + va[2] * vb[2]));
  const om = Math.acos(dot);
  if (om < 1e-9) return [[a.lat, a.lon]];
  const so = Math.sin(om);
  const out: [number, number][] = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const ka = Math.sin((1 - t) * om) / so;
    const kb = Math.sin(t * om) / so;
    const x = ka * va[0] + kb * vb[0];
    const y = ka * va[1] + kb * vb[1];
    const z = ka * va[2] + kb * vb[2];
    out.push([Math.asin(Math.max(-1, Math.min(1, z))) * DEG, Math.atan2(y, x) * DEG]);
  }
  return out;
}
