export const ROLES = ["admin", "user"] as const;
export type Role = (typeof ROLES)[number];

/** Comma-separated emails in ADMIN_EMAILS, plus the workshop owner default. */
export function adminEmails(): string[] {
  const fromEnv = (process.env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  const defaults = ["etienne.landman@vulcanlabs.com"];
  return [...new Set([...defaults, ...fromEnv])];
}

export function isAdminEmail(email: string | null | undefined): boolean {
  if (!email) return false;
  return adminEmails().includes(email.trim().toLowerCase());
}

export function roleForEmail(email: string | null | undefined): Role {
  return isAdminEmail(email) ? "admin" : "user";
}

export function isAdminRole(role: string | null | undefined): boolean {
  return role === "admin";
}

export type AccessInput = {
  role: string | null | undefined;
  active: boolean | null | undefined;
  accessUntil?: Date | string | null;
};

export type AccessDenial = "inactive" | "expired";

export function accessEndsAtMs(
  value: Date | string | null | undefined,
): number | null {
  if (value == null) return null;
  const ms = value instanceof Date ? value.getTime() : new Date(value).getTime();
  return Number.isNaN(ms) ? null : ms;
}

/** Admins always pass. Others need active plus a future accessUntil. */
export function accessDenial(opts: AccessInput, now = Date.now()): AccessDenial | null {
  if (isAdminRole(opts.role)) return null;
  if (!opts.active) return "inactive";
  const ends = accessEndsAtMs(opts.accessUntil);
  if (ends == null || ends <= now) return "expired";
  return null;
}

export function accessError(denial: AccessDenial): { code: AccessDenial; message: string } {
  if (denial === "expired") {
    return {
      code: "expired",
      message: "Access period has ended. Ask an admin to extend it.",
    };
  }
  return {
    code: "inactive",
    message: "Account is not active. Wait for an admin to activate you.",
  };
}

export function canAccessGames(opts: AccessInput, now = Date.now()): boolean {
  return accessDenial(opts, now) === null;
}
