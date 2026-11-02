export const ACTIONS: Record<string, { label: string; description: string }> = {
  spawn_monster: {
    label: "SPAWN MONSTER",
    description: "Adds another monster that roams the water.",
  },
  crow_attack: {
    label: "CROW ATTACK",
    description: "A crow swoops down and knocks the player backwards.",
  },
  up_1: {
    label: "UP 1 CHECKPOINT",
    description: "Moves the player forward one checkpoint.",
  },
  down_1: {
    label: "DOWN 1 CHECKPOINT",
    description: "Sends the player back one checkpoint.",
  },
  up_5: {
    label: "UP 5 CHECKPOINTS",
    description: "Moves the player forward five checkpoints.",
  },
  down_5: {
    label: "DOWN 5 CHECKPOINTS",
    description: "Sends the player back five checkpoints.",
  },
  custom: {
    label: "CUSTOM CHECKPOINT",
    description: "Moves by the amount set in Settings (negative goes back).",
  },
  reset: {
    label: "RESET",
    description: "Sends the player back to the start.",
  },
  push_forward: {
    label: "PUSH FORWARD",
    description: "Shoves the player forward.",
  },
  push_back: {
    label: "PUSH BACKWARD",
    description: "Shoves the player backwards.",
  },
  push_water: {
    label: "PUSH INTO WATER",
    description: "Knocks the player off the platform. The splash wakes the monster.",
  },
};

export type GiftEntry = { name: string; emoji: string; coins?: number };

export const GIFT_CATALOG: GiftEntry[] = [
  { name: "Rose", emoji: "🌹", coins: 1 },
  { name: "TikTok", emoji: "🎵", coins: 1 },
  { name: "GG", emoji: "🎮", coins: 1 },
  { name: "Ice Cream Cone", emoji: "🍦", coins: 1 },
  { name: "Heart Me", emoji: "💗", coins: 1 },
  { name: "Finger Heart", emoji: "🫰", coins: 5 },
  { name: "Rosa", emoji: "🌷", coins: 10 },
  { name: "Perfume", emoji: "🧴", coins: 20 },
  { name: "Doughnut", emoji: "🍩", coins: 30 },
  { name: "Hand Hearts", emoji: "🫶", coins: 100 },
  { name: "Confetti", emoji: "🎊", coins: 100 },
  { name: "Sunglasses", emoji: "🕶️", coins: 199 },
  { name: "Corgi", emoji: "🐶", coins: 299 },
  { name: "Money Gun", emoji: "💸", coins: 500 },
  { name: "Swan", emoji: "🦢", coins: 699 },
  { name: "Galaxy", emoji: "🌌", coins: 1000 },
  { name: "Watermelon Love", emoji: "🍉", coins: 1000 },
  { name: "Lion", emoji: "🦁", coins: 29999 },
  { name: "Universe", emoji: "🪐", coins: 34999 },
  { name: "Paper Crane", emoji: "🕊️" },
  { name: "Little Crown", emoji: "👑" },
  { name: "Love You", emoji: "🤟" },
  { name: "Flower Heart", emoji: "💐" },
  { name: "Fireworks", emoji: "🎆" },
  { name: "Sports Car", emoji: "🏎️" },
  { name: "Yacht", emoji: "🛥️" },
  { name: "Diamond", emoji: "💎" },
  { name: "Whale Diving", emoji: "🐋" },
  { name: "Interstellar", emoji: "🚀" },
  { name: "Phoenix", emoji: "🔥" },
  { name: "Dragon", emoji: "🐉" },
  { name: "Castle", emoji: "🏰" },
];

export const DEFAULT_BINDINGS: Record<string, string> = {
  Rose: "push_back",
  TikTok: "push_forward",
  "Finger Heart": "up_1",
  Perfume: "down_1",
  Doughnut: "crow_attack",
  "Hand Hearts": "up_5",
  Galaxy: "down_5",
  Lion: "spawn_monster",
};

export type GameSettings = {
  monster: "stalker" | "crawler" | "beast" | "shadow";
  diff: number;
  fov: number;
  push: number;
  custom: number;
};

export const DEFAULT_SETTINGS: GameSettings = {
  monster: "stalker",
  diff: 1,
  fov: 90,
  push: 12,
  custom: 3,
};

export function giftEmoji(name: string): string {
  return (
    GIFT_CATALOG.find((g) => g.name.toLowerCase() === name.toLowerCase())?.emoji ??
    "🎁"
  );
}

export function isAction(id: string): boolean {
  return id in ACTIONS;
}
