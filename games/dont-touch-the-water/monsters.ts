import * as THREE from "three";
import { MONSTER_TYPES } from "./constants";
import type { Monster, MonsterType } from "./types";

export function makeMonster(
  scene: THREE.Scene,
  type: MonsterType,
  near: THREE.Vector3,
): Monster {
  const T = MONSTER_TYPES[type];
  const g = new THREE.Group();
  const mat = new THREE.MeshLambertMaterial({ color: T.c });

  const body = new THREE.Mesh(new THREE.SphereGeometry(1, 14, 10), mat);
  body.scale.set(1.35, 0.75, 2.4);
  body.position.y = -0.15;
  g.add(body);

  const jaw = new THREE.Mesh(
    new THREE.ConeGeometry(0.9, 1.6, 8),
    mat,
  );
  jaw.rotation.x = Math.PI / 2;
  jaw.position.set(0, -0.35, -1.7);
  g.add(jaw);

  const fin = new THREE.Mesh(new THREE.ConeGeometry(0.45, 1.6, 6), mat);
  fin.position.set(0, 0.85, 0.2);
  g.add(fin);

  [-0.55, 0.55].forEach((x) => {
    const e = new THREE.Mesh(
      new THREE.SphereGeometry(0.28, 10, 8),
      new THREE.MeshBasicMaterial({ color: 0xff1a0a }),
    );
    e.position.set(x, 0.25, -1.85);
    g.add(e);
    const glow = new THREE.PointLight(0xff2010, 1.1, 14);
    glow.position.copy(e.position);
    g.add(glow);
  });

  const tm = new THREE.MeshBasicMaterial({ color: 0xe8e2cf });
  for (let i = 0; i < 14; i++) {
    const a = (i / 14) * Math.PI * 2;
    const t = new THREE.Mesh(new THREE.ConeGeometry(0.09, 0.42, 5), tm);
    t.position.set(Math.cos(a) * 0.55, Math.sin(a) * 0.28 - 0.2, -2.35);
    t.rotation.x = -Math.PI / 2;
    g.add(t);
  }

  for (let i = 0; i < 6; i++) {
    const sp = new THREE.Mesh(
      new THREE.ConeGeometry(0.18, 0.85 - i * 0.08, 5),
      mat,
    );
    sp.position.set(0, 0.9, 0.9 - i * 0.45);
    sp.rotation.x = 0.35;
    g.add(sp);
  }

  const aura = new THREE.PointLight(0xff3020, 0.55, 16);
  aura.position.set(0, 0.2, -1.2);
  g.add(aura);

  g.scale.setScalar(T.s);
  scene.add(g);

  const m: Monster = { g, T, state: "roam", tgt: null, calm: 0 };
  placeFar(m, near);
  return m;
}

export function placeFar(m: Monster, near: THREE.Vector3) {
  const a = Math.random() * Math.PI * 2;
  const d = 16 + Math.random() * 10;
  m.g.position.set(near.x + Math.cos(a) * d, -1.1, near.z + Math.sin(a) * d);
}

export function stepMonsters(
  monsters: Monster[],
  playerPos: THREE.Vector3,
  playerWater: boolean,
  dt: number,
  t: number,
  onCatch: () => void,
) {
  for (const m of monsters) {
    const p = m.g.position;
    let tx: number;
    let tz: number;
    let sp: number;

    if (m.state === "roam") {
      if (
        !m.tgt ||
        Math.hypot(m.tgt.x - p.x, m.tgt.z - p.z) < 2
      ) {
        const a = Math.random() * Math.PI * 2;
        const d = 12 + Math.random() * 16;
        m.tgt = {
          x: playerPos.x + Math.cos(a) * d,
          z: playerPos.z + Math.sin(a) * d,
        };
      }
      tx = m.tgt.x;
      tz = m.tgt.z;
      sp = m.T.roam;
      p.y = -1.1 + Math.sin(t * 2) * 0.08;
    } else {
      tx = playerPos.x;
      tz = playerPos.z;
      sp = m.T.charge;
      p.y = -0.85;
      const d = Math.hypot(tx - p.x, tz - p.z);
      if (d < 2.6) {
        sp = 0;
        if (playerWater) onCatch();
        else {
          m.calm += dt;
          if (m.calm > 1.6) {
            m.state = "roam";
            m.tgt = null;
          }
        }
      }
    }

    const dx = tx - p.x;
    const dz = tz - p.z;
    const d = Math.hypot(dx, dz) || 1;
    if (sp) {
      p.x += (dx / d) * sp * dt;
      p.z += (dz / d) * sp * dt;
      m.g.rotation.y = Math.atan2(-dx, -dz);
    }
  }
}

export function alertMonsters(
  monsters: Monster[],
  playerPos: THREE.Vector3,
) {
  for (const m of monsters) {
    if (m.T.tele) {
      const a = Math.random() * Math.PI * 2;
      m.g.position.set(
        playerPos.x + Math.cos(a) * 10,
        -1.1,
        playerPos.z + Math.sin(a) * 10,
      );
    }
    m.state = "charge";
    m.calm = 0;
  }
}
