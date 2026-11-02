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

export type GiftEntry = {
  name: string;
  emoji: string;
  /** One coin price, or both when TikTok lists the same name twice. */
  coins?: number | number[];
};

export const GIFT_CATALOG: GiftEntry[] = [
  { name: "Rose", emoji: "🌹", coins: 1 },
  { name: "TikTok", emoji: "🎵", coins: 1 },
  { name: "GG", emoji: "🎮", coins: 1 },
  { name: "Ice Cream Cone", emoji: "🍦", coins: 1 },
  { name: "Heart Me", emoji: "💗", coins: 1 },
  { name: "Love you", emoji: "😘", coins: 1 },
  { name: "Finger Heart", emoji: "🫰", coins: 5 },
  { name: "Rosa", emoji: "🌷", coins: 10 },
  { name: "Perfume", emoji: "🧴", coins: 20 },
  { name: "Doughnut", emoji: "🍩", coins: 30 },
  { name: "Paper Crane", emoji: "🕊️", coins: 99 },
  { name: "Little Crown", emoji: "👑", coins: 99 },
  { name: "Hand Heart", emoji: "🫶", coins: 100 },
  { name: "Confetti", emoji: "🎊", coins: 100 },
  { name: "Love You", emoji: "🤟", coins: 199 },
  { name: "Sunglasses", emoji: "🕶️", coins: 199 },
  { name: "Corgi", emoji: "🐶", coins: 299 },
  { name: "Money Gun", emoji: "💸", coins: 500 },
  { name: "Swan", emoji: "🦢", coins: 699 },
  { name: "Galaxy", emoji: "🌌", coins: 1000 },
  { name: "Watermelon Love", emoji: "🍉", coins: 1000 },
  { name: "Fireworks", emoji: "🎆", coins: 1088 },
  { name: "Diamond", emoji: "💎", coins: 1099 },
  { name: "Whale Diving", emoji: "🐋", coins: 2150 },
  { name: "Sports Car", emoji: "🏎️", coins: [4999, 7000] },
  { name: "Interstellar", emoji: "🚀", coins: 10000 },
  { name: "Castle Fantasy", emoji: "🏰", coins: 20000 },
  { name: "Phoenix", emoji: "🔥", coins: 25999 },
  { name: "Dragon Flame", emoji: "🐉", coins: 26999 },
  { name: "Lion", emoji: "🦁", coins: 29999 },
  { name: "TikTok Universe+", emoji: "🌠", coins: 34999 },
  { name: "TikTok Universe", emoji: "🪐", coins: 44999 },
];

/** Old hub names that no longer match a TikTok gift. */
const GIFT_NAME_FIXES: Record<string, string> = {
  "Hand Hearts": "Hand Heart",
  Universe: "TikTok Universe+",
  Dragon: "Dragon Flame",
  Castle: "Castle Fantasy",
};

export const DEFAULT_BINDINGS: Record<string, string> = {
  Rose: "push_back",
  TikTok: "push_forward",
  "Finger Heart": "up_1",
  Perfume: "down_1",
  Doughnut: "crow_attack",
  "Hand Heart": "up_5",
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

export function formatGiftCoins(coins?: number | number[]): string {
  if (coins == null) return "";
  return (Array.isArray(coins) ? coins : [coins]).join(" / ");
}

/** True when two catalog gifts differ only by case, such as Love you and Love You. */
export function hasCaseDistinctGifts(name: string): boolean {
  const lower = name.toLowerCase();
  let hits = 0;
  for (const gift of GIFT_CATALOG) {
    if (gift.name.toLowerCase() === lower) hits += 1;
    if (hits > 1) return true;
  }
  return false;
}

export function giftEmoji(name: string): string {
  const exact = GIFT_CATALOG.find((g) => g.name === name);
  if (exact) return exact.emoji;
  if (hasCaseDistinctGifts(name)) return "🎁";
  return (
    GIFT_CATALOG.find((g) => g.name.toLowerCase() === name.toLowerCase())
      ?.emoji ?? "🎁"
  );
}

/** Rewrite retired gift names. An already-correct key wins over the old one. */
export function normalizeBindingNames(
  bindings: Record<string, string>,
): Record<string, string> {
  const out: Record<string, string> = {};
  const pending: [string, string][] = [];
  for (const [name, action] of Object.entries(bindings)) {
    const fixed = GIFT_NAME_FIXES[name];
    if (!fixed) out[name] = action;
    else pending.push([fixed, action]);
  }
  for (const [name, action] of pending) {
    if (!out[name]) out[name] = action;
  }
  return out;
}

export function isAction(id: string): boolean {
  return id in ACTIONS;
}
