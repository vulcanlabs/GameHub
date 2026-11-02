import { redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { isAdminRole } from "@/lib/roles";
import { HubShell } from "@/components/HubShell";
import { AdminUsersTable } from "@/components/AdminUsersTable";

export default async function AdminUsersPage() {
  const session = await auth();
  if (!session?.user?.id) redirect("/login");
  if (!isAdminRole(session.user.role)) redirect("/");

  const users = await prisma.user.findMany({
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      name: true,
      email: true,
      image: true,
      role: true,
      active: true,
      createdAt: true,
    },
  });

  return (
    <HubShell active="admin-users">
      <p className="text-xs font-bold tracking-[0.22em]">ADMIN</p>
      <h1 className="mt-2 text-5xl leading-none font-extrabold tracking-tight">
        Users
      </h1>
      <p className="mt-3 text-lg text-[var(--mute)]">
        New accounts stay inactive until you activate them. Only active users
        can open games. Admins stay active.
      </p>
      <div className="mt-6">
        <AdminUsersTable
          currentUserId={session.user.id}
          initialUsers={users.map((u) => ({
            ...u,
            createdAt: u.createdAt.toISOString(),
          }))}
        />
      </div>
    </HubShell>
  );
}
