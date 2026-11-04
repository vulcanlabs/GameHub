import { auth } from "./auth";
import { apiError } from "./errors";
import { accessDenial, accessError, isAdminRole } from "./roles";

export async function requireSession() {
  const session = await auth();
  if (!session?.user?.id) {
    return { error: apiError(401, "unauthorized", "Sign in required") } as const;
  }
  return { session } as const;
}

export async function requireAdmin() {
  const result = await requireSession();
  if ("error" in result) return result;
  if (!isAdminRole(result.session.user.role)) {
    return {
      error: apiError(403, "forbidden", "Admin access required"),
    } as const;
  }
  return result;
}

export async function requireActivePlayer() {
  const result = await requireSession();
  if ("error" in result) return result;
  const denial = accessDenial({
    role: result.session.user.role,
    active: result.session.user.active,
    accessUntil: result.session.user.accessUntil,
  });
  if (denial) {
    const err = accessError(denial);
    return { error: apiError(403, err.code, err.message) } as const;
  }
  return result;
}
