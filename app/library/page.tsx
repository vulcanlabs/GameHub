import { redirect } from "next/navigation";
import { HubShell } from "@/components/HubShell";
import { GameRow } from "@/components/GameRow";
import { PendingAccess } from "@/components/PendingAccess";
import { GAMES } from "@/games/registry";
import { auth } from "@/lib/auth";
import { canAccessGames } from "@/lib/roles";

export default async function LibraryPage() {
  const session = await auth();
  if (!session?.user?.id) redirect("/login");
  if (
    !canAccessGames({
      role: session.user.role,
      active: session.user.active,
    })
  ) {
    return <PendingAccess />;
  }

  return (
    <HubShell active="library">
      <p className="text-xs font-bold tracking-[0.22em]">WORKSHOP</p>
      <h1 className="mt-2 text-5xl leading-none font-extrabold tracking-tight">
        Library
      </h1>
      <p className="mt-3 text-lg text-[var(--mute)]">
        Games registered here. Add a folder under{" "}
        <code className="font-bold">games/</code> and a row in{" "}
        <code className="font-bold">games/registry.ts</code>.
      </p>
      <ul className="mt-6 space-y-3">
        {GAMES.map((g, i) => (
          <li key={g.slug}>
            <GameRow game={g} index={i} />
          </li>
        ))}
      </ul>
    </HubShell>
  );
}
