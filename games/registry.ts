export type GameMeta = {
  slug: string;
  title: string;
  emoji: string;
  genre: string;
  blurb: string;
  version: string;
};

export const GAMES: GameMeta[] = [
  {
    slug: "dont-touch-the-water",
    title: "Don’t Touch the Water",
    emoji: "🌊",
    genre: "Arcade",
    blurb:
      "Stay on the platforms. LIVE gifts shove you, spawn monsters, and move checkpoints.",
    version: "v1.0.0",
  },
];

export function getGame(slug: string): GameMeta | undefined {
  return GAMES.find((g) => g.slug === slug);
}
