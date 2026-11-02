import { NextRequest, NextResponse } from "next/server";
import { apiError } from "@/lib/errors";
import { getGame } from "@/games/registry";
import { asBindings, getOrCreateGameConfig } from "@/lib/game-config";
import { processGiftForUser } from "@/lib/hooks";
import { requireActivePlayer } from "@/lib/session-guards";

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ slug: string }> },
) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const { slug } = await ctx.params;
  if (!getGame(slug)) return apiError(404, "not_found", "Unknown game");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return apiError(422, "invalid_body", "JSON body required");
  }

  const giftName = String(
    (body as { giftName?: unknown }).giftName ?? "",
  ).trim();
  if (!giftName) {
    return apiError(422, "invalid_body", "giftName is required");
  }
  const repeatCount = Math.min(
    10,
    Math.max(1, Number((body as { repeatCount?: unknown }).repeatCount) || 1),
  );

  const config = await getOrCreateGameConfig(gate.session.user.id, slug);
  if (!config) return apiError(404, "not_found", "Unknown game");

  const result = processGiftForUser({
    userId: gate.session.user.id,
    slug,
    bindings: asBindings(config.bindings),
    gift: { giftName, repeatCount },
    fingerprintExtra: `test-${Date.now()}`,
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
