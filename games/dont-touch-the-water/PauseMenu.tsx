"use client";

import type { GameSettings, MonsterType } from "./types";

type Props = {
  settings: GameSettings;
  onChange: (s: GameSettings) => void;
  onResume: () => void;
};

export function PauseMenu({ settings, onChange, onResume }: Props) {
  return (
    <aside
      className="flex w-80 flex-none flex-col gap-3 overflow-y-auto border-l border-[#2a2d36] bg-[#17191f] p-4 text-[#e8e6df]"
      onClick={(e) => e.stopPropagation()}
    >
      <h1 className="text-base font-semibold">Paused</h1>
      <p className="text-xs text-[#8d909a]">
        Esc releases the mouse. Change settings here — they save to your account.
      </p>
      <button
        type="button"
        className="rounded-md border border-[#e0b84a] bg-[#e0b84a] px-3 py-2 text-sm font-semibold text-[#111]"
        onClick={onResume}
      >
        Resume
      </button>

      <h2 className="mt-2 text-xs font-semibold uppercase tracking-wider text-[#8d909a]">
        Game settings
      </h2>

      <label className="grid gap-1 text-sm text-[#8d909a]">
        Monster
        <select
          className="rounded-md border border-[#2a2d36] bg-[#1f222a] px-2 py-1.5 text-[#e8e6df]"
          value={settings.monster}
          onChange={(e) =>
            onChange({
              ...settings,
              monster: e.target.value as MonsterType,
            })
          }
        >
          <option value="stalker">Stalker</option>
          <option value="crawler">Crawler</option>
          <option value="beast">Water Beast</option>
          <option value="shadow">Shadow</option>
        </select>
      </label>

      <label className="grid gap-1 text-sm text-[#8d909a]">
        Parkour difficulty
        <select
          className="rounded-md border border-[#2a2d36] bg-[#1f222a] px-2 py-1.5 text-[#e8e6df]"
          value={settings.diff}
          onChange={(e) =>
            onChange({ ...settings, diff: Number(e.target.value) })
          }
        >
          <option value={0}>Easy</option>
          <option value={1}>Normal</option>
          <option value={2}>Hard</option>
          <option value={3}>Nightmare</option>
        </select>
      </label>

      <label className="grid gap-1 text-sm text-[#8d909a]">
        Field of view: {settings.fov}°
        <input
          type="range"
          min={60}
          max={120}
          value={settings.fov}
          onChange={(e) =>
            onChange({ ...settings, fov: Number(e.target.value) })
          }
        />
      </label>

      <label className="grid gap-1 text-sm text-[#8d909a]">
        Push strength: {settings.push}
        <input
          type="range"
          min={6}
          max={24}
          value={settings.push}
          onChange={(e) =>
            onChange({ ...settings, push: Number(e.target.value) })
          }
        />
      </label>

      <label className="grid gap-1 text-sm text-[#8d909a]">
        Custom checkpoint amount
        <input
          type="number"
          className="rounded-md border border-[#2a2d36] bg-[#1f222a] px-2 py-1.5 text-[#e8e6df]"
          value={settings.custom}
          onChange={(e) =>
            onChange({
              ...settings,
              custom: parseInt(e.target.value, 10) || 0,
            })
          }
        />
      </label>

      <h2 className="mt-2 text-xs font-semibold uppercase tracking-wider text-[#8d909a]">
        Actions
      </h2>
      <p className="text-xs text-[#8d909a]">
        F1 Spawn · F2 Crow · F3/F4 ±1 CP · F6/F7 ±5 CP · F8 Custom · F9 Reset ·
        F10/F11 Push · F12 Push into water
      </p>
    </aside>
  );
}
