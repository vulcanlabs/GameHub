import Link from "next/link";
import { HubShell } from "@/components/HubShell";

export function PendingAccess() {
  return (
    <HubShell active="home">
      <div className="mx-auto max-w-lg px-8 py-16 text-center">
        <h1 className="text-2xl font-bold">Account pending</h1>
        <p className="mt-3 text-[var(--mute)]">
          Your account is registered but not active yet. An admin must turn it
          on before you can open games.
        </p>
        <Link
          href="/"
          className="mt-6 inline-block rounded-full bg-white px-6 py-3 font-bold text-[#111]"
        >
          Back to home
        </Link>
      </div>
    </HubShell>
  );
}
