import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { requireDevice } from "@/lib/devices";
import { takeLive } from "@/lib/live";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const HOLD_MS = 25_000;

export async function GET(req: NextRequest) {
  const slug = req.nextUrl.searchParams.get("slug") ?? "";
  if (!slug) return apiError(422, "invalid_body", "slug is required");

  const gate = await requireDevice(req, slug);
  if ("error" in gate) return gate.error;

  await prisma.device.update({
    where: { id: gate.device.id },
    data: { lastSeenAt: new Date() },
  });

  const events = await takeLive(gate.device.userId, slug, HOLD_MS, req.signal);
  if (req.signal.aborted) return new Response(null, { status: 204 });
  return NextResponse.json({ events });
}
