import { describe, expect, it } from "vitest";
import { generatePairCode, hashDeviceToken, normalizeDeviceName } from "./devices";

describe("device helpers", () => {
  it("mints an 8-character pair code", () => {
    const code = generatePairCode();
    expect(code).toMatch(/^[A-Z2-9]{8}$/);
    expect(code).not.toMatch(/[01IO]/);
  });

  it("hashes tokens stably", () => {
    expect(hashDeviceToken("gh_abc")).toBe(hashDeviceToken("gh_abc"));
    expect(hashDeviceToken("gh_abc")).not.toBe(hashDeviceToken("gh_abd"));
  });

  it("rejects blank or long device names", () => {
    expect(normalizeDeviceName("  Booth PC  ")).toBe("Booth PC");
    expect(normalizeDeviceName("")).toBeNull();
    expect(normalizeDeviceName("x".repeat(41))).toBeNull();
    expect(normalizeDeviceName(12)).toBeNull();
  });
});
