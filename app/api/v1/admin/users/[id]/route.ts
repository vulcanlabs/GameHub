import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { requireAdmin } from "@/lib/session-guards";
import { isAdminRole } from "@/lib/roles";

export async function PATCH(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const gate = await requireAdmin();
  if ("error" in gate) return gate.error;

  const { id } = await ctx.params;
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return apiError(422, "invalid_body", "JSON body required");
  }

  const active = (body as { active?: unknown }).active;
  if (typeof active !== "boolean") {
    return apiError(422, "invalid_body", "active boolean required");
  }

  const target = await prisma.user.findUnique({ where: { id } });
  if (!target) return apiError(404, "not_found", "User not found");

  if (isAdminRole(target.role) && active === false) {
    return apiError(422, "invalid_body", "Cannot deactivate an admin account");
  }

  if (target.id === gate.session.user.id && active === false) {
    return apiError(422, "invalid_body", "Cannot deactivate your own account");
  }

  const user = await prisma.user.update({
    where: { id },
    data: { active },
    select: {
      id: true,
      name: true,
      email: true,
      image: true,
      role: true,
      active: true,
      createdAt: true,
    },
  });

  return NextResponse.json({ user });
}

export async function DELETE(
  _req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const gate = await requireAdmin();
  if ("error" in gate) return gate.error;

  const { id } = await ctx.params;
  const target = await prisma.user.findUnique({ where: { id } });
  if (!target) return apiError(404, "not_found", "User not found");

  if (target.id === gate.session.user.id) {
    return apiError(422, "invalid_body", "Cannot delete your own account");
  }
  if (isAdminRole(target.role)) {
    return apiError(422, "invalid_body", "Cannot delete an admin account");
  }

  await prisma.user.delete({ where: { id } });
  return NextResponse.json({ deleted: true, id });
}

