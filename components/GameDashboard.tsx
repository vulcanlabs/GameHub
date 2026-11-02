"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { GameMeta } from "@/games/registry";
import {
  ACTIONS,
  GIFT_CATALOG,
  formatGiftCoins,
  giftEmoji,
  type GameSettings,
  type GiftEntry,
} from "@/lib/gifts";

type Props = {
  game: GameMeta;
  initialBindings: Record<string, string>;
  initialSettings: GameSettings;
  initialHook: { token: string; url: string };
};

type LogLine = { t: string; text: string };

export function GameDashboard({
  game,
  initialBindings,
  initialSettings,
  initialHook,
}: Props) {
  const [tab, setTab] = useState<"ov" | "st">("ov");
  const [bindings, setBindings] = useState(initialBindings);
  const [settings, setSettings] = useState(initialSettings);
  const [hook, setHook] = useState(initialHook);
  const [log, setLog] = useState<LogLine[]>([]);
  const [modal, setModal] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [selGift, setSelGift] = useState<string | null>(null);
  const [selAction, setSelAction] = useState("push_back");
  const [toast, setToast] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const pushLog = useCallback((text: string) => {
    setLog((L) =>
      [{ t: new Date().toLocaleTimeString(), text }, ...L].slice(0, 8),
    );
  }, []);

  useEffect(() => {
    const es = new EventSource(`/api/v1/games/${game.slug}/live`);
    es.onmessage = (ev) => {
      try {
        const data = JSON.parse(ev.data);
        if (data.type === "action") {
          pushLog(
            `🎁 ${data.giftName} → ${data.label || data.action}${
              data.repeatCount > 1 ? ` ×${data.repeatCount}` : ""
            }`,
          );
        }
      } catch {
        /* ignore */
      }
    };
    return () => es.close();
  }, [game.slug, pushLog]);

  function showToast(t: string) {
    setToast(t);
    setTimeout(() => setToast(null), 2800);
  }

  async function saveBindings(next: Record<string, string>) {
    setBindings(next);
    await fetch(`/api/v1/games/${game.slug}/bindings`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ bindings: next }),
    });
  }

  async function saveSettings(next: GameSettings) {
    setSettings(next);
    await fetch(`/api/v1/games/${game.slug}/settings`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(next),
    });
  }

  async function testGift(name: string) {
    const res = await fetch(`/api/v1/games/${game.slug}/test`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ giftName: name, repeatCount: 1 }),
    });
    const data = await res.json();
    if (data.ignored) {
      pushLog(`${name} – ${data.reason}`);
    } else {
      pushLog(
        `🎁 ${data.giftName} → ${ACTIONS[data.action]?.label || data.action}`,
      );
    }
  }

  async function rotateHook() {
    if (!confirm("Rotate hook token? The old URL stops working.")) return;
    setBusy(true);
    const res = await fetch("/api/v1/hooks/me", { method: "POST" });
    const data = await res.json();
    setHook(data);
    setBusy(false);
    showToast("Hook URL rotated");
  }

  function play() {
    const w = window.open(
      `/play/${game.slug}`,
      "gh-game",
      "width=1280,height=780",
    );
    if (!w) {
      showToast("Pop-up blocked. Allow pop-ups, then press Play again.");
      return;
    }
    pushLog("Game window opened");
  }

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    let list: GiftEntry[] = GIFT_CATALOG.filter((g) =>
      g.name.toLowerCase().includes(q),
    );
    if (q && !list.some((g) => g.name.toLowerCase() === q)) {
      list = [...list, { name: search.trim(), emoji: "➕" }];
    }
    if (editing && !q && !list.some((g) => g.name === editing)) {
      list = [{ name: editing, emoji: giftEmoji(editing) }, ...list];
    } else if (editing && !q) {
      const current = list.find((g) => g.name === editing);
      if (current) {
        list = [current, ...list.filter((g) => g.name !== editing)];
      }
    }
    return list;
  }, [search, editing]);

  function openAdd() {
    setEditing(null);
    setSelGift(null);
    setSearch("");
    setSelAction("push_back");
    setModal(true);
  }

  function openEdit(name: string) {
    setEditing(name);
    setSelGift(name);
    setSearch("");
    setSelAction(bindings[name] ?? "push_back");
    setModal(true);
  }

  function commitGift() {
    if (!selGift) {
      showToast("Pick a gift first");
      return;
    }
    if (editing && editing !== selGift && bindings[selGift]) {
      showToast("That gift is already in the list");
      return;
    }
    const next = { ...bindings };
    if (editing && editing !== selGift) delete next[editing];
    next[selGift] = selAction;
    void saveBindings(next);
    setModal(false);
  }

  const actionOptions = Object.entries(ACTIONS).map(([k, v]) => (
    <option key={k} value={k}>
      {v.label}
    </option>
  ));

  return (
    <div className="space-y-5 pb-4">
      <div className="flex items-center gap-4 rounded-[32px] bg-[var(--orange)] px-5 py-4 text-[var(--card-ink)] shadow-[0_18px_40px_rgba(22,48,52,0.18)]">
        <div className="flex h-16 w-16 flex-none items-center justify-center rounded-full bg-white/50 text-4xl">
          {game.emoji}
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold tracking-[0.22em]">
            {game.genre.toUpperCase()}
          </p>
          <h1 className="truncate text-3xl leading-none font-extrabold tracking-tight">
            {game.title}
          </h1>
          <p className="mt-1 text-base">
            {game.version} · {Object.keys(bindings).length} gifts · hook ready
          </p>
        </div>
        <button
          type="button"
          onClick={play}
          className="h-14 flex-none rounded-full bg-[var(--card-ink)] px-8 text-lg font-bold text-[var(--ink)]"
        >
          Play
        </button>
      </div>

      <div className="grid max-w-md grid-cols-2 gap-1 rounded-full bg-[var(--card)] p-1.5">
        <button
          type="button"
          className={`h-14 rounded-full text-base font-bold ${
            tab === "ov"
              ? "bg-[var(--card-ink)] text-[var(--ink)]"
              : "text-[var(--card-mute)]"
          }`}
          onClick={() => setTab("ov")}
        >
          Overview
        </button>
        <button
          type="button"
          className={`h-14 rounded-full text-base font-bold ${
            tab === "st"
              ? "bg-[var(--card-ink)] text-[var(--ink)]"
              : "text-[var(--card-mute)]"
          }`}
          onClick={() => setTab("st")}
        >
          Settings
        </button>
      </div>

      {tab === "ov" ? (
        <div className="grid items-start gap-4 lg:grid-cols-[1.5fr_1fr]">
          <section className="rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="text-2xl font-extrabold tracking-tight">
                  Gifts
                </h2>
                <p className="mt-1 text-base text-[var(--card-mute)]">
                  Tap a gift to change it. Test while the game window is open.
                </p>
              </div>
              <button
                type="button"
                className="h-12 flex-none rounded-full bg-[var(--sand)] px-5 text-base font-bold"
                onClick={openAdd}
              >
                Add gift
              </button>
            </div>
            {Object.keys(bindings).length === 0 && (
              <p className="mt-4 text-lg text-[var(--card-mute)]">
                No gifts yet.
              </p>
            )}
            <ul className="mt-4 space-y-2">
              {Object.entries(bindings).map(([name, action]) => (
                <li
                  key={name}
                  className="flex items-center gap-2 overflow-x-auto rounded-[24px] bg-[var(--sand)] px-2 py-2"
                >
                  <button
                    type="button"
                    title="Change gift"
                    className="flex min-w-44 flex-1 items-center gap-3 text-left"
                    onClick={() => openEdit(name)}
                  >
                    <span className="flex h-12 w-12 flex-none items-center justify-center rounded-full bg-[var(--card)] text-xl">
                      {giftEmoji(name)}
                    </span>
                    <span className="min-w-0">
                      <b className="block truncate text-base">{name}</b>
                      <span className="block truncate text-sm text-[var(--card-mute)]">
                        {ACTIONS[action]?.description}
                      </span>
                    </span>
                  </button>
                  <select
                    className="h-12 w-40 flex-none rounded-full bg-[var(--card)] px-3 text-sm font-bold text-[var(--card-ink)]"
                    value={action}
                    onChange={(e) => {
                      const next = { ...bindings, [name]: e.target.value };
                      void saveBindings(next);
                    }}
                  >
                    {actionOptions}
                  </select>
                  <button
                    type="button"
                    className="h-12 flex-none rounded-full bg-[var(--card-ink)] px-4 text-sm font-bold text-[var(--ink)]"
                    onClick={() => void testGift(name)}
                  >
                    Test
                  </button>
                  <button
                    type="button"
                    className="h-12 flex-none rounded-full bg-[var(--card)] px-4 text-sm font-bold"
                    onClick={() => {
                      const next = { ...bindings };
                      delete next[name];
                      void saveBindings(next);
                    }}
                  >
                    Remove
                  </button>
                </li>
              ))}
            </ul>
          </section>

          <div className="space-y-4">
          <section className="rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-2xl font-extrabold tracking-tight">Status</h2>
              <span className="rounded-full bg-[#d9f6ef] px-3 py-1 text-sm font-bold text-[var(--ok)]">
                Ready
              </span>
            </div>
            <p className="mt-3 text-lg text-[var(--card-mute)]">
              Gifts from your LIVE trigger the actions you set here.
            </p>
            <ol className="mt-4 space-y-4 text-base">
              <li className="flex gap-3">
                <b className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-[var(--sand)]">
                  1
                </b>
                <span>
                  Press Play. The game opens in its own window. Click inside it
                  to start.
                </span>
              </li>
              <li className="flex gap-3">
                <b className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-[var(--sand)]">
                  2
                </b>
                <span>
                  Run the TikFinity bridge with your hook URL. Keep this hub
                  open.
                </span>
              </li>
              <li className="flex gap-3">
                <b className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-[var(--sand)]">
                  3
                </b>
                <span>
                  WASD move, Shift sprint, Space jump/climb. F1–F12 also fire actions
                  in the game window.
                </span>
              </li>
            </ol>
          </section>

          <section className="rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
            <h2 className="text-2xl font-extrabold tracking-tight">Hook</h2>
            <p className="mt-2 text-base text-[var(--card-mute)]">
              Paste this into the bridge. Anyone with the URL can send gifts as
              you. Rotate it if it leaks.
            </p>
            <code className="mt-4 block rounded-[24px] bg-[var(--sand)] p-4 text-base break-all">
              {hook.url}
            </code>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <button
                type="button"
                className="h-14 rounded-full bg-[var(--card-ink)] text-base font-bold text-[var(--ink)]"
                onClick={async () => {
                  await navigator.clipboard.writeText(hook.url);
                  showToast("Copied hook URL");
                }}
              >
                Copy
              </button>
              <button
                type="button"
                disabled={busy}
                className="h-14 rounded-full bg-[var(--sand)] text-base font-bold disabled:opacity-50"
                onClick={() => void rotateHook()}
              >
                Rotate
              </button>
            </div>
          </section>

          <section className="rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
            <h2 className="text-2xl font-extrabold tracking-tight">Activity</h2>
            {log.length === 0 ? (
              <p className="mt-3 text-lg text-[var(--card-mute)]">Nothing yet.</p>
            ) : (
              <div className="mt-3 space-y-2">
                {log.map((l, i) => (
                  <p
                    key={`${l.t}-${i}`}
                    className="text-base text-[var(--card-mute)]"
                  >
                    {l.t} {l.text}
                  </p>
                ))}
              </div>
            )}
          </section>
          </div>
        </div>
      ) : (
        <div className="space-y-4 rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
          <label className="grid gap-2 text-base font-bold text-[var(--card-mute)]">
            Monster
            <select
              className="h-14 rounded-full bg-[var(--sand)] px-4 text-base font-bold text-[var(--card-ink)]"
              value={settings.monster}
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  monster: e.target.value as GameSettings["monster"],
                })
              }
            >
              <option value="stalker">Stalker</option>
              <option value="crawler">Crawler</option>
              <option value="beast">Water Beast</option>
              <option value="shadow">Shadow</option>
            </select>
          </label>
          <label className="grid gap-2 text-base font-bold text-[var(--card-mute)]">
            Parkour difficulty
            <select
              className="h-14 rounded-full bg-[var(--sand)] px-4 text-base font-bold text-[var(--card-ink)]"
              value={settings.diff}
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  diff: Number(e.target.value),
                })
              }
            >
              <option value={0}>Easy</option>
              <option value={1}>Normal</option>
              <option value={2}>Hard</option>
              <option value={3}>Nightmare</option>
            </select>
          </label>
          <label className="grid gap-2 text-base font-bold text-[var(--card-mute)]">
            Field of view:{" "}
            <b className="text-[var(--card-ink)]">{settings.fov}°</b>
            <input
              type="range"
              min={60}
              max={120}
              value={settings.fov}
              className="h-8 accent-[var(--orange)]"
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  fov: Number(e.target.value),
                })
              }
            />
          </label>
          <label className="grid gap-2 text-base font-bold text-[var(--card-mute)]">
            Push strength:{" "}
            <b className="text-[var(--card-ink)]">{settings.push}</b>
            <input
              type="range"
              min={6}
              max={24}
              value={settings.push}
              className="h-8 accent-[var(--orange)]"
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  push: Number(e.target.value),
                })
              }
            />
          </label>
          <label className="grid gap-2 text-base font-bold text-[var(--card-mute)]">
            Custom checkpoint amount (negative goes back)
            <input
              type="number"
              className="h-14 rounded-full bg-[var(--sand)] px-4 text-base font-bold text-[var(--card-ink)]"
              value={settings.custom}
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  custom: parseInt(e.target.value, 10) || 0,
                })
              }
            />
          </label>
        </div>
      )}

      {modal && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-[#163033]/45 p-3 sm:items-center">
          <div className="max-h-[88vh] w-full max-w-[480px] overflow-y-auto rounded-[32px] bg-[var(--card)] p-5 text-[var(--card-ink)]">
            <h2 className="text-3xl font-extrabold tracking-tight">
              {editing ? "Change gift" : "Add a gift"}
            </h2>
            <input
              type="text"
              placeholder="Search gifts (Rose, Galaxy, Lion…)"
              className="mt-4 h-14 w-full rounded-full bg-[var(--sand)] px-4 text-base"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              autoFocus
            />
            <div className="my-4 flex max-h-[240px] flex-wrap gap-2 overflow-y-auto">
              {filtered.map((g) => {
                const coins = formatGiftCoins(g.coins);
                return (
                  <button
                    key={g.name}
                    type="button"
                    className={`h-12 rounded-full px-4 text-base font-bold ${
                      selGift === g.name
                        ? "bg-[var(--card-ink)] text-[var(--ink)]"
                        : "bg-[var(--sand)]"
                    }`}
                    onClick={() => setSelGift(g.name)}
                  >
                    {g.emoji} {g.name}
                    {coins ? ` · ${coins}` : ""}
                  </button>
                );
              })}
            </div>
            <select
              className="h-14 w-full rounded-full bg-[var(--sand)] px-4 text-base font-bold"
              value={selAction}
              onChange={(e) => setSelAction(e.target.value)}
            >
              {actionOptions}
            </select>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <button
                type="button"
                className="h-14 rounded-full bg-[var(--sand)] text-base font-bold"
                onClick={() => setModal(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="h-14 rounded-full bg-[var(--card-ink)] text-base font-bold text-[var(--ink)]"
                onClick={commitGift}
              >
                {editing ? "Save" : "Add"}
              </button>
            </div>
          </div>
        </div>
      )}

      {toast && (
        <div className="fixed bottom-28 left-1/2 z-50 max-w-[90vw] -translate-x-1/2 rounded-full bg-[var(--card)] px-5 py-3 text-base font-bold text-[var(--card-ink)] shadow-[0_12px_30px_rgba(22,48,52,0.2)]">
          {toast}
        </div>
      )}
    </div>
  );
}
