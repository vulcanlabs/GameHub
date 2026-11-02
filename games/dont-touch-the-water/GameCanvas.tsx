"use client";

import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { ACTION_LABELS, DEFAULT_KEYS, SPEED } from "./constants";
import type { ActionId, Bird, GameSettings, Monster } from "./types";
import { buildMap, type MapState } from "./map";
import {
  alertMonsters,
  makeMonster,
  placeFar,
  stepMonsters,
} from "./monsters";
import { makeBird, stepBirds } from "./birds";
import {
  makeCausticTexture,
  makeCeilTexture,
} from "./textures";
import { PauseMenu } from "./PauseMenu";

type Props = {
  slug: string;
  initialSettings: GameSettings;
};

type Player = {
  yaw: number;
  pitch: number;
  pos: THREE.Vector3;
  vel: THREE.Vector3;
  kb: THREE.Vector3;
  ground: boolean;
  water: boolean;
  plat: MapState["plats"][number] | null;
  cp: number;
  dead: number;
};

export function GameCanvas({ slug, initialSettings }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  const [paused, setPaused] = useState(true);
  const [hud, setHud] = useState({
    cp: "Checkpoint 0",
    st: "Click to play",
    mon: "",
  });
  const [feed, setFeed] = useState<string[]>([]);
  const [scare, setScare] = useState(false);
  const [settings, setSettings] = useState<GameSettings>(initialSettings);
  const settingsRef = useRef(settings);
  settingsRef.current = settings;

  const log = (msg: string) => {
    setFeed((f) => [msg, ...f].slice(0, 6));
  };

  useEffect(() => {
    const root = wrapRef.current;
    if (!root) return;

    let disposed = false;
    const keys: Record<string, boolean> = {};
    const actionByCode: Record<string, ActionId> = {};
    for (const [a, code] of Object.entries(DEFAULT_KEYS)) {
      actionByCode[code] = a as ActionId;
    }

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    root.insertBefore(renderer.domElement, root.firstChild);

    const FOGA = 0x6a5a30;
    const FOGW = 0x1a4a55;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(FOGA);
    scene.fog = new THREE.FogExp2(FOGA, 0.022);

    const cam = new THREE.PerspectiveCamera(
      settingsRef.current.fov,
      1,
      0.1,
      300,
    );
    cam.rotation.order = "YXZ";

    const amb = new THREE.AmbientLight(0xfff0b0, 1.05);
    scene.add(amb);
    const dl = new THREE.DirectionalLight(0xffffff, 0.55);
    dl.position.set(0.3, 1, 0.2);
    scene.add(dl);
    const torch = new THREE.PointLight(0xfff2b0, 1.35, 50);
    scene.add(torch);

    const cTex = makeCausticTexture();
    const caust = new THREE.Mesh(
      new THREE.PlaneGeometry(700, 700),
      new THREE.MeshBasicMaterial({
        map: cTex,
        transparent: true,
        opacity: 0.45,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      }),
    );
    caust.rotation.x = -Math.PI / 2;
    caust.position.y = 0.03;
    scene.add(caust);

    const water = new THREE.Mesh(
      new THREE.PlaneGeometry(700, 700),
      new THREE.MeshLambertMaterial({
        color: 0x2a7a88,
        emissive: 0x0a3038,
        transparent: true,
        opacity: 0.88,
      }),
    );
    water.rotation.x = -Math.PI / 2;
    scene.add(water);

    const bed = new THREE.Mesh(
      new THREE.PlaneGeometry(700, 700),
      new THREE.MeshBasicMaterial({ color: 0x0a2024 }),
    );
    bed.rotation.x = -Math.PI / 2;
    bed.position.y = -4;
    scene.add(bed);

    const ceilT = makeCeilTexture();
    const ceil = new THREE.Mesh(
      new THREE.PlaneGeometry(700, 700),
      new THREE.MeshBasicMaterial({
        map: ceilT,
        color: 0xc8c8b8,
        side: THREE.DoubleSide,
      }),
    );
    ceil.rotation.x = Math.PI / 2;
    ceil.position.y = 15;
    scene.add(ceil);

    const P: Player = {
      yaw: 0,
      pitch: 0,
      pos: new THREE.Vector3(),
      vel: new THREE.Vector3(),
      kb: new THREE.Vector3(),
      ground: false,
      water: false,
      plat: null,
      cp: 0,
      dead: 0,
    };

    let map: MapState = buildMap(scene, null, settingsRef.current.diff);
    const monsters: Monster[] = [];
    const birds: Bird[] = [];
    const fx: { r: THREE.Mesh; t: number }[] = [];

    for (let i = 0; i < 5; i++) birds.push(makeBird(scene, false));
    for (let i = 0; i < 9; i++) birds.push(makeBird(scene, true));

    function resize() {
      const w = root!.clientWidth;
      const h = root!.clientHeight;
      renderer.setSize(w, h);
      cam.aspect = w / h;
      cam.updateProjectionMatrix();
    }
    const ro = new ResizeObserver(resize);
    ro.observe(root);
    resize();

    function respawn(c: number) {
      P.cp = Math.max(0, Math.min(map.cps.length - 1, c));
      const p = map.plats[map.cps[P.cp]];
      P.pos.set(p.x, p.top + 0.01, p.z);
      P.vel.set(0, 0, 0);
      P.kb.set(0, 0, 0);
      P.yaw = 0;
      P.water = false;
      monsters.forEach((m) => {
        m.state = "roam";
        m.tgt = null;
        placeFar(m, P.pos);
      });
    }

    function collide(prevY: number) {
      P.ground = false;
      P.plat = null;
      for (const p of map.plats) {
        if (Math.abs(p.z - P.pos.z) > p.h + 2) continue;
        const dx = P.pos.x - p.x;
        const dz = P.pos.z - p.z;
        const lim = p.h + 0.35;
        if (Math.abs(dx) < lim && Math.abs(dz) < lim) {
          if (prevY >= p.top - 0.15 && P.pos.y <= p.top && P.vel.y <= 0) {
            P.pos.y = p.top;
            P.vel.y = 0;
            P.ground = true;
            P.plat = p;
            if (p.cpi > P.cp) {
              P.cp = p.cpi;
              log(`Checkpoint ${P.cp} reached`);
              if (P.cp === map.cps.length - 1) log("Finish reached!");
            }
          } else if (P.pos.y < p.top - 0.05) {
            const ox = lim - Math.abs(dx);
            const oz = lim - Math.abs(dz);
            if (ox < oz) P.pos.x += (dx < 0 ? -1 : 1) * ox;
            else P.pos.z += (dz < 0 ? -1 : 1) * oz;
          }
        }
      }
    }

    function tryClimb() {
      let best: { p: MapState["plats"][number]; d: number } | null = null;
      for (const p of map.plats) {
        const d = Math.hypot(P.pos.x - p.x, P.pos.z - p.z);
        if (d < p.h + 1.4 && (!best || d < best.d)) best = { p, d };
      }
      if (!best) return false;
      P.pos.set(best.p.x, best.p.top + 0.05, best.p.z);
      P.vel.set(0, 0, 0);
      P.kb.set(0, 0, 0);
      P.water = false;
      P.ground = true;
      P.plat = best.p;
      log("Climbed back onto a platform");
      return true;
    }

    function splash() {
      const r = new THREE.Mesh(
        new THREE.RingGeometry(0.5, 0.8, 24),
        new THREE.MeshBasicMaterial({
          color: 0xccffff,
          transparent: true,
          opacity: 0.9,
          side: THREE.DoubleSide,
        }),
      );
      r.rotation.x = -Math.PI / 2;
      r.position.set(P.pos.x, 0.06, P.pos.z);
      scene.add(r);
      fx.push({ r, t: 0 });
      alertMonsters(monsters, P.pos);
      log("Splash! The monster heard you");
    }

    function fwd() {
      return { x: -Math.sin(P.yaw), z: -Math.cos(P.yaw) };
    }

    function movePlayer(dt: number) {
      const f = fwd();
      const r = { x: Math.cos(P.yaw), z: -Math.sin(P.yaw) };
      const a = (keys.KeyW ? 1 : 0) - (keys.KeyS ? 1 : 0);
      const b = (keys.KeyD ? 1 : 0) - (keys.KeyA ? 1 : 0);
      let mx = f.x * a + r.x * b;
      let mz = f.z * a + r.z * b;
      const l = Math.hypot(mx, mz) || 1;
      mx /= l;
      mz /= l;
      const sprint = !!(keys.ShiftLeft || keys.ShiftRight);
      const sp = P.water
        ? sprint
          ? SPEED.waterSprint
          : SPEED.water
        : sprint
          ? SPEED.landSprint
          : SPEED.land;
      P.vel.x = mx * sp + P.kb.x;
      P.vel.z = mz * sp + P.kb.z;
      P.kb.multiplyScalar(Math.exp(-3.5 * dt));
      const prevY = P.pos.y;
      const was = P.water;

      if (P.water) {
        // Surface swim — stay at y=0, no sinking.
        P.pos.y = 0;
        P.vel.y = 0;
        P.pos.x += P.vel.x * dt;
        P.pos.z += P.vel.z * dt;
        if (keys.Space) tryClimb();
        else if (a || b) {
          for (const p of map.plats) {
            const d = Math.hypot(P.pos.x - p.x, P.pos.z - p.z);
            if (d < p.h + 0.55) {
              tryClimb();
              break;
            }
          }
        }
      } else {
        P.vel.y -= 22 * dt;
        if (keys.Space && P.ground) P.vel.y = 8;
        P.pos.addScaledVector(P.vel, dt);
        collide(prevY);
      }

      P.water = !P.ground && P.pos.y < 0.05;
      if (P.water) P.pos.y = 0;
      if (P.water && !was) splash();
    }

    function scare() {
      if (P.dead > 0) return;
      P.dead = 1.4;
      setScare(true);
      log("The monster caught you");
    }

    function run(action: ActionId, amt?: number) {
      const f = fwd();
      const pushS = settingsRef.current.push;
      switch (action) {
        case "spawn_monster":
          monsters.push(
            makeMonster(scene, settingsRef.current.monster, P.pos),
          );
          break;
        case "crow_attack": {
          const b = makeBird(scene, false);
          b.mode = "attack";
          b.g.position.set(
            P.pos.x + f.x * 14,
            P.pos.y + 7,
            P.pos.z + f.z * 14,
          );
          birds.push(b);
          break;
        }
        case "up_1":
          respawn(P.cp + 1);
          log(`Moved to checkpoint ${P.cp}`);
          break;
        case "down_1":
          respawn(P.cp - 1);
          log(`Moved to checkpoint ${P.cp}`);
          break;
        case "up_5":
          respawn(P.cp + 5);
          log(`Moved to checkpoint ${P.cp}`);
          break;
        case "down_5":
          respawn(P.cp - 5);
          log(`Moved to checkpoint ${P.cp}`);
          break;
        case "custom":
          respawn(P.cp + (amt ?? settingsRef.current.custom));
          log(`Moved to checkpoint ${P.cp}`);
          break;
        case "reset":
          respawn(0);
          log(`Moved to checkpoint ${P.cp}`);
          break;
        case "push_forward":
          P.kb.x += f.x * pushS * 1.2;
          P.kb.z += f.z * pushS * 1.2;
          break;
        case "push_back":
          P.kb.x += -f.x * pushS * 1.2;
          P.kb.z += -f.z * pushS * 1.2;
          break;
        case "push_water": {
          if (!P.plat) {
            log("Already in the water");
            break;
          }
          const p = P.plat;
          const dx = P.pos.x - p.x;
          const dz = P.pos.z - p.z;
          const d =
            Math.abs(dx) > Math.abs(dz)
              ? { x: Math.sign(dx) || 1, z: 0 }
              : { x: 0, z: Math.sign(dz) || 1 };
          P.kb.x += d.x * pushS * 2.4;
          P.kb.z += d.z * pushS * 2.4;
          P.vel.y = 5;
          break;
        }
      }
    }

    monsters.push(makeMonster(scene, settingsRef.current.monster, P.pos));
    respawn(0);

    function restartMap() {
      map = buildMap(scene, map, settingsRef.current.diff);
      while (monsters.length) {
        const m = monsters.pop()!;
        scene.remove(m.g);
      }
      monsters.push(makeMonster(scene, settingsRef.current.monster, P.pos));
      respawn(0);
    }

    const api = {
      run,
      restartMap,
      applySettings(s: GameSettings) {
        const diffChanged = s.diff !== settingsRef.current.diff;
        const monChanged = s.monster !== settingsRef.current.monster;
        settingsRef.current = s;
        cam.fov = s.fov;
        cam.updateProjectionMatrix();
        if (diffChanged) restartMap();
        else if (monChanged) {
          while (monsters.length) {
            const m = monsters.pop()!;
            scene.remove(m.g);
          }
          monsters.push(makeMonster(scene, s.monster, P.pos));
        }
      },
    };
    (root as HTMLElement & { __game?: typeof api }).__game = api;

    function onKeyDown(e: KeyboardEvent) {
      if (e.code === "Escape") {
        if (document.pointerLockElement) {
          document.exitPointerLock();
        }
        setPaused(true);
        return;
      }
      const action = actionByCode[e.code];
      if (action && !e.repeat) {
        e.preventDefault();
        run(action);
        log(`${e.code} → ${ACTION_LABELS[action]}`);
        return;
      }
      keys[e.code] = true;
      if (e.code === "Space") e.preventDefault();
    }
    function onKeyUp(e: KeyboardEvent) {
      keys[e.code] = false;
    }
    function onMouseMove(e: MouseEvent) {
      if (document.pointerLockElement !== renderer.domElement) return;
      P.yaw -= e.movementX * 0.0022;
      P.pitch = Math.max(
        -1.45,
        Math.min(1.45, P.pitch - e.movementY * 0.0022),
      );
    }
    function onPointerLockChange() {
      const locked = document.pointerLockElement === renderer.domElement;
      setPaused(!locked);
      setReady(true);
    }

    addEventListener("keydown", onKeyDown);
    addEventListener("keyup", onKeyUp);
    addEventListener("mousemove", onMouseMove);
    document.addEventListener("pointerlockchange", onPointerLockChange);

    renderer.domElement.addEventListener("click", () => {
      renderer.domElement.requestPointerLock();
    });

    // SSE live gifts
    const es = new EventSource(`/api/v1/games/${slug}/live`);
    es.onmessage = (ev) => {
      try {
        const data = JSON.parse(ev.data);
        if (data.type === "action") {
          const count = Math.min(10, data.repeatCount || 1);
          for (let i = 0; i < count; i++) run(data.action as ActionId);
          log(
            `${data.giftName} → ${data.label || ACTION_LABELS[data.action as ActionId] || data.action}`,
          );
        }
      } catch {
        /* ignore */
      }
    };

    let last = performance.now();
    let T = 0;
    function frame(now: number) {
      if (disposed) return;
      requestAnimationFrame(frame);
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      T += dt;
      let sh = 0;
      if (P.dead > 0) {
        P.dead -= dt;
        sh = 0.12;
        if (P.dead <= 0) {
          setScare(false);
          respawn(P.cp);
        }
      } else if (document.pointerLockElement === renderer.domElement) {
        movePlayer(dt);
      }
      stepMonsters(monsters, P.pos, P.water, dt, T, scare);
      stepBirds(
        birds,
        scene,
        P.pos,
        P.kb,
        settingsRef.current.push,
        dt,
        T,
        () => log("Crow hit you!"),
      );
      for (let i = fx.length - 1; i >= 0; i--) {
        const f = fx[i];
        f.t += dt;
        f.r.scale.setScalar(1 + f.t * 9);
        (f.r.material as THREE.MeshBasicMaterial).opacity = Math.max(
          0,
          0.9 - f.t * 1.2,
        );
        if (f.t > 0.8) {
          scene.remove(f.r);
          fx.splice(i, 1);
        }
      }
      const ey = P.pos.y + 1.6;
      const uw = ey < 0.2 && P.water;
      cam.position.set(
        P.pos.x + (Math.random() - 0.5) * sh,
        ey,
        P.pos.z + (Math.random() - 0.5) * sh,
      );
      cam.rotation.set(P.pitch, P.yaw, 0);
      torch.position.copy(cam.position);
      water.position.set(P.pos.x, 0, P.pos.z);
      caust.position.set(P.pos.x, 0.03, P.pos.z);
      bed.position.set(P.pos.x, -4, P.pos.z);
      ceil.position.set(P.pos.x, 15, P.pos.z);
      cTex.offset.set(P.pos.x / 6 + T * 0.02, -P.pos.z / 6 + T * 0.015);
      ceilT.offset.set(P.pos.x / 8, P.pos.z / 8);
      const fog = scene.fog as THREE.FogExp2;
      fog.color.setHex(uw ? FOGW : FOGA);
      fog.density = uw ? 0.06 : 0.022;
      (scene.background as THREE.Color).setHex(uw ? FOGW : FOGA);
      if (Math.floor(now / 250) !== Math.floor((now - dt * 1000) / 250)) {
        setHud({
          cp: `Checkpoint ${P.cp} / ${map.cps.length - 1}`,
          st: P.water
            ? "In the water — Space or walk to climb"
            : "Safe on platform",
          mon: `${monsters.length} monster${monsters.length === 1 ? "" : "s"} · ${monsters.filter((m) => m.state === "charge").length} charging`,
        });
      }
      renderer.render(scene, cam);
    }
    requestAnimationFrame(frame);
    setReady(true);

    return () => {
      disposed = true;
      es.close();
      ro.disconnect();
      removeEventListener("keydown", onKeyDown);
      removeEventListener("keyup", onKeyUp);
      removeEventListener("mousemove", onMouseMove);
      document.removeEventListener("pointerlockchange", onPointerLockChange);
      renderer.dispose();
      if (renderer.domElement.parentElement) {
        renderer.domElement.parentElement.removeChild(renderer.domElement);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slug]);

  async function saveSettings(next: GameSettings) {
    setSettings(next);
    const wrap = wrapRef.current as
      | (HTMLElement & {
          __game?: { applySettings: (s: GameSettings) => void };
        })
      | null;
    wrap?.__game?.applySettings(next);
    await fetch(`/api/v1/games/${slug}/settings`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(next),
    });
  }

  function resume() {
    const canvas = wrapRef.current?.querySelector("canvas");
    canvas?.requestPointerLock();
  }

  return (
    <div className="relative flex h-full w-full bg-black">
      <div ref={wrapRef} className="relative min-w-0 flex-1 overflow-hidden">
        <div className="pointer-events-none absolute left-3 top-3 z-10 font-semibold text-white drop-shadow">
          <div>{hud.cp}</div>
          <div className="text-sm font-normal opacity-85">{hud.st}</div>
          <div className="text-sm font-normal opacity-85">{hud.mon}</div>
        </div>
        <div className="pointer-events-none absolute bottom-3 left-3 z-10 max-w-[70%] text-sm text-white drop-shadow">
          {feed.map((f, i) => (
            <div key={`${f}-${i}`}>{f}</div>
          ))}
        </div>
        {scare && (
          <div className="absolute inset-0 z-20 flex items-center justify-center bg-red-900/80 text-4xl font-extrabold tracking-wide text-white">
            IT GOT YOU
          </div>
        )}
        {paused && (
          <div
            className="absolute inset-0 z-30 flex flex-col items-center justify-center bg-black/70 text-center text-white"
            onClick={resume}
          >
            <b className="mb-2 text-2xl">Don’t Touch the Water</b>
            <div className="opacity-90">
              Click to play · WASD move · Shift sprint · Space jump / climb · Esc
              pause
            </div>
            <div className="mt-2 text-sm opacity-75">
              Stay on the platforms. Splash = the monster charges.
            </div>
            {!ready && (
              <div className="mt-4 text-sm text-amber-200">Loading scene…</div>
            )}
          </div>
        )}
      </div>
      {paused && (
        <PauseMenu
          settings={settings}
          onChange={saveSettings}
          onResume={resume}
        />
      )}
    </div>
  );
}
