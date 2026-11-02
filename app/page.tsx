import Link from "next/link";
import { HubShell } from "@/components/HubShell";
import { GameRow } from "@/components/GameRow";
import { GAMES } from "@/games/registry";
import { auth } from "@/lib/auth";
import { canAccessGames } from "@/lib/roles";

export default async function HomePage() {
  const session = await auth();
  const gamesOk = canAccessGames({
    role: session?.user?.role,
    active: session?.user?.active,
  });

  return (
    <HubShell active="home">
      <p className="text-xs font-bold tracking-[0.22em]">TONIGHT</p>
      <h1 className="mt-2 text-5xl leading-none font-extrabold tracking-tight">
        Home
      </h1>
      <p className="mt-3 text-lg text-[var(--mute)]">
        Keep this hub open while you stream. Run the TikFinity bridge on the
        same PC as TikFinity.
      </p>

      {session?.user && !gamesOk && (
        <div className="mt-6 rounded-[28px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
          <b className="text-xl text-[var(--bad)]">Account pending</b>
          <p className="mt-2 text-lg text-[var(--card-mute)]">
            You are signed in. An admin must activate your account before games
            unlock.
          </p>
        </div>
      )}

      {!session?.user && (
        <Link
          href="/login"
          className="mt-6 block rounded-[36px] bg-[var(--card)] p-7 text-[var(--card-ink)] shadow-[0_18px_40px_rgba(22,48,52,0.18)]"
        >
          <p className="text-xs font-bold tracking-[0.22em] text-[var(--card-mute)]">
            START
          </p>
          <h2 className="mt-3 text-4xl leading-none font-extrabold tracking-tight">
            Sign in to play
          </h2>
          <p className="mt-3 text-lg text-[var(--card-mute)]">
            Google opens your games, hook URL, and gift map.
          </p>
          <span className="mt-6 inline-flex h-14 items-center rounded-full bg-[var(--card-ink)] px-6 text-lg font-bold text-[var(--ink)]">
            Continue
          </span>
        </Link>
      )}

      {gamesOk ? (
        <ul className="mt-6 space-y-3">
          {GAMES.map((g, i) => (
            <li key={g.slug}>
              <GameRow game={g} index={i} />
            </li>
          ))}
        </ul>
      ) : null}
    </HubShell>
  );
}
