import Link from "next/link";
import { redirect } from "next/navigation";
import { HubShell } from "@/components/HubShell";
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
      <div className="mx-auto max-w-[1100px] px-8 py-8">
        <h1 className="text-3xl font-bold">Library</h1>
        <p className="mt-1 text-[var(--mute)]">
          Games registered in this workshop. Add a folder under{" "}
          <code className="text-[var(--acc)]">games/</code> and a row in{" "}
          <code className="text-[var(--acc)]">games/registry.ts</code>.
        </p>
        <ul className="mt-6 space-y-3">
          {GAMES.map((g) => (
            <li key={g.slug}>
              <Link
                href={`/games/${g.slug}`}
                className="flex items-center gap-4 rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4 hover:border-[var(--acc)]"
              >
                <span className="text-3xl">{g.emoji}</span>
                <div>
                  <b>{g.title}</b>
                  <p className="text-[var(--mute)]">{g.blurb}</p>
                </div>
                <span className="ml-auto text-[var(--mute)]">{g.version}</span>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </HubShell>
  );
}
