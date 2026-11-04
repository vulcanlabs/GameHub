import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { requireActivePlayer } from "@/lib/session-guards";
import { PAIR_TTL_MS, assertDesktopSlug, generatePairCode } from "@/lib/devices";

export async function POST(req: NextRequest) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return apiError(422, "invalid_body", "JSON body required");
  }
  const slug = (body as { slug?: unknown }).slug;
  if (typeof slug !== "string") {
    return apiError(422, "invalid_body", "slug is required");
  }
  const unknown = assertDesktopSlug(slug);
  if (unknown) return unknown;

  const expiresAt = new Date(Date.now() + PAIR_TTL_MS);
  let code = generatePairCode();
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const row = await prisma.pairCode.create({
        data: { userId: gate.session.user.id, slug, code, expiresAt },
      });
      return NextResponse.json({
        code: row.code,
        slug: row.slug,
        expiresAt: row.expiresAt.toISOString(),
      });
    } catch {
      code = generatePairCode();
    }
  }
  return apiError(422, "invalid_body", "Could not mint a pair code");
}
