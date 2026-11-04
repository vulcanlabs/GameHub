import { describe, expect, it } from "vitest";
import {
  accessDenial,
  canAccessGames,
  isAdminEmail,
  roleForEmail,
} from "./roles";

describe("roles", () => {
  it("treats owner email as admin", () => {
    expect(isAdminEmail("etienne.landman@vulcanlabs.com")).toBe(true);
    expect(isAdminEmail("Etienne.Landman@vulcanlabs.com")).toBe(true);
    expect(roleForEmail("etienne.landman@vulcanlabs.com")).toBe("admin");
  });

  it("defaults others to user", () => {
    expect(roleForEmail("someone@example.com")).toBe("user");
  });

  it("admins can access games even when active is false", () => {
    expect(canAccessGames({ role: "admin", active: false, accessUntil: null })).toBe(
      true,
    );
    expect(canAccessGames({ role: "user", active: false, accessUntil: null })).toBe(
      false,
    );
    const future = new Date(Date.now() + 86_400_000).toISOString();
    expect(canAccessGames({ role: "user", active: true, accessUntil: future })).toBe(
      true,
    );
  });

  it("requires a future accessUntil for normal users", () => {
    const past = new Date(Date.now() - 1000).toISOString();
    expect(canAccessGames({ role: "user", active: true, accessUntil: null })).toBe(
      false,
    );
    expect(canAccessGames({ role: "user", active: true, accessUntil: past })).toBe(
      false,
    );
    expect(
      accessDenial({ role: "user", active: true, accessUntil: past }),
    ).toBe("expired");
    expect(
      accessDenial({ role: "user", active: false, accessUntil: past }),
    ).toBe("inactive");
  });
});
