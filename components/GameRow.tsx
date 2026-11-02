import Link from "next/link";
import type { GameMeta } from "@/games/registry";

const WASH = ["#f6a15c", "#f6c1b4", "#8fdcd4"];

export function GameRow({
  game,
  index = 0,
}: {
  game: GameMeta;
  index?: number;
}) {
  const wash = WASH[index % WASH.length];

  return (
    <Link
      href={`/games/${game.slug}`}
      className="flex items-center gap-4 rounded-[28px] bg-[var(--card)] px-4 py-3 text-[var(--card-ink)] shadow-[0_10px_28px_rgba(22,48,52,0.12)]"
    >
      <span
        className="flex h-16 w-16 flex-none items-center justify-center rounded-full text-3xl"
        style={{ background: wash }}
      >
        {game.emoji}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-xl font-extrabold tracking-tight">
          {game.title}
        </span>
        <span className="block truncate text-base text-[var(--card-mute)]">
          {game.genre} · {game.blurb}
        </span>
      </span>
      <span className="flex-none text-sm font-bold tracking-[0.14em] text-[var(--card-mute)]">
        {game.version}
      </span>
    </Link>
  );
}
