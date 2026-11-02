import type { ActionId, MonsterType } from "./types";

export const PLATFORM_COUNT = 90;
export const CHECKPOINT_EVERY = 5;

/** Gap ranges per difficulty: Easy, Normal, Hard, Nightmare. ~1.8× original. */
export const DIFF_GAPS = [
  { gmin: 2.9, gmax: 4.3, wmin: 3.4 },
  { gmin: 4.0, gmax: 5.6, wmin: 2.9 },
  { gmin: 5.0, gmax: 6.7, wmin: 2.4 },
  { gmin: 6.0, gmax: 8.0, wmin: 2.0 },
] as const;

export const SPEED = {
  land: 6.5,
  landSprint: 10,
  water: 3.5,
  waterSprint: 5.5,
} as const;

export const MONSTER_TYPES: Record<
  MonsterType,
  { c: number; s: number; roam: number; charge: number; tele?: number }
> = {
  stalker: { c: 0x1b1b22, s: 1.5, roam: 2.5, charge: 8.5 },
  crawler: { c: 0x5a2323, s: 1.1, roam: 3.5, charge: 11.5 },
  beast: { c: 0x1d4630, s: 2.4, roam: 2, charge: 7.5 },
  shadow: { c: 0x050505, s: 1.6, roam: 2.5, charge: 8, tele: 1 },
};

export const ACTION_LABELS: Record<ActionId, string> = {
  spawn_monster: "Spawn Monster",
  crow_attack: "Crow Attack",
  up_1: "Up 1 Checkpoint",
  down_1: "Down 1 Checkpoint",
  up_5: "Up 5 Checkpoints",
  down_5: "Down 5 Checkpoints",
  custom: "Custom Checkpoint",
  reset: "Reset",
  push_forward: "Push Forward",
  push_back: "Push Backward",
  push_water: "Push into Water",
};

export const DEFAULT_KEYS: Record<ActionId, string> = {
  spawn_monster: "F1",
  crow_attack: "F2",
  up_1: "F3",
  down_1: "F4",
  up_5: "F6",
  down_5: "F7",
  custom: "F8",
  reset: "F9",
  push_forward: "F10",
  push_back: "F11",
  push_water: "F12",
};
