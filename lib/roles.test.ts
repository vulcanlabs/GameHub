import { describe, expect, it } from "vitest";
import {
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
    expect(canAccessGames({ role: "admin", active: false })).toBe(true);
    expect(canAccessGames({ role: "user", active: false })).toBe(false);
    expect(canAccessGames({ role: "user", active: true })).toBe(true);
  });
});
