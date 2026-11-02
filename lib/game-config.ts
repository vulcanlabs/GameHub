import { prisma } from "./prisma";
import {
  DEFAULT_BINDINGS,
  DEFAULT_SETTINGS,
  isAction,
  type GameSettings,
} from "./gifts";
import { getGame } from "@/games/registry";

export async function getOrCreateGameConfig(userId: string, slug: string) {
  if (!getGame(slug)) return null;

  const existing = await prisma.gameConfig.findUnique({
    where: { userId_slug: { userId, slug } },
  });
  if (existing) return existing;

  return prisma.gameConfig.create({
    data: {
      userId,
      slug,
      bindings: DEFAULT_BINDINGS,
      settings: DEFAULT_SETTINGS,
    },
  });
}

export function asBindings(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return { ...DEFAULT_BINDINGS };
  }
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    if (typeof v === "string" && isAction(v)) out[k] = v;
  }
  return out;
}

export function asSettings(value: unknown): GameSettings {
  const raw = (value && typeof value === "object" ? value : {}) as Record<
    string,
    unknown
  >;
  const monsters = ["stalker", "crawler", "beast", "shadow"] as const;
  const monster = monsters.includes(raw.monster as (typeof monsters)[number])
    ? (raw.monster as GameSettings["monster"])
    : DEFAULT_SETTINGS.monster;
  const diff = clampInt(raw.diff, 0, 3, DEFAULT_SETTINGS.diff);
  const fov = clampInt(raw.fov, 60, 120, DEFAULT_SETTINGS.fov);
  const push = clampInt(raw.push, 6, 24, DEFAULT_SETTINGS.push);
  const custom =
    typeof raw.custom === "number" && Number.isFinite(raw.custom)
      ? Math.trunc(raw.custom)
      : DEFAULT_SETTINGS.custom;
  return { monster, diff, fov, push, custom };
}

function clampInt(
  v: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

export function validateBindingsInput(
  body: unknown,
): Record<string, string> | null {
  if (!body || typeof body !== "object") return null;
  const bindings = (body as { bindings?: unknown }).bindings;
  if (!bindings || typeof bindings !== "object" || Array.isArray(bindings)) {
    return null;
  }
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(bindings as Record<string, unknown>)) {
    if (typeof k !== "string" || !k.trim()) return null;
    if (typeof v !== "string" || !isAction(v)) return null;
    out[k.trim()] = v;
  }
  return out;
}

export function validateSettingsInput(body: unknown): GameSettings | null {
  if (!body || typeof body !== "object") return null;
  const s = asSettings(body);
  const raw = body as Record<string, unknown>;
  if (raw.monster == null || raw.diff == null || raw.fov == null) return null;
  if (raw.push == null || raw.custom == null) return null;
  return s;
}
