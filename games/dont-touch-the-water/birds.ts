import * as THREE from "three";
import type { Bird } from "./types";

export function makeBird(scene: THREE.Scene, bat: boolean): Bird {
  const g = new THREE.Group();
  const mat = new THREE.MeshLambertMaterial({
    color: bat ? 0x1a1220 : 0x0a0a0a,
  });
  g.add(new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.2, 0.7), mat));

  const mk = (s: number) => {
    const p = new THREE.Group();
    const w = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.04, 0.4), mat);
    w.position.x = s * 0.45;
    p.add(w);
    p.position.x = s * 0.12;
    g.add(p);
    return p;
  };

  g.scale.setScalar(bat ? 0.8 : 1.3);
  scene.add(g);

  return {
    g,
    wl: mk(-1),
    wr: mk(1),
    bat,
    ph: Math.random() * Math.PI * 2,
    r: 10 + Math.random() * 16,
    y: bat ? 10 + Math.random() * 3 : 5 + Math.random() * 4,
    sp: (0.3 + Math.random() * 0.4) * (Math.random() < 0.5 ? -1 : 1),
    mode: "orbit",
    t: 0,
  };
}

export function stepBirds(
  birds: Bird[],
  scene: THREE.Scene,
  playerPos: THREE.Vector3,
  kb: THREE.Vector3,
  pushS: number,
  dt: number,
  t: number,
  onHit: () => void,
) {
  for (let i = birds.length - 1; i >= 0; i--) {
    const b = birds[i];
    const p = b.g.position;
    b.t += dt;
    const fl = Math.sin(t * (b.bat ? 18 : 11) + b.ph) * 0.9;
    b.wl.rotation.z = fl;
    b.wr.rotation.z = -fl;

    if (b.mode === "orbit") {
      const a = b.ph + t * b.sp;
      const nx = playerPos.x + Math.cos(a) * b.r;
      const nz = playerPos.z + Math.sin(a) * b.r;
      b.g.rotation.y = Math.atan2(-(nx - p.x), -(nz - p.z));
      p.set(nx, b.y + Math.sin(t * 2 + b.ph), nz);
    } else if (b.mode === "attack") {
      const ex = playerPos.x;
      const ey = playerPos.y + 1.4;
      const ez = playerPos.z;
      const dx = ex - p.x;
      const dy = ey - p.y;
      const dz = ez - p.z;
      const d = Math.hypot(dx, dy, dz) || 1;
      p.x += (dx / d) * 20 * dt;
      p.y += (dy / d) * 20 * dt;
      p.z += (dz / d) * 20 * dt;
      b.g.rotation.y = Math.atan2(-dx, -dz);
      if (d < 1.3 || b.t > 4) {
        const h = Math.hypot(dx, dz) || 1;
        kb.x += (dx / h) * pushS * 1.4;
        kb.z += (dz / h) * pushS * 1.4;
        b.mode = "leave";
        b.t = 0;
        onHit();
      }
    } else {
      p.y += 8 * dt;
      p.x += Math.sin(b.ph) * 6 * dt;
      p.z -= 6 * dt;
      if (b.t > 3) {
        scene.remove(b.g);
        birds.splice(i, 1);
      }
    }
  }
}
