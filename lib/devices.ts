import { createHash, randomBytes } from "crypto";
import { isDesktopGame } from "@/games/registry";
import { apiError } from "./errors";
import { prisma } from "./prisma";
import { accessDenial, accessError } from "./roles";

export const PAIR_TTL_MS = 5 * 60 * 1000;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function generatePairCode(): string {
  const bytes = randomBytes(8);
  let out = "";
  for (let i = 0; i < 8; i++) out += ALPHABET[bytes[i]! % ALPHABET.length];
  return out;
}

export function generateDeviceToken(): string {
  return `gh_${randomBytes(32).toString("base64url")}`;
}

export function hashDeviceToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function normalizeDeviceName(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const name = raw.trim();
  if (name.length < 1 || name.length > 40) return null;
  return name;
}

export function readBearer(req: Request): string | null {
  const header = req.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(\S+)\s*$/i.exec(header);
  return match ? match[1] : null;
}

export function assertDesktopSlug(slug: string) {
  if (!isDesktopGame(slug)) {
    return apiError(404, "not_found", "Unknown desktop game");
  }
  return null;
}

export async function requireDevice(req: Request, slug?: string) {
  const token = readBearer(req);
  if (!token) {
    return { error: apiError(401, "unauthorized", "Device token required") } as const;
  }
  const device = await prisma.device.findUnique({
    where: { tokenHash: hashDeviceToken(token) },
    include: { user: true },
  });
  if (!device || device.revokedAt) {
    return { error: apiError(401, "unauthorized", "Unknown device token") } as const;
  }
  if (slug && device.slug !== slug) {
    return {
      error: apiError(403, "forbidden", "Token is for a different game"),
    } as const;
  }
  const denial = accessDenial({
    role: device.user.role,
    active: device.user.active,
    accessUntil: device.user.accessUntil,
  });
  if (denial) {
    const err = accessError(denial);
    return { error: apiError(403, err.code, err.message) } as const;
  }
  return { device } as const;
}

export function toDeviceJson(device: {
  id: string;
  name: string;
  slug: string;
  lastStatus: string | null;
  lastScore: number | null;
  lastSeenAt: Date | null;
  createdAt: Date;
}) {
  return {
    id: device.id,
    name: device.name,
    slug: device.slug,
    lastStatus: device.lastStatus,
    lastScore: device.lastScore,
    lastSeenAt: device.lastSeenAt?.toISOString() ?? null,
    createdAt: device.createdAt.toISOString(),
  };
}
