import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { generateHookToken, hookUrl } from "@/lib/hooks";
import { requireActivePlayer } from "@/lib/session-guards";

function originFrom(req: NextRequest): string {
  return process.env.AUTH_URL ?? req.nextUrl.origin;
}

export async function GET(req: NextRequest) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const user = await prisma.user.findUnique({
    where: { id: gate.session.user.id },
    select: { hookToken: true },
  });
  if (!user) {
    return apiError(401, "unauthorized", "Sign in required");
  }

  return NextResponse.json({
    token: user.hookToken,
    url: hookUrl(user.hookToken, originFrom(req)),
  });
}

export async function POST(req: NextRequest) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const token = generateHookToken();
  const user = await prisma.user.update({
    where: { id: gate.session.user.id },
    data: { hookToken: token },
    select: { hookToken: true },
  });

  return NextResponse.json({
    token: user.hookToken,
    url: hookUrl(user.hookToken, originFrom(req)),
  });
}
