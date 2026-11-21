import * as THREE from "three";
import {
  START_GRASS,
  grassFullness,
  tuftHeightScale,
} from "./counter";

export type LawnView = {
  apply: (grass: number) => void;
  dispose: () => void;
};

type Tuft = {
  x: number;
  z: number;
  depth: number;
  phase: number;
  height: number;
  width: number;
  rot: number;
  flower: boolean;
};

function hash01(n: number): number {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
}

function track<T extends { dispose: () => void }>(
  bag: { dispose: () => void }[],
  value: T,
): T {
  bag.push(value);
  return value;
}

function canvasTexture(
  bag: { dispose: () => void }[],
  draw: (ctx: CanvasRenderingContext2D, size: number) => void,
  size = 128,
): THREE.CanvasTexture {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("canvas 2d unavailable");
  draw(ctx, size);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return track(bag, tex);
}

function mowedTexture(bag: { dispose: () => void }[], light: boolean) {
  const tex = canvasTexture(bag, (ctx) => {
    const stripes = light
      ? ["#b6e07a", "#a8d46e"]
      : ["#7fbe45", "#6aa83a"];
    for (let y = 0; y < 128; y++) {
      ctx.fillStyle = stripes[Math.floor(y / 6) % 2]!;
      ctx.fillRect(0, y, 128, 1);
    }
    for (let i = 0; i < 280; i++) {
      ctx.fillStyle = i % 2 === 0 ? "rgba(255,255,255,0.14)" : "rgba(30,80,20,0.18)";
      ctx.fillRect(hash01(i) * 128, hash01(i + 40) * 128, 2, 2);
    }
  });
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.anisotropy = 4;
  return tex;
}

