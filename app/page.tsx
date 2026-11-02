import Link from "next/link";
import { HubShell } from "@/components/HubShell";
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
      <div className="mx-auto max-w-[1100px] px-8 py-8">
        <h1 className="text-3xl font-bold">Home</h1>
        <p className="mt-1 text-[var(--mute)]">
          Your LIVE interactive games. Keep the hub open while you stream, and
          run the TikFinity bridge on the same PC as TikFinity.
        </p>

        {!gamesOk && (
          <div className="mt-6 rounded-2xl border border-[var(--bad)]/40 bg-[#2a1515] p-4">
            <b className="text-[var(--bad)]">Account pending activation</b>
            <p className="mt-1 text-sm text-[var(--mute)]">
              You are signed in, but an admin must activate your account before
              games unlock.
            </p>
          </div>
        )}

        {gamesOk ? (
          <div className="mt-6 grid grid-cols-[repeat(auto-fill,minmax(230px,1fr))] gap-4">
            {GAMES.map((g) => (
              <Link
                key={g.slug}
                href={`/games/${g.slug}`}
                className="overflow-hidden rounded-2xl border border-[var(--line)] bg-[var(--panel)]"
              >
                <div className="flex h-[130px] items-center justify-center bg-gradient-to-br from-[#3b6b73] to-[#0b1b1f] text-5xl">
                  {g.emoji}
                </div>
                <div className="px-3.5 py-3">
                  <b>{g.title}</b>
                  <div className="text-[var(--mute)]">
                    {g.genre} · {g.version}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        ) : null}
      </div>
    </HubShell>
  );
}
