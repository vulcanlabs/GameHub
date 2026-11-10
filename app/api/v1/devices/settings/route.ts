import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { apiError } from "@/lib/errors";
import { assertDesktopSlug, requireDevice } from "@/lib/devices";
import {
  asSettings,
  getOrCreateGameConfig,
  validateSettingsInput,
} from "@/lib/game-config";

async function settingsFor(req: NextRequest) {
  const slug = req.nextUrl.searchParams.get("slug") ?? "";
  if (!slug) return { error: apiError(422, "invalid_body", "slug is required") } as const;
  const unknown = assertDesktopSlug(slug);
  if (unknown) return { error: unknown } as const;
  const gate = await requireDevice(req, slug);
  if ("error" in gate) return { error: gate.error } as const;
  const config = await getOrCreateGameConfig(gate.device.userId, slug);
  if (!config) return { error: apiError(404, "not_found", "Unknown game") } as const;
  return { slug, config } as const;
}

export async function GET(req: NextRequest) {
  const found = await settingsFor(req);
  if ("error" in found) return found.error;
  return NextResponse.json({
    slug: found.slug,
    settings: asSettings(found.slug, found.config.settings),
  });
}

export async function PUT(req: NextRequest) {
  const found = await settingsFor(req);
  if ("error" in found) return found.error;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return apiError(422, "invalid_body", "JSON body required");
  }
  const settings = validateSettingsInput(found.slug, body);
  if (!settings) return apiError(422, "invalid_body", "Invalid settings");

  const config = await prisma.gameConfig.update({
    where: { userId_slug: { userId: found.config.userId, slug: found.slug } },
    data: { settings },
  });
  return NextResponse.json({
    slug: found.slug,
    settings: asSettings(found.slug, config.settings),
  });
}