function flowerTexture(bag: { dispose: () => void }[]) {
  return canvasTexture(bag, (ctx, size) => {
    ctx.clearRect(0, 0, size, size);
    ctx.save();
    ctx.translate(size / 2, size / 2);
    for (let i = 0; i < 6; i++) {
      ctx.rotate(Math.PI / 3);
      ctx.fillStyle = "#fff7df";
      ctx.beginPath();
      ctx.ellipse(0, size * 0.22, size * 0.08, size * 0.16, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = "#f2c014";
    ctx.beginPath();
    ctx.arc(0, 0, size * 0.09, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  });
}

function grassClump(bag: { dispose: () => void }[]) {
  const main = new THREE.ConeGeometry(0.28, 1, 5);
  main.translate(0, 0.5, 0);
  const side = new THREE.ConeGeometry(0.16, 0.72, 4);
  side.translate(0.12, 0.36, 0.06);
  const geo = mergeNonIndexed([main.toNonIndexed(), side.toNonIndexed()]);
  main.dispose();
  side.dispose();
  return track(bag, geo);
}

function mergeNonIndexed(parts: THREE.BufferGeometry[]): THREE.BufferGeometry {
  let count = 0;
  for (const part of parts) count += part.getAttribute("position").count;
  const position = new Float32Array(count * 3);
  const normal = new Float32Array(count * 3);
  const uv = new Float32Array(count * 2);
  let offset = 0;
  for (const part of parts) {
    const pos = part.getAttribute("position");
    const nrm = part.getAttribute("normal");
    const uvs = part.getAttribute("uv");
    for (let i = 0; i < pos.count; i++) {
      position.set([pos.getX(i), pos.getY(i), pos.getZ(i)], (offset + i) * 3);
      normal.set([nrm.getX(i), nrm.getY(i), nrm.getZ(i)], (offset + i) * 3);
      uv.set([uvs.getX(i), uvs.getY(i)], (offset + i) * 2);
    }
    offset += pos.count;
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(position, 3));
  geo.setAttribute("normal", new THREE.BufferAttribute(normal, 3));
  geo.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  return geo;
}

function addSway(material: THREE.Material, time: { value: number }) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uTime = time;
    shader.vertexShader = shader.vertexShader
      .replace(
        "#include <common>",
        "#include <common>\nuniform float uTime;\n",
      )
      .replace(
        "#include <begin_vertex>",
        `#include <begin_vertex>
         #ifdef USE_INSTANCING
           float tip = clamp(position.y, 0.0, 1.0);
           float wave = sin(uTime * 1.7 + instanceMatrix[3].x * 0.55 + instanceMatrix[3].z * 0.37);
           transformed.x += wave * tip * 0.12;
           transformed.z += cos(uTime * 1.2 + instanceMatrix[3].z * 0.42) * tip * 0.06;
         #endif`,
      );
  };
}

function buildTufts(): Tuft[] {
  const tufts: Tuft[] = [];
  const rows = 32;
  const cols = 11;
  let n = 0;
  for (let row = 0; row < rows; row++) {
    const z = 3.15 - row * 1.26;
    const pathHalf = THREE.MathUtils.lerp(1.6, 0.2, Math.min(1, row / 16));
    const depth = row / (rows - 1);
    for (const side of [-1, 1]) {
      for (let col = 0; col < cols; col++) {
        n += 1;
        const phase = hash01(n * 1.7);
        let x = side * (pathHalf + 0.22 + col * 0.56);
        x += (hash01(n * 2.3) - 0.5) * 0.22;
        if (Math.abs(x) < pathHalf * 0.8) x = side * pathHalf;
        tufts.push({
          x,
          z: z + (hash01(n * 4.1) - 0.5) * 0.36,
          depth,
          phase,
          height: 0.45 + hash01(n * 8.2) * 0.55,
          width: 0.82 + hash01(n * 6.4) * 0.55,
          rot: hash01(n * 9.9) * Math.PI,
          flower: hash01(n * 3.3) > 0.9,
        });
      }
    }
  }
  return tufts;
}

function makeMower(
  bag: { dispose: () => void }[],
  scene: THREE.Scene,
): THREE.Group {
  const yellow = track(
    bag,
    new THREE.MeshStandardMaterial({
      color: 0xf0c014,
      roughness: 0.42,
      metalness: 0.08,
    }),
  );
  const yellowDeep = track(
    bag,
    new THREE.MeshStandardMaterial({
      color: 0xd7a40a,
      roughness: 0.5,
      metalness: 0.06,
    }),
  );
  const black = track(
    bag,
    new THREE.MeshStandardMaterial({
      color: 0x1c1c1c,
      roughness: 0.6,
      metalness: 0.15,
    }),
  );
  const stringMat = track(
    bag,
    new THREE.MeshBasicMaterial({ color: 0xf7fbff }),
  );
  const ghostMat = track(
    bag,
    new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0.35,
      depthWrite: false,
    }),
  );

  const head = new THREE.Group();
  // Held in the lower middle of the view, ahead of the camera.
  head.position.set(0.08, 0.98, 3.45);
  head.rotation.set(0.35, 0.25, -0.12);

  const guard = new THREE.Mesh(
    track(bag, new THREE.CylinderGeometry(0.34, 0.38, 0.07, 32)),
    yellow,
  );
  head.add(guard);

  const rim = new THREE.Mesh(
    track(bag, new THREE.TorusGeometry(0.36, 0.022, 8, 28)),
    yellowDeep,
  );
  rim.rotation.x = Math.PI / 2;
  rim.position.y = 0.01;
  head.add(rim);

  const housing = new THREE.Mesh(
    track(bag, new THREE.BoxGeometry(0.16, 0.1, 0.22)),
    yellowDeep,
  );
  housing.position.set(-0.02, 0.08, -0.02);
  head.add(housing);

  const spinner = new THREE.Group();
  spinner.position.y = 0.055;
  spinner.name = "spinner";
  const stringGeo = track(bag, new THREE.BoxGeometry(1.15, 0.028, 0.05));
  for (const angle of [0.2, Math.PI / 2 + 0.2]) {
    const strand = new THREE.Mesh(stringGeo, stringMat);
    strand.rotation.y = angle;
    spinner.add(strand);
    const ghost = new THREE.Mesh(stringGeo, ghostMat);
    ghost.rotation.y = angle + 0.35;
    spinner.add(ghost);
  }
  head.add(spinner);
  scene.add(head);

  const from = new THREE.Vector3(0.22, 1.05, 3.55);
  const to = new THREE.Vector3(0.95, 0.42, 4.72);
  const direction = to.clone().sub(from);
  const length = direction.length();
  const shaft = new THREE.Mesh(
    track(bag, new THREE.CylinderGeometry(0.032, 0.04, length, 10)),
    yellow,
  );
  shaft.position.copy(from).add(to).multiplyScalar(0.5);
  shaft.quaternion.setFromUnitVectors(
    new THREE.Vector3(0, 1, 0),
    direction.normalize(),
  );
  scene.add(shaft);

  const grip = new THREE.Mesh(
    track(bag, new THREE.CylinderGeometry(0.055, 0.055, 0.34, 12)),
    black,
  );
  grip.position.copy(to);
  grip.quaternion.copy(shaft.quaternion);
  scene.add(grip);

  const loop = new THREE.Mesh(
    track(bag, new THREE.TorusGeometry(0.11, 0.02, 8, 18)),
    black,
  );
  loop.position.set(0.58, 0.78, 4.15);
  loop.rotation.set(1.1, 0.4, 0.6);
  scene.add(loop);

  const shade = new THREE.Mesh(
    track(bag, new THREE.CircleGeometry(0.55, 20)),
    track(
      bag,
      new THREE.MeshBasicMaterial({
        color: 0x214018,
        transparent: true,
        opacity: 0.28,
        depthWrite: false,
      }),
    ),
  );
  shade.rotation.x = -Math.PI / 2;
  shade.position.set(0.12, 0.025, 3.2);
  scene.add(shade);

  return spinner;
}

