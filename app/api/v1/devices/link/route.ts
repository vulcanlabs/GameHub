import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { accessDenial, accessError } from "@/lib/roles";
import {
  assertDesktopSlug,
  generateDeviceToken,
  hashDeviceToken,
  normalizeDeviceName,
} from "@/lib/devices";

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return apiError(422, "invalid_body", "JSON body required");
  }
  const raw = body as { code?: unknown; slug?: unknown; deviceName?: unknown };
  if (typeof raw.code !== "string" || typeof raw.slug !== "string") {
    return apiError(422, "invalid_body", "code and slug are required");
  }
  const slug = raw.slug;
  const unknown = assertDesktopSlug(slug);
  if (unknown) return unknown;
  const name = normalizeDeviceName(raw.deviceName);
  if (!name) {
    return apiError(422, "invalid_body", "deviceName must be 1–40 characters");
  }
  const code = raw.code.trim().toUpperCase();

  const pair = await prisma.pairCode.findUnique({
    where: { code },
    include: { user: true },
  });
  if (
    !pair ||
    pair.slug !== slug ||
    pair.usedAt ||
    pair.expiresAt.getTime() <= Date.now()
  ) {
    return apiError(401, "unauthorized", "Pair code is invalid or expired");
  }
  const denial = accessDenial({
    role: pair.user.role,
    active: pair.user.active,
    accessUntil: pair.user.accessUntil,
  });
  if (denial) {
    const err = accessError(denial);
    return apiError(403, err.code, err.message);
  }

  const token = generateDeviceToken();
  const device = await prisma.$transaction(async (tx) => {
    const claimed = await tx.pairCode.updateMany({
      where: { id: pair.id, usedAt: null },
      data: { usedAt: new Date() },
    });
    if (claimed.count !== 1) return null;
    return tx.device.create({
      data: {
        userId: pair.userId,
        slug,
        name,
        tokenHash: hashDeviceToken(token),
      },
    });
  });
  if (!device) {
    return apiError(401, "unauthorized", "Pair code is invalid or expired");
  }

  return NextResponse.json({
    token,
    deviceId: device.id,
    slug: device.slug,
  });
}
