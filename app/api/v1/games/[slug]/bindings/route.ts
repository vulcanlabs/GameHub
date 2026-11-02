import { NextRequest, NextResponse } from "next/server";
import { apiError } from "@/lib/errors";
import {
  asBindings,
  getOrCreateGameConfig,
  validateBindingsInput,
} from "@/lib/game-config";
import { prisma } from "@/lib/prisma";
import { getGame } from "@/games/registry";
import { requireActivePlayer } from "@/lib/session-guards";

export async function GET(
  _req: NextRequest,
  ctx: { params: Promise<{ slug: string }> },
) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const { slug } = await ctx.params;
  if (!getGame(slug)) return apiError(404, "not_found", "Unknown game");

  const config = await getOrCreateGameConfig(gate.session.user.id, slug);
  if (!config) return apiError(404, "not_found", "Unknown game");

  return NextResponse.json({
    slug,
    bindings: asBindings(config.bindings),
  });
}

export async function PUT(
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

  const bindings = validateBindingsInput(body);
  if (!bindings) {
    return apiError(422, "invalid_body", "Invalid bindings map");
  }

  await getOrCreateGameConfig(gate.session.user.id, slug);
  const config = await prisma.gameConfig.update({
    where: {
      userId_slug: { userId: gate.session.user.id, slug },
    },
    data: { bindings },
  });

  return NextResponse.json({
    slug,
    bindings: asBindings(config.bindings),
  });
}
