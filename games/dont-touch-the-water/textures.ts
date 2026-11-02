import * as THREE from "three";

function noise(
  g: CanvasRenderingContext2D,
  w: number,
  h: number,
  n: number,
) {
  for (let i = 0; i < n; i++) {
    g.fillStyle = `rgba(${Math.random() < 0.5 ? "0,0,0" : "255,255,255"},${Math.random() * 0.07})`;
    g.fillRect(
      Math.random() * w,
      Math.random() * h,
      2 + Math.random() * 3,
      2 + Math.random() * 3,
    );
  }
}

export function canvasTex(
  w: number,
  h: number,
  fn: (g: CanvasRenderingContext2D, w: number, h: number) => void,
  rx = 1,
  ry = 1,
) {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  fn(c.getContext("2d")!, w, h);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(rx, ry);
  t.anisotropy = 4;
  return t;
}

export function makeTileTexture() {
  return canvasTex(128, 128, (g, w, h) => {
    g.fillStyle = "#d6ddd8";
    g.fillRect(0, 0, w, h);
    noise(g, w, h, 1200);
    g.strokeStyle = "#6c7a75";
    g.lineWidth = 4;
    [0, 64].forEach((x) =>
      [0, 64].forEach((y) => g.strokeRect(x, y, 64, 64)),
    );
  });
}

export function makeWallTexture() {
  return canvasTex(128, 128, (g, w, h) => {
    g.fillStyle = "#c4b360";
    g.fillRect(0, 0, w, h);
    for (let x = 0; x < w; x += 16) {
      g.fillStyle = "#a89843";
      g.fillRect(x, 0, 5, h);
    }
    for (let i = 0; i < 14; i++) {
      g.fillStyle = `rgba(90,60,20,${Math.random() * 0.12})`;
      g.beginPath();
      g.arc(
        Math.random() * w,
        Math.random() * h,
        8 + Math.random() * 18,
        0,
        7,
      );
      g.fill();
    }
    noise(g, w, h, 900);
  });
}

export function makeCeilTexture() {
  return canvasTex(
    256,
    256,
    (g, w, h) => {
      g.fillStyle = "#c2b982";
      g.fillRect(0, 0, w, h);
      noise(g, w, h, 1500);
      g.strokeStyle = "#8c8458";
      g.lineWidth = 4;
      [0, 128].forEach((x) =>
        [0, 128].forEach((y) => {
          g.strokeRect(x, y, 128, 128);
          g.fillStyle = "#fffbe2";
          g.fillRect(x + 30, y + 44, 68, 40);
        }),
      );
    },
    700 / 8,
    700 / 8,
  );
}

export function makeCausticTexture() {
  return canvasTex(
    128,
    128,
    (g, w, h) => {
      const d = g.createImageData(w, h);
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const u = (x / w) * 6.283;
          const v = (y / h) * 6.283;
          const q = Math.abs(
            Math.sin(2 * u + Math.sin(2 * v) * 1.2) +
              Math.sin(2 * v + Math.sin(3 * u) * 1.2),
          );
          const I = Math.pow(Math.max(0, 1 - q / 1.1), 3);
          const i = (y * w + x) * 4;
          d.data[i] = 170;
          d.data[i + 1] = 255;
          d.data[i + 2] = 255;
          d.data[i + 3] = I * 255;
        }
      }
      g.putImageData(d, 0, 0);
    },
    700 / 6,
    700 / 6,
  );
}

export function uvScale(g: THREE.BufferGeometry, k: number) {
  const u = g.attributes.uv;
  for (let i = 0; i < u.count; i++) u.setXY(i, u.getX(i) * k, u.getY(i) * k);
  return g;
}
