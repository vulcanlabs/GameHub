/** Starting grass, and the value both resets return to. */
export const START_GRASS = 1_000_000;

/** Slider stops, in order. The control picks an index into this list. */
export const CUSTOM_STOPS = [
  1, 10, 50, 100, 250, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_000,
  250_000, 500_000, 1_000_000,
] as const;

export const DEFAULT_CUSTOM_INDEX = CUSTOM_STOPS.indexOf(1_000);

export const STORAGE_KEY = "gamehub:one-more-lawn:grass";

export function clampGrass(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.trunc(n));
}

/** 0 is a fully cut lawn. 1 is a full meadow. Counts above the start stay full. */
export function grassFullness(grass: number): number {
  return Math.min(1, Math.max(0, clampGrass(grass) / START_GRASS));
}

export function formatGrass(n: number): string {
  return clampGrass(n).toLocaleString("en-US");
}

/** Signed delta with thousands separators, such as +1,000 or -5,000. */
export function formatDelta(n: number): string {
  const value = Math.trunc(n);
  if (!Number.isFinite(value) || value === 0) return "0";
  const sign = value > 0 ? "+" : "-";
  return sign + Math.abs(value).toLocaleString("en-US");
}

export function applyGrassChange(
  current: number,
  delta: number,
): { grass: number; applied: number } {
  const base = clampGrass(current);
  const next = clampGrass(base + delta);
  return { grass: next, applied: next - base };
}

/**
 * Height scale for one clump.
 * `depth` is 0 beside the mower and 1 at the far tree line.
 * `phase` is a stable 0–1 roll for that clump, so cuts land in patches.
 * A full lawn keeps every clump at `height`. A cut clump is hidden (scale 0).
 */
export function tuftHeightScale(
  fullness: number,
  depth: number,
  phase: number,
  height: number,
): number {
  const f = Math.min(1, Math.max(0, fullness));
  const d = Math.min(1, Math.max(0, depth));
  const p = Math.min(1, Math.max(0, phase));
  const threshold = f * 1.05 - (1 - d) * (1 - f) * 0.55;
  if (p < threshold) return height;
  return 0;
}

export function readSavedGrass(raw: string | null): number | null {
  if (!raw) return null;
  try {
    const data = JSON.parse(raw) as unknown;
    if (typeof data === "number") return clampGrass(data);
    if (data && typeof data === "object" && "grass" in data) {
      const grass = (data as { grass: unknown }).grass;
      if (typeof grass === "number") return clampGrass(grass);
    }
  } catch {
    return null;
  }
  return null;
}

export function savedGrassPayload(grass: number): string {
  return JSON.stringify({ grass: clampGrass(grass) });
}
