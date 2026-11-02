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

/** Admins always count as active for game access. */
export function canAccessGames(opts: {
  role: string | null | undefined;
  active: boolean | null | undefined;
}): boolean {
  if (isAdminRole(opts.role)) return true;
  return Boolean(opts.active);
}
