import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { requireActivePlayer } from "@/lib/session-guards";

export async function DELETE(
  _req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const { id } = await ctx.params;
  const device = await prisma.device.findUnique({ where: { id } });
  if (!device || device.userId !== gate.session.user.id) {
    return apiError(404, "not_found", "Device not found");
  }
  if (!device.revokedAt) {
    await prisma.device.update({
      where: { id },
      data: { revokedAt: new Date() },
    });
  }
  return NextResponse.json({ revoked: true, id });
}
