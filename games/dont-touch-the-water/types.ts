import type * as THREE from "three";

export type MonsterType = "stalker" | "crawler" | "beast" | "shadow";

export type GameSettings = {
  monster: MonsterType;
  diff: number;
  fov: number;
  push: number;
  custom: number;
};

export type Platform = {
  x: number;
  z: number;
  h: number;
  top: number;
  cpi: number;
  mesh: THREE.Mesh;
};

export type Monster = {
  g: THREE.Group;
  T: {
    c: number;
    s: number;
    roam: number;
    charge: number;
    tele?: number;
  };
  state: "roam" | "charge";
  tgt: { x: number; z: number } | null;
  calm: number;
};

export type Bird = {
  g: THREE.Group;
  wl: THREE.Group;
  wr: THREE.Group;
  bat: boolean;
  ph: number;
  r: number;
  y: number;
  sp: number;
  mode: "orbit" | "attack" | "leave";
  t: number;
};

export type ActionId =
  | "spawn_monster"
  | "crow_attack"
  | "up_1"
  | "down_1"
  | "up_5"
  | "down_5"
  | "custom"
  | "reset"
  | "push_forward"
  | "push_back"
  | "push_water";
