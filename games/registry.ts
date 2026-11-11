export type GameRuntime = "web" | "desktop";

export type GameMeta = {
  slug: string;
  title: string;
  emoji: string;
  genre: string;
  blurb: string;
  version: string;
  runtime: GameRuntime;
};

export const GAMES: GameMeta[] = [
  {
    slug: "dont-touch-the-water",
    title: "Don’t Touch the Water",
    emoji: "🌊",
    genre: "Arcade",
    blurb:
      "Godot on the stream PC. Stay on the platforms. LIVE gifts shove you, spawn monsters, and change levels.",
    version: "v1.0.0",
    runtime: "desktop",
  },
  {
    slug: "pulse-beacon",
    title: "Pulse Beacon",
    emoji: "📡",
    genre: "Desktop",
    blurb:
      "Godot app on the stream PC. Gifts move the beacon. TikFinity stays on the hub.",
    version: "v0.1.0",
    runtime: "desktop",
  },
  {
    slug: "dont-touch-the-lava",
    title: "Don’t Touch the Lava",
    emoji: "🌋",
    genre: "Parkour",
    blurb:
      "First-person Godot parkour. Jump a generated platform chain. Lava costs a life.",
    version: "v0.1.0",
    runtime: "desktop",
  },
  {
    slug: "dont-touch-the-grass",
    title: "Don’t Touch the Grass",
    emoji: "🌱",
    genre: "Parkour",
    blurb:
      "First-person Backrooms horror parkour across 50 levels. Stay on the platforms. The grass belongs to giant ants, and a spider joins from level 25.",
    version: "v0.1.0",
    runtime: "desktop",
  },
];

export function isDesktopGame(slug: string): boolean {
  return getGame(slug)?.runtime === "desktop";
}

export function getGame(slug: string): GameMeta | undefined {
  return GAMES.find((g) => g.slug === slug);
}
