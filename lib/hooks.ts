import { randomBytes } from "crypto";
import { ACTIONS } from "./gifts";
import { fingerprintSeen, publishAction } from "./live";

export function generateHookToken(): string {
  return randomBytes(24).toString("base64url");
}

export function hookUrl(token: string, origin?: string): string {
  const base = origin ?? process.env.AUTH_URL ?? "http://localhost:3000";
  return `${base.replace(/\/$/, "")}/api/v1/hooks/${token}/events`;
}

export type ParsedGift = {
  giftName: string;
  repeatCount: number;
  giftType?: number;
  repeatEnd?: boolean;
  coins?: number;
  giftId?: string;
};

export function parseGiftBody(body: unknown): ParsedGift | null {
  if (!body || typeof body !== "object") return null;
  const raw = body as Record<string, unknown>;
  const data =
    raw.data && typeof raw.data === "object"
      ? (raw.data as Record<string, unknown>)
      : raw;

  const giftName = String(data.giftName ?? "").trim();
  if (!giftName) return null;

  const repeatCount = Math.min(
    10,
    Math.max(1, Number(data.repeatCount) || 1),
  );

  return {
    giftName,
    repeatCount,
    giftType: data.giftType != null ? Number(data.giftType) : undefined,
    repeatEnd:
      data.repeatEnd != null ? Boolean(data.repeatEnd) : undefined,
    coins: data.coins != null ? Number(data.coins) : undefined,
    giftId: data.giftId != null ? String(data.giftId) : undefined,
  };
}

export function isStreakPartial(gift: ParsedGift): boolean {
  return gift.giftType === 1 && gift.repeatEnd === false;
}

export function resolveBinding(
  bindings: Record<string, string>,
  giftName: string,
): string | null {
  const key = Object.keys(bindings).find(
    (g) => g.toLowerCase() === giftName.toLowerCase(),
  );
  if (!key) return null;
  const action = bindings[key];
  return action && action in ACTIONS ? action : null;
}

export type ProcessResult =
  | { ok: true; giftName: string; action: string; repeatCount: number }
  | { ok: false; ignored: true; reason: "streak" | "unmapped" | "duplicate" };

export function processGiftForUser(opts: {
  userId: string;
  slug: string;
  bindings: Record<string, string>;
  gift: ParsedGift;
  fingerprintExtra?: string;
}): ProcessResult {
  const { userId, slug, bindings, gift } = opts;

  if (isStreakPartial(gift)) {
    return { ok: false, ignored: true, reason: "streak" };
  }

  const fp = [
    userId,
    slug,
    gift.giftId ?? gift.giftName,
    gift.repeatCount,
    gift.repeatEnd ?? "",
    opts.fingerprintExtra ?? "",
  ].join("|");

  if (fingerprintSeen(fp)) {
    return { ok: false, ignored: true, reason: "duplicate" };
  }

  const action = resolveBinding(bindings, gift.giftName);
  if (!action) {
    return { ok: false, ignored: true, reason: "unmapped" };
  }

  const repeatCount = gift.repeatCount;
  publishAction(userId, slug, {
    giftName: gift.giftName,
    action,
    repeatCount,
    label: ACTIONS[action]?.label,
  });

  return { ok: true, giftName: gift.giftName, action, repeatCount };
}
