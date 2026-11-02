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

  async function deleteUser(id: string, label: string) {
    if (!confirm(`Delete ${label}? This cannot be undone.`)) return;
    setBusyId(id);
    setError(null);
    const res = await fetch(`/api/v1/admin/users/${id}`, { method: "DELETE" });
    const data = await res.json().catch(() => ({}));
    setBusyId(null);
    if (!res.ok) {
      setError(data.message || "Delete failed");
      return;
    }
    setUsers((list) => list.filter((u) => u.id !== id));
  }

  return (
    <div className="space-y-4">
      {error && (
        <p className="rounded-[24px] bg-[#fde8ea] px-4 py-3 text-base font-semibold text-[var(--bad)]">
          {error}
        </p>
      )}
      <ul className="space-y-4">
        {users.map((u) => {
          const locked = u.role === "admin" || u.id === currentUserId;
          const canDelete = u.role !== "admin" && u.id !== currentUserId;
          const live = u.role === "admin" || u.active;
          return (
            <li
              key={u.id}
              className="flex items-center gap-3 overflow-x-auto rounded-[28px] bg-[var(--card)] px-3 py-3 text-[var(--card-ink)]"
            >
              {u.image ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={u.image} alt="" className="h-12 w-12 flex-none rounded-full" />
              ) : (
                <div className="flex h-12 w-12 flex-none items-center justify-center rounded-full bg-[var(--sand)] text-lg font-bold">
                  {(u.name || u.email || "?").slice(0, 1).toUpperCase()}
                </div>
              )}
              <div className="min-w-40 flex-1">
                <div className="truncate text-lg font-extrabold">
                  {u.name || "—"}
                  {u.id === currentUserId && (
                    <span className="ml-2 text-sm font-semibold text-[var(--card-mute)]">
                      you
                    </span>
                  )}
                </div>
                <div className="truncate text-sm text-[var(--card-mute)]">
                  {u.email}
                </div>
              </div>
              <span className="flex-none rounded-full bg-[var(--sand)] px-3 py-1.5 text-sm font-bold capitalize">
                {u.role}
              </span>
              <span
                className={`flex-none rounded-full px-3 py-1.5 text-sm font-bold ${
                  live
                    ? "bg-[#d9f6ef] text-[var(--ok)]"
                    : "bg-[#fde8ea] text-[var(--bad)]"
                }`}
              >
                {live ? "Active" : "Inactive"}
              </span>
              <span className="flex-none text-sm font-bold text-[var(--card-mute)]">
                {new Date(u.createdAt).toLocaleDateString()}
              </span>
              <button
                type="button"
                disabled={locked || busyId === u.id}
                onClick={() => void setActive(u.id, !u.active)}
                className="h-12 flex-none rounded-full bg-[var(--card-ink)] px-4 text-sm font-bold text-[var(--ink)] disabled:cursor-not-allowed disabled:opacity-40"
              >
                {busyId === u.id ? "…" : u.active ? "Deactivate" : "Activate"}
              </button>
              <button
                type="button"
                disabled={!canDelete || busyId === u.id}
                onClick={() =>
                  void deleteUser(u.id, u.email || u.name || "user")
                }
                className="h-12 flex-none rounded-full bg-[#fde8ea] px-4 text-sm font-bold text-[var(--bad)] disabled:cursor-not-allowed disabled:opacity-40"
              >
                Delete
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
