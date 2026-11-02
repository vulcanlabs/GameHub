import Link from "next/link";
import { HubShell } from "@/components/HubShell";

export function PendingAccess() {
  return (
    <HubShell active="home">
      <div className="rounded-[36px] bg-[var(--card)] p-7 text-center text-[var(--card-ink)]">
        <p className="text-xs font-bold tracking-[0.22em] text-[var(--card-mute)]">
          WAITING
        </p>
        <h1 className="mt-3 text-4xl leading-none font-extrabold tracking-tight">
          Account pending
        </h1>
        <p className="mt-4 text-lg text-[var(--card-mute)]">
          Your account is registered but not active yet. An admin must turn it
          on before you can open games.
        </p>
        <Link
          href="/"
          className="mt-6 inline-flex h-14 items-center rounded-full bg-[var(--card-ink)] px-6 text-lg font-bold text-[var(--ink)]"
        >
          Back to home
        </Link>
      </div>
    </HubShell>
  );
}
