"use client";

import { useState } from "react";

export type AdminUserRow = {
  id: string;
  name: string | null;
  email: string | null;
  image: string | null;
  role: string;
  active: boolean;
  createdAt: string;
};

export function AdminUsersTable({
  initialUsers,
  currentUserId,
}: {
  initialUsers: AdminUserRow[];
  currentUserId: string;
}) {
  const [users, setUsers] = useState(initialUsers);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function setActive(id: string, active: boolean) {
    setBusyId(id);
    setError(null);
    const res = await fetch(`/api/v1/admin/users/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ active }),
    });
    const data = await res.json();
    setBusyId(null);
    if (!res.ok) {
      setError(data.message || "Update failed");
      return;
    }
    setUsers((list) =>
      list.map((u) => (u.id === id ? { ...u, active: data.user.active } : u)),
    );
  }

  return (
    <div className="space-y-4">
      {error && (
        <p className="rounded-lg border border-[var(--bad)]/40 bg-[#2a1515] px-3 py-2 text-sm text-[var(--bad)]">
          {error}
        </p>
      )}
      <div className="overflow-x-auto rounded-2xl border border-[var(--line)] bg-[var(--panel)]">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="border-b border-[var(--line)] text-xs uppercase tracking-wide text-[var(--mute)]">
            <tr>
              <th className="px-4 py-3 font-medium">User</th>
              <th className="px-4 py-3 font-medium">Role</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Joined</th>
              <th className="px-4 py-3 font-medium">Active</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => {
              const locked = u.role === "admin" || u.id === currentUserId;
              return (
                <tr key={u.id} className="border-t border-[var(--line)]">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      {u.image ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={u.image}
                          alt=""
                          className="h-8 w-8 rounded-full"
                        />
                      ) : (
                        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-[var(--field)] text-xs">
                          {(u.name || u.email || "?").slice(0, 1).toUpperCase()}
                        </div>
                      )}
                      <div>
                        <div className="font-semibold">
                          {u.name || "—"}
                          {u.id === currentUserId && (
                            <span className="ml-2 text-xs font-normal text-[var(--mute)]">
                              you
                            </span>
                          )}
                        </div>
                        <div className="text-[var(--mute)]">{u.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3 capitalize">{u.role}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs ${
                        u.active || u.role === "admin"
                          ? "bg-[#1d3a28] text-[var(--ok)]"
                          : "bg-[#2a1515] text-[var(--bad)]"
                      }`}
                    >
                      {u.role === "admin" || u.active ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-[var(--mute)]">
                    {new Date(u.createdAt).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3">
                    <button
                      type="button"
                      disabled={locked || busyId === u.id}
                      onClick={() => void setActive(u.id, !u.active)}
                      className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-3 py-1.5 disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      {busyId === u.id
                        ? "…"
                        : u.active
                          ? "Deactivate"
                          : "Activate"}
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
