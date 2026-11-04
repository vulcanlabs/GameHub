import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { parseGiftBody, processGiftForUser } from "@/lib/hooks";
import { asBindings, getOrCreateGameConfig } from "@/lib/game-config";
import { accessDenial, accessError } from "@/lib/roles";

const DEFAULT_SLUG = "dont-touch-the-water";

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ token: string }> },
) {
  const { token } = await ctx.params;
  const user = await prisma.user.findUnique({ where: { hookToken: token } });
  if (!user) {
    return apiError(401, "unauthorized", "Unknown hook token");
  }
  const denial = accessDenial({
    role: user.role,
    active: user.active,
    accessUntil: user.accessUntil,
  });
  if (denial) {
    const err = accessError(denial);
    return apiError(403, err.code, err.message);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return apiError(422, "invalid_body", "JSON body required");
  }

  const gift = parseGiftBody(body);
  if (!gift) {
    return apiError(422, "invalid_body", "giftName is required");
  }

  const slug =
    (typeof (body as { slug?: string }).slug === "string" &&
      (body as { slug: string }).slug) ||
    DEFAULT_SLUG;

  const config = await getOrCreateGameConfig(user.id, slug);
  if (!config) {
    return apiError(404, "not_found", "Unknown game");
  }

  const result = processGiftForUser({
    userId: user.id,
    slug,
    bindings: asBindings(config.bindings),
    gift,
  });

  if (!result.ok) {
    return NextResponse.json(
      { ignored: true as const, reason: result.reason },
      { status: 202 },
    );
  }

  return NextResponse.json(
    {
      giftName: result.giftName,
      action: result.action,
      repeatCount: result.repeatCount,
    },
    { status: 202 },
  );
}
