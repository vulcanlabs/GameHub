import * as THREE from "three";
import {
  CHECKPOINT_EVERY,
  DIFF_GAPS,
  PLATFORM_COUNT,
} from "./constants";
import type { Platform } from "./types";
import { makeTileTexture, makeWallTexture, uvScale } from "./textures";

export type MapState = {
  group: THREE.Group;
  plats: Platform[];
  cps: number[];
};

export function buildMap(
  scene: THREE.Scene,
  prev: MapState | null,
  diffI: number,
): MapState {
  if (prev) scene.remove(prev.group);

  const group = new THREE.Group();
  scene.add(group);
  const plats: Platform[] = [];
  const cps: number[] = [];
  const tileT = makeTileTexture();
  const wallT = makeWallTexture();
  const gap = DIFF_GAPS[Math.min(diffI, DIFF_GAPS.length - 1)];

  let x = 0;
  let z = 0;
  let pw = 5;
  let heading = Math.PI; // face −Z initially
  const turnBudget = 0.55;

  for (let i = 0; i <= PLATFORM_COUNT; i++) {
    const w = i ? gap.wmin + Math.random() * 1.1 : 5;
    const cp = i % CHECKPOINT_EVERY === 0;

    if (i) {
      heading += (Math.random() - 0.5) * turnBudget;
      heading = Math.max(
        Math.PI - 1.1,
        Math.min(Math.PI + 1.1, heading),
      );
      const step = pw / 2 + gap.gmin + Math.random() * (gap.gmax - gap.gmin) + w / 2;
      x += Math.sin(heading) * step;
      z += Math.cos(heading) * step;
      x = Math.max(-40, Math.min(40, x));
    }

    const top = 1 + (i % 4) * 0.12;
    const mesh = new THREE.Mesh(
      uvScale(new THREE.BoxGeometry(w, 5, w), w / 3),
      new THREE.MeshLambertMaterial(
        cp
          ? { map: tileT, color: 0xffd36b, emissive: 0x4a3a00 }
          : { map: tileT, color: 0xe4ece6 },
      ),
    );
    mesh.position.set(x, top - 2.5, z);
    group.add(mesh);
    plats.push({ x, z, h: w / 2, top, cpi: cp ? cps.length : -1, mesh });
    if (cp) {
      cps.push(plats.length - 1);
      const beacon = new THREE.Mesh(
        new THREE.CylinderGeometry(0.06, 0.06, 4),
        new THREE.MeshBasicMaterial({ color: 0xffe27a }),
      );
      beacon.position.set(x, top + 2, z);
      group.add(beacon);
    }
    pw = w;
  }

  const pm = new THREE.MeshLambertMaterial({ map: wallT });
  for (let i = 0; i < 70; i++) {
    const s = 1.5 + Math.random() * 1.5;
    const p = new THREE.Mesh(
      uvScale(new THREE.BoxGeometry(s, 19, s), s / 3),
      pm,
    );
    const side = Math.random() < 0.5 ? -1 : 1;
    const along = plats[Math.floor(Math.random() * plats.length)];
    p.position.set(
      along.x + side * (10 + Math.random() * 22),
      5.5,
      along.z + (Math.random() - 0.5) * 8,
    );
    group.add(p);
  }

  return { group, plats, cps };
}
