import { describe, expect, it } from "vitest";
import {
  CUSTOM_STOPS,
  START_GRASS,
  applyGrassChange,
  formatDelta,
  formatGrass,
  grassFullness,
  readSavedGrass,
  savedGrassPayload,
  tuftHeightScale,
} from "./counter";

describe("one more lawn counter", () => {
  it("formats the live count and the flashed delta", () => {
    expect(formatGrass(691854)).toBe("691,854");
    expect(formatGrass(START_GRASS)).toBe("1,000,000");
    expect(formatDelta(-5000)).toBe("-5,000");
    expect(formatDelta(1000)).toBe("+1,000");
  });

  it("never goes below zero and reports the applied delta", () => {
    expect(applyGrassChange(1000, -5000)).toEqual({ grass: 0, applied: -1000 });
    expect(applyGrassChange(0, -1)).toEqual({ grass: 0, applied: 0 });
    expect(applyGrassChange(990000, 10000)).toEqual({
      grass: 1_000_000,
      applied: 10_000,
    });
  });

  it("resets by applying the difference back to the start", () => {
    const current = 691_854;
    expect(applyGrassChange(current, START_GRASS - current)).toEqual({
      grass: START_GRASS,
      applied: START_GRASS - current,
    });
  });

  it("uses the custom stops in order", () => {
    expect(CUSTOM_STOPS).toEqual([
      1, 10, 50, 100, 250, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000,
      100_000, 250_000, 500_000, 1_000_000,
    ]);
  });

  it("cuts near clumps before far ones", () => {
    expect(tuftHeightScale(1, 0, 0.99, 1.2)).toBe(1.2);
    expect(tuftHeightScale(0, 1, 0, 1.2)).toBe(0);
    expect(tuftHeightScale(0.5, 1, 0.4, 1)).toBe(1);
    expect(tuftHeightScale(0.5, 0, 0.4, 1)).toBe(0);
    expect(grassFullness(0)).toBe(0);
    expect(grassFullness(START_GRASS)).toBe(1);
    expect(grassFullness(START_GRASS * 2)).toBe(1);
  });

  it("round-trips a save without treating a reset as a save", () => {
    expect(readSavedGrass(null)).toBeNull();
    expect(readSavedGrass("nope")).toBeNull();
    const raw = savedGrassPayload(250_000);
    expect(readSavedGrass(raw)).toBe(250_000);
    expect(readSavedGrass(savedGrassPayload(-20))).toBe(0);
  });
});
