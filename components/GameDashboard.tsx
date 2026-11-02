"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { GameMeta } from "@/games/registry";
import {
  ACTIONS,
  GIFT_CATALOG,
  giftEmoji,
  type GameSettings,
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
    const list = GIFT_CATALOG.filter((g) =>
      g.name.toLowerCase().includes(q),
    );
    if (q && !list.some((g) => g.name.toLowerCase() === q)) {
      return [...list, { name: search.trim(), emoji: "➕", coins: undefined }];
    }
    return list;
  }, [search]);

  const actionOptions = Object.entries(ACTIONS).map(([k, v]) => (
    <option key={k} value={k}>
      {v.label}
    </option>
  ));

  return (
    <div className="mx-auto max-w-[1100px] px-8 py-8 pb-16">
      <div className="mb-5 flex flex-wrap items-center gap-5">
        <div className="flex h-24 w-24 items-center justify-center rounded-[18px] border border-[var(--line)] bg-gradient-to-br from-[#3b6b73] to-[#0b1b1f] text-4xl">
          {game.emoji}
        </div>
        <div>
          <h1 className="text-3xl font-bold">{game.title}</h1>
          <div className="mt-2 flex gap-1.5">
            <button
              type="button"
              className={`rounded-lg bg-[var(--field)] px-3 py-2 text-xs font-semibold tracking-wide ${
                tab === "ov" ? "shadow-[inset_0_-2px_var(--acc)]" : ""
              }`}
              onClick={() => setTab("ov")}
            >
              OVERVIEW
            </button>
            <button
              type="button"
              className={`rounded-lg bg-[var(--field)] px-3 py-2 text-xs font-semibold tracking-wide ${
                tab === "st" ? "shadow-[inset_0_-2px_var(--acc)]" : ""
              }`}
              onClick={() => setTab("st")}
            >
              SETTINGS
            </button>
          </div>
        </div>
        <button
          type="button"
          onClick={play}
          className="rounded-full bg-white px-8 py-3 text-base font-bold text-[#111] shadow-[0_0_30px_#5ad1e655]"
        >
          Play
        </button>
        <div className="ml-auto grid grid-cols-2 gap-x-6 gap-y-1 text-xs">
          <div>
            <small className="block tracking-wide text-[var(--mute)]">
              GAME
            </small>
            {game.genre}
          </div>
          <div>
            <small className="block tracking-wide text-[var(--mute)]">
              SET UP
            </small>
            {Object.keys(bindings).length} gifts
          </div>
          <div>
            <small className="block tracking-wide text-[var(--mute)]">
              VERSION
            </small>
            {game.version}
          </div>
          <div>
            <small className="block tracking-wide text-[var(--mute)]">
              HOOK
            </small>
            Ready
          </div>
        </div>
      </div>

      {tab === "ov" ? (
        <div className="grid gap-4 lg:grid-cols-[1.6fr_1fr]">
          <div className="rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4">
            <div className="mb-3 flex items-start justify-between gap-3">
              <div>
                <h2 className="text-base font-semibold">Gifts &amp; events</h2>
                <p className="mt-1 text-sm text-[var(--mute)]">
                  Pick what each gift does. Test while the game window is open.
                </p>
              </div>
              <button
                type="button"
                className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-3 py-2"
                onClick={() => {
                  setSelGift(null);
                  setSearch("");
                  setSelAction("push_back");
                  setModal(true);
                }}
              >
                Add
              </button>
            </div>
            {Object.keys(bindings).length === 0 && (
              <p className="text-[var(--mute)]">No gifts yet. Press Add.</p>
            )}
            {Object.entries(bindings).map(([name, action]) => (
              <div
                key={name}
                className="grid grid-cols-[44px_1fr_170px_38px_38px] items-center gap-2.5 border-t border-[var(--line)] py-3"
              >
                <div className="flex h-[42px] w-[42px] items-center justify-center rounded-[10px] bg-[var(--field)] text-xl">
                  {giftEmoji(name)}
                </div>
                <div>
                  <b>{name}</b>
                  <p className="m-0 text-xs text-[var(--mute)]">
                    {ACTIONS[action]?.label}, {ACTIONS[action]?.description}
                  </p>
                </div>
                <select
                  className="w-full rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-2 text-xs font-semibold"
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
                  title="Test"
                  className="h-9 w-[38px] rounded-lg border border-[var(--line)] bg-[var(--field)]"
                  onClick={() => void testGift(name)}
                >
                  ▶
                </button>
                <button
                  type="button"
                  title="Remove"
                  className="h-9 w-[38px] rounded-lg border border-[var(--line)] bg-[var(--field)]"
                  onClick={() => {
                    const next = { ...bindings };
                    delete next[name];
                    void saveBindings(next);
                  }}
                >
                  ⌫
                </button>
              </div>
            ))}
          </div>

          <div className="space-y-3.5">
            <div className="rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4">
              <div className="mb-2 flex items-center justify-between">
                <h2 className="text-base font-semibold">Status</h2>
                <span className="rounded-full bg-[#14333a] px-2.5 py-0.5 text-xs text-[var(--acc)]">
                  Ready
                </span>
              </div>
              <div className="text-xl font-bold">Ready to play</div>
              <p className="text-sm text-[var(--mute)]">
                Gifts from your LIVE trigger the actions you set here.
              </p>
              <ol className="mt-3 space-y-2 text-sm">
                <li className="flex gap-2">
                  <b className="flex h-6 w-6 flex-none items-center justify-center rounded-full border border-[var(--line)] text-xs">
                    1
                  </b>
                  <span>
                    Press Play. The game opens in its own window. Click inside
                    it to start.
                  </span>
                </li>
                <li className="flex gap-2">
                  <b className="flex h-6 w-6 flex-none items-center justify-center rounded-full border border-[var(--line)] text-xs">
                    2
                  </b>
                  <span>
                    Run the TikFinity bridge with your hook URL (below). Keep
                    this hub open.
                  </span>
                </li>
                <li className="flex gap-2">
                  <b className="flex h-6 w-6 flex-none items-center justify-center rounded-full border border-[var(--line)] text-xs">
                    3
                  </b>
                  <span>
                    WASD move, Shift sprint, Space jump/climb. F1–F12 also fire
                    actions in the game window.
                  </span>
                </li>
              </ol>
            </div>

            <div className="rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4">
              <h2 className="mb-2 text-base font-semibold">Your TikFinity hook</h2>
              <p className="mb-2 text-sm text-[var(--mute)]">
                Paste this into the bridge. Anyone with the URL can send gifts
                as you — rotate if it leaks.
              </p>
              <code className="block break-all rounded-lg bg-[var(--field)] p-2 text-xs">
                {hook.url}
              </code>
              <div className="mt-2 flex gap-2">
                <button
                  type="button"
                  className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-3 py-2"
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
                  className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-3 py-2"
                  onClick={() => void rotateHook()}
                >
                  Rotate
                </button>
              </div>
            </div>

            <div className="rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4">
              <h2 className="mb-2 text-base font-semibold">Activity</h2>
              {log.length === 0 ? (
                <div className="text-xs text-[var(--mute)]">Nothing yet.</div>
              ) : (
                log.map((l, i) => (
                  <div key={`${l.t}-${i}`} className="text-xs text-[var(--mute)]">
                    {l.t} {l.text}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      ) : (
        <div className="max-w-md space-y-3.5 rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4">
          <label className="grid gap-1.5 text-sm text-[var(--mute)]">
            Monster
            <select
              className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-2 font-semibold text-[var(--ink)]"
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
          <label className="grid gap-1.5 text-sm text-[var(--mute)]">
            Parkour difficulty
            <select
              className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-2 font-semibold text-[var(--ink)]"
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
          <label className="grid gap-1.5 text-sm text-[var(--mute)]">
            Field of view: <b className="text-[var(--ink)]">{settings.fov}°</b>
            <input
              type="range"
              min={60}
              max={120}
              value={settings.fov}
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  fov: Number(e.target.value),
                })
              }
            />
          </label>
          <label className="grid gap-1.5 text-sm text-[var(--mute)]">
            Push strength:{" "}
            <b className="text-[var(--ink)]">{settings.push}</b>
            <input
              type="range"
              min={6}
              max={24}
              value={settings.push}
              onChange={(e) =>
                void saveSettings({
                  ...settings,
                  push: Number(e.target.value),
                })
              }
            />
          </label>
          <label className="grid gap-1.5 text-sm text-[var(--mute)]">
            Custom checkpoint amount (negative goes back)
            <input
              type="number"
              className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-2 font-semibold text-[var(--ink)]"
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
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="w-[min(480px,92vw)] rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-4">
            <h2 className="text-base font-semibold">Add a gift</h2>
            <input
              type="text"
              placeholder="Search gifts (Rose, Galaxy, Lion…)"
              className="mt-2.5 w-full rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-2"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              autoFocus
            />
            <div className="my-2.5 flex max-h-[210px] flex-wrap gap-1.5 overflow-y-auto">
              {filtered.map((g) => (
                <button
                  key={g.name}
                  type="button"
                  className={`rounded-lg border px-2.5 py-1.5 text-sm ${
                    selGift === g.name
                      ? "border-[var(--acc)] bg-[#14333a]"
                      : "border-[var(--line)] bg-[var(--field)]"
                  }`}
                  onClick={() => setSelGift(g.name)}
                >
                  {g.emoji} {g.name}
                  {g.coins != null ? ` · ${g.coins}` : ""}
                </button>
              ))}
            </div>
            <select
              className="w-full rounded-lg border border-[var(--line)] bg-[var(--field)] px-2 py-2"
              value={selAction}
              onChange={(e) => setSelAction(e.target.value)}
            >
              {actionOptions}
            </select>
            <div className="mt-3 flex justify-end gap-2">
              <button
                type="button"
                className="rounded-lg border border-[var(--line)] bg-[var(--field)] px-3 py-2"
                onClick={() => setModal(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="rounded-lg border border-[var(--acc)] bg-[var(--acc)] px-3 py-2 font-bold text-[#05181c]"
                onClick={() => {
                  if (!selGift) {
                    showToast("Pick a gift first");
                    return;
                  }
                  void saveBindings({ ...bindings, [selGift]: selAction });
                  setModal(false);
                }}
              >
                Add
              </button>
            </div>
          </div>
        </div>
      )}

      {toast && (
        <div className="fixed bottom-5 left-1/2 z-50 -translate-x-1/2 rounded-[10px] bg-white px-4 py-2 font-semibold text-[#111]">
          {toast}
        </div>
      )}
    </div>
  );
}
