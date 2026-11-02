import Link from "next/link";
import { auth, signOut } from "@/lib/auth";
import { GAMES } from "@/games/registry";
import { canAccessGames, isAdminRole } from "@/lib/roles";

export async function HubShell({
  children,
  active,
}: {
  children: React.ReactNode;
  active?: string;
}) {
  const session = await auth();
  const admin = isAdminRole(session?.user?.role);
  const gamesOk = canAccessGames({
    role: session?.user?.role,
    active: session?.user?.active,
  });

  return (
    <div className="flex min-h-full">
      <aside className="flex w-[230px] flex-none flex-col gap-1 border-r border-[var(--line)] bg-[var(--side)] p-3">
        <div className="mb-4 px-2 text-lg font-extrabold">Game Hub</div>
        <NavLink href="/" active={active === "home"}>
          Home
        </NavLink>
        {gamesOk && (
          <NavLink href="/library" active={active === "library"}>
            Library
            <em className="ml-auto text-xs text-[var(--mute)] not-italic">
              {GAMES.length}
            </em>
          </NavLink>
        )}
        {gamesOk && (
          <>
            <div className="mt-4 px-2 text-[11px] tracking-widest text-[var(--mute)]">
              GAMES
            </div>
            {GAMES.map((g) => (
              <NavLink
                key={g.slug}
                href={`/games/${g.slug}`}
                active={active === g.slug}
              >
                <span aria-hidden>{g.emoji}</span> {g.title}
              </NavLink>
            ))}
          </>
        )}
        {admin && (
          <>
            <div className="mt-4 px-2 text-[11px] tracking-widest text-[var(--mute)]">
              ADMIN
            </div>
            <NavLink href="/admin/users" active={active === "admin-users"}>
              Users
            </NavLink>
          </>
        )}
        <div className="mt-auto rounded-[10px] border border-[var(--line)] p-3 text-sm">
          {session?.user ? (
            <div className="flex flex-col gap-2">
              <div className="truncate text-[var(--mute)]">
                {session.user.email || session.user.name}
              </div>
              <div className="text-xs capitalize text-[var(--mute)]">
                {session.user.role}
                {!gamesOk && " · pending"}
              </div>
              <form
                action={async () => {
                  "use server";
                  await signOut({ redirectTo: "/login" });
                }}
              >
                <button
                  type="submit"
                  className="w-full rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-1.5 text-left"
                >
                  Sign out
                </button>
              </form>
            </div>
          ) : (
            <Link href="/login" className="text-[var(--acc)]">
              Sign in
            </Link>
          )}
        </div>
      </aside>
      <main className="min-w-0 flex-1 overflow-y-auto bg-[radial-gradient(900px_300px_at_30%_-80px,#2a3a2a55,transparent)]">
        {children}
      </main>
    </div>
  );
}

function NavLink({
  href,
  active,
  children,
}: {
  href: string;
  active?: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className={`flex items-center gap-2 rounded-lg px-2.5 py-2 text-left ${
        active ? "bg-[var(--field)]" : "hover:bg-[var(--field)]"
      }`}
    >
      {children}
    </Link>
  );
}