export function mountLawn(root: HTMLElement): LawnView {
  const bag: { dispose: () => void }[] = [];
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.domElement.style.display = "block";
  renderer.domElement.style.width = "100%";
  renderer.domElement.style.height = "100%";
  root.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const sky = new THREE.Color(0x8ec6ef);
  scene.background = sky;
  scene.fog = new THREE.Fog(0x9ed0ee, 22, 70);

  const camera = new THREE.PerspectiveCamera(68, 1, 0.08, 120);
  camera.position.set(0, 1.55, 4.85);
  camera.lookAt(0, 0.95, -8);

  scene.add(new THREE.HemisphereLight(0xd7f0ff, 0x3e6b28, 1.25));
  const sun = new THREE.DirectionalLight(0xfff4d2, 1.35);
  sun.position.set(-8, 14, 6);
  scene.add(sun);

  const yardTex = mowedTexture(bag, false);
  yardTex.repeat.set(14, 22);
  const yard = new THREE.Mesh(
    track(bag, new THREE.PlaneGeometry(90, 90)),
    track(bag, new THREE.MeshLambertMaterial({ map: yardTex })),
  );
  yard.rotation.x = -Math.PI / 2;
  yard.position.set(0, 0, -12);
  scene.add(yard);

  const pathTex = mowedTexture(bag, true);
  pathTex.repeat.set(2, 18);
  const path = new THREE.Mesh(
    track(bag, new THREE.PlaneGeometry(3.15, 46)),
    track(bag, new THREE.MeshLambertMaterial({ map: pathTex })),
  );
  path.rotation.x = -Math.PI / 2;
  path.position.set(0, 0.015, -8);
  scene.add(path);

  const tufts = buildTufts();
  const bladeGeo = grassClump(bag);
  const bladeMat = track(
    bag,
    new THREE.MeshLambertMaterial({ color: 0x3c9a34 }),
  );
  const time = { value: 0 };
  addSway(bladeMat, time);
  const grass = new THREE.InstancedMesh(bladeGeo, bladeMat, tufts.length);
  grass.frustumCulled = false;
  const color = new THREE.Color();
  tufts.forEach((tuft, i) => {
    color.setRGB(
      0.72 + tuft.phase * 0.35,
      0.85 + (1 - tuft.phase) * 0.2,
      0.45,
    );
    grass.setColorAt(i, color);
  });
  scene.add(grass);

  const flowers = tufts.filter((tuft) => tuft.flower);
  const flowerGeo = track(bag, new THREE.PlaneGeometry(0.42, 0.42));
  const flowerMat = track(
    bag,
    new THREE.MeshLambertMaterial({
      map: flowerTexture(bag),
      alphaTest: 0.4,
      side: THREE.DoubleSide,
    }),
  );
  addSway(flowerMat, time);
  const flowerMesh = new THREE.InstancedMesh(flowerGeo, flowerMat, flowers.length);
  flowerMesh.frustumCulled = false;
  flowers.forEach((tuft, i) => {
    const hue = tuft.phase > 0.55 ? 0.12 : 0.08;
    color.setHSL(hue, 0.35, 0.95);
    flowerMesh.setColorAt(i, color);
  });
  scene.add(flowerMesh);

  const trunkGeo = track(bag, new THREE.CylinderGeometry(0.14, 0.2, 1.35, 6));
  const crownGeo = track(bag, new THREE.SphereGeometry(1.05, 10, 8));
  const crownSmall = track(bag, new THREE.SphereGeometry(0.62, 8, 6));
  const trunkMat = track(bag, new THREE.MeshLambertMaterial({ color: 0x6b4428 }));
  const leafMat = track(bag, new THREE.MeshLambertMaterial({ color: 0x2f7a32 }));
  const leafLite = track(bag, new THREE.MeshLambertMaterial({ color: 0x4e9a3d }));
  const treeCount = 18;
  const trunks = new THREE.InstancedMesh(trunkGeo, trunkMat, treeCount);
  const crowns = new THREE.InstancedMesh(crownGeo, leafMat, treeCount);
  const highlights = new THREE.InstancedMesh(crownSmall, leafLite, treeCount);
  trunks.frustumCulled = false;
  crowns.frustumCulled = false;
  highlights.frustumCulled = false;
  const dummy = new THREE.Object3D();
  for (let i = 0; i < treeCount; i++) {
    const side = i % 2 === 0 ? -1 : 1;
    const along = Math.floor(i / 2);
    const x = side * (7.6 + hash01(i + 2) * 1.4);
    const z = 2.2 - along * 4.7 - hash01(i + 5);
    dummy.position.set(x, 0.67, z);
    dummy.scale.set(1, 1, 1);
    dummy.rotation.set(0, 0, 0);
    dummy.updateMatrix();
    trunks.setMatrixAt(i, dummy.matrix);
    dummy.position.set(x, 1.85, z);
    dummy.scale.set(1, 0.82, 1);
    dummy.updateMatrix();
    crowns.setMatrixAt(i, dummy.matrix);
    dummy.position.set(x + side * 0.35, 2.15, z + 0.15);
    dummy.scale.set(1, 0.9, 1);
    dummy.updateMatrix();
    highlights.setMatrixAt(i, dummy.matrix);

    const shade = new THREE.Mesh(
      track(bag, new THREE.CircleGeometry(1.15, 12)),
      track(
        bag,
        new THREE.MeshBasicMaterial({
          color: 0x2a4a1c,
          transparent: true,
          opacity: 0.18,
          depthWrite: false,
        }),
      ),
    );
    shade.rotation.x = -Math.PI / 2;
    shade.position.set(x, 0.02, z);
    scene.add(shade);
  }
  scene.add(trunks, crowns, highlights);

  const hillGeo = track(bag, new THREE.SphereGeometry(7, 14, 10));
  const hillMat = track(bag, new THREE.MeshLambertMaterial({ color: 0x69a84a }));
  for (const [x, z] of [
    [-16, -42],
    [4, -48],
    [18, -40],
  ] as const) {
    const hill = new THREE.Mesh(hillGeo, hillMat);
    hill.scale.y = 0.32;
    hill.position.set(x, -1.4, z);
    scene.add(hill);
  }

  const cloudMat = track(
    bag,
    new THREE.MeshLambertMaterial({ color: 0xffffff, emissive: 0xd7e8f6 }),
  );
  const puff = track(bag, new THREE.SphereGeometry(1, 8, 6));
  for (let c = 0; c < 5; c++) {
    const group = new THREE.Group();
    group.position.set(-14 + c * 8 + hash01(c) * 2, 9 + hash01(c + 3) * 2, -6 - c * 4);
    for (let p = 0; p < 3; p++) {
      const ball = new THREE.Mesh(puff, cloudMat);
      ball.position.set(p * 1.1, hash01(c * 4 + p) * 0.4, 0);
      ball.scale.setScalar(0.7 + hash01(c + p) * 0.5);
      group.add(ball);
    }
    scene.add(group);
  }

  const sunTex = canvasTexture(bag, (ctx, size) => {
    const glow = ctx.createRadialGradient(
      size / 2,
      size / 2,
      size * 0.08,
      size / 2,
      size / 2,
      size * 0.48,
    );
    glow.addColorStop(0, "rgba(255,250,230,1)");
    glow.addColorStop(0.35, "rgba(255,214,110,0.95)");
    glow.addColorStop(1, "rgba(255,214,110,0)");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, size, size);
  });
  const sunSprite = new THREE.Sprite(
    track(
      bag,
      new THREE.SpriteMaterial({ map: sunTex, depthWrite: false, transparent: true }),
    ),
  );
  sunSprite.position.set(-10, 11, -16);
  sunSprite.scale.set(9, 9, 1);
  scene.add(sunSprite);

  const spinner = makeMower(bag, scene);
  const dummyGrass = new THREE.Object3D();
  const dummyFlower = new THREE.Object3D();

  function apply(amount: number) {
    const full = grassFullness(amount);
    const boost =
      1 + Math.min(0.35, Math.max(0, amount - START_GRASS) / START_GRASS);
    for (let i = 0; i < tufts.length; i++) {
      const tuft = tufts[i]!;
      const y = tuftHeightScale(full, tuft.depth, tuft.phase, tuft.height) * boost;
      const standing = y > 0.05;
      dummyGrass.position.set(tuft.x, standing ? 0 : -6, tuft.z);
      dummyGrass.scale.set(
        standing ? tuft.width : 0.01,
        standing ? y : 0.01,
        standing ? tuft.width : 0.01,
      );
      dummyGrass.rotation.set(0, tuft.rot, 0);
      dummyGrass.updateMatrix();
      grass.setMatrixAt(i, dummyGrass.matrix);
    }
    grass.instanceMatrix.needsUpdate = true;

    for (let i = 0; i < flowers.length; i++) {
      const tuft = flowers[i]!;
      const grown = tuftHeightScale(full, tuft.depth, tuft.phase, tuft.height) > 0.2;
      dummyFlower.position.set(tuft.x, grown ? tuft.height * 0.72 : -6, tuft.z);
      dummyFlower.scale.setScalar(grown ? 0.55 + tuft.phase * 0.25 : 0.01);
      dummyFlower.rotation.set(0, tuft.rot, 0);
      dummyFlower.updateMatrix();
      flowerMesh.setMatrixAt(i, dummyFlower.matrix);
    }
    flowerMesh.instanceMatrix.needsUpdate = true;
  }

  apply(START_GRASS);

  let disposed = false;
  let frame = 0;
  const timer = new THREE.Timer();
  timer.connect(document);
  const loop = () => {
    if (disposed) return;
    frame = requestAnimationFrame(loop);
    timer.update();
    const t = timer.getElapsed();
    time.value = t;
    spinner.rotation.y = t * 26;
    renderer.render(scene, camera);
  };
  loop();

  const resize = () => {
    const width = root.clientWidth || 1;
    const height = root.clientHeight || 1;
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height, false);
  };
  resize();
  const observer = new ResizeObserver(resize);
  observer.observe(root);

  return {
    apply,
    dispose() {
      disposed = true;
      cancelAnimationFrame(frame);
      timer.disconnect();
      observer.disconnect();
      for (const item of bag) item.dispose();
      renderer.dispose();
      renderer.domElement.remove();
    },
  };
}
