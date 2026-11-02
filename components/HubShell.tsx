import Link from "next/link";
import { auth, signOut } from "@/lib/auth";
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
  const onLibrary =
    active === "library" ||
    (Boolean(active) && active !== "home" && active !== "admin-users");

  return (
    <div className="relative min-h-full">
      <header className="sticky top-0 z-30 px-4 pt-[max(0.75rem,env(safe-area-inset-top))]">
        <div className="mx-auto flex max-w-[480px] items-center gap-3 rounded-full bg-[var(--card)]/95 px-4 py-2.5 text-[var(--card-ink)] shadow-[0_10px_30px_rgba(22,48,52,0.16)] backdrop-blur">
          <Link href="/" className="min-w-0 flex-1">
            <div className="text-xl leading-none font-extrabold tracking-tight">
              Game Hub
            </div>
            {session?.user ? (
              <div className="mt-1 truncate text-sm text-[var(--card-mute)]">
                {session.user.email || session.user.name}
                {!gamesOk ? " · pending" : ""}
              </div>
            ) : (
              <div className="mt-1 text-sm text-[var(--card-mute)]">
                Sign in to play
              </div>
            )}
          </Link>
          {session?.user ? (
            <form
              action={async () => {
                "use server";
                await signOut({ redirectTo: "/login" });
              }}
            >
              <button
                type="submit"
                className="h-12 rounded-full bg-[var(--sand)] px-4 text-base font-bold"
              >
                Sign out
              </button>
            </form>
          ) : (
            <Link
              href="/login"
              className="inline-flex h-12 items-center rounded-full bg-[var(--card-ink)] px-4 text-base font-bold text-[var(--ink)]"
            >
              Sign in
            </Link>
          )}
        </div>
      </header>

      <main className="mx-auto max-w-[1040px] px-4 pt-6 pb-36">{children}</main>

      <nav className="fixed inset-x-0 bottom-0 z-40 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
        <div className="mx-auto flex max-w-[480px] gap-1 rounded-full bg-[var(--card)]/95 p-1.5 shadow-[0_12px_36px_rgba(22,48,52,0.2)] backdrop-blur">
          <Tab href="/" active={active === "home"}>
            Home
          </Tab>
          {gamesOk && (
            <Tab href="/library" active={onLibrary}>
              Library
            </Tab>
          )}
          {admin && (
            <Tab href="/admin/users" active={active === "admin-users"}>
              Users
            </Tab>
          )}
        </div>
      </nav>
    </div>
  );
}

function Tab({
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
      className={`flex h-14 flex-1 items-center justify-center rounded-full text-base font-bold ${
        active
          ? "bg-[var(--card-ink)] text-[var(--ink)]"
          : "text-[var(--card-mute)]"
      }`}
    >
      {children}
    </Link>
  );
}
