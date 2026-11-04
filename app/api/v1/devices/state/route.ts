import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { requireDevice } from "@/lib/devices";

const STATUSES = new Set(["ready", "paused"]);

export async function POST(req: NextRequest) {
  let body: unknown = {};
  const text = await req.text();
  if (text.trim()) {
    try {
      body = JSON.parse(text);
    } catch {
      return apiError(422, "invalid_body", "JSON body required");
    }
  }
  const raw = body as { slug?: unknown; status?: unknown; score?: unknown };
  const slug = typeof raw.slug === "string" ? raw.slug : undefined;
  const gate = await requireDevice(req, slug);
  if ("error" in gate) return gate.error;

  let status: string | undefined;
  if (raw.status !== undefined) {
    if (typeof raw.status !== "string" || !STATUSES.has(raw.status)) {
      return apiError(422, "invalid_body", "status must be ready or paused");
    }
    status = raw.status;
  }
  let score: number | undefined;
  if (raw.score !== undefined) {
    if (typeof raw.score !== "number" || !Number.isFinite(raw.score)) {
      return apiError(422, "invalid_body", "score must be a finite number");
    }
    score = raw.score;
  }

  const seen = new Date();
  const device = await prisma.device.update({
    where: { id: gate.device.id },
    data: {
      lastSeenAt: seen,
      ...(status === undefined ? {} : { lastStatus: status }),
      ...(score === undefined ? {} : { lastScore: score }),
    },
  });

  return NextResponse.json({
    ok: true,
    lastSeenAt: device.lastSeenAt?.toISOString() ?? seen.toISOString(),
  });
}
