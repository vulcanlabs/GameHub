import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireActivePlayer } from "@/lib/session-guards";
import { assertDesktopSlug, toDeviceJson } from "@/lib/devices";

export async function GET(req: NextRequest) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const slug = req.nextUrl.searchParams.get("slug") ?? "";
  const unknown = assertDesktopSlug(slug);
  if (unknown) return unknown;

  const devices = await prisma.device.findMany({
    where: { userId: gate.session.user.id, slug, revokedAt: null },
    orderBy: { createdAt: "desc" },
  });
  return NextResponse.json({ devices: devices.map(toDeviceJson) });
}
