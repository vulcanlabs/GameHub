"use client";

import { useCallback, useEffect, useState } from "react";

export type DesktopDevice = {
  id: string;
  name: string;
  slug: string;
  lastStatus: string | null;
  lastScore: number | null;
  lastSeenAt: string | null;
  createdAt: string;
};

function seenLabel(iso: string | null) {
  if (!iso) return "not seen";
  const age = Date.now() - new Date(iso).getTime();
  if (age < 40_000) return "polling";
  return `last ${new Date(iso).toLocaleTimeString()}`;
}

export function DesktopLink({
  slug,
  title,
  initialDevices,
}: {
  slug: string;
  title: string;
  initialDevices: DesktopDevice[];
}) {
  const [devices, setDevices] = useState(initialDevices);
  const [code, setCode] = useState<string | null>(null);
  const [expiresAt, setExpiresAt] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const refresh = useCallback(async () => {
    const res = await fetch(`/api/v1/devices?slug=${encodeURIComponent(slug)}`);
    if (!res.ok) return;
    const data = await res.json();
    setDevices(data.devices ?? []);
  }, [slug]);

  useEffect(() => {
    const id = setInterval(() => void refresh(), 8000);
    return () => clearInterval(id);
  }, [refresh]);

  async function mint() {
    setBusy(true);
    setError(null);
    const res = await fetch("/api/v1/devices/codes", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ slug }),
    });
    const data = await res.json();
    setBusy(false);
    if (!res.ok) {
      setError(data.message || "Could not create a code");
      return;
    }
    setCode(data.code);
    setExpiresAt(data.expiresAt);
  }

  async function revoke(id: string) {
    setBusy(true);
    setError(null);
    const res = await fetch(`/api/v1/devices/${id}`, { method: "DELETE" });
    const data = await res.json().catch(() => ({}));
    setBusy(false);
    if (!res.ok) {
      setError(data.message || "Revoke failed");
      return;
    }
    setDevices((list) => list.filter((d) => d.id !== id));
  }

  return (
    <section className="rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
      <h2 className="text-2xl font-extrabold tracking-tight">Desktop app</h2>
      <p className="mt-1 text-base text-[var(--card-mute)]">
        Open {title} in Godot, enter this hub URL and a one-time code.
        The app never talks to TikFinity.
      </p>
      {error && (
        <p className="mt-3 rounded-[20px] bg-[#fde8ea] px-4 py-3 text-sm font-semibold text-[var(--bad)]">
          {error}
        </p>
      )}
      <div className="mt-4 flex flex-wrap items-center gap-3">
        <button
          type="button"
          disabled={busy}
          onClick={() => void mint()}
          className="h-12 rounded-full bg-[var(--card-ink)] px-5 text-sm font-bold text-[var(--ink)] disabled:opacity-40"
        >
          {busy ? "…" : "Create link code"}
        </button>
        {code && (
          <div>
            <p className="text-3xl font-extrabold tracking-[0.2em]">{code}</p>
            <p className="text-sm text-[var(--card-mute)]">
              Expires {expiresAt ? new Date(expiresAt).toLocaleTimeString() : ""}
            </p>
          </div>
        )}
      </div>
      <ul className="mt-4 space-y-2">
        {devices.length === 0 && (
          <li className="text-sm text-[var(--card-mute)]">No linked devices.</li>
        )}
        {devices.map((d) => (
          <li
            key={d.id}
            className="flex items-center gap-3 rounded-[20px] bg-[var(--sand)] px-3 py-2"
          >
            <div className="min-w-0 flex-1">
              <div className="truncate font-extrabold">{d.name}</div>
              <div className="text-sm text-[var(--card-mute)]">
                {seenLabel(d.lastSeenAt)}
                {d.lastStatus ? ` · ${d.lastStatus}` : ""}
                {d.lastScore != null ? ` · score ${d.lastScore}` : ""}
              </div>
            </div>
            <button
              type="button"
              disabled={busy}
              onClick={() => void revoke(d.id)}
              className="h-10 flex-none rounded-full bg-[#fde8ea] px-3 text-sm font-bold text-[var(--bad)] disabled:opacity-40"
            >
              Revoke
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
