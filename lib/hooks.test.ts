import { afterEach, describe, expect, it } from "vitest";
import {
  isStreakPartial,
  parseGiftBody,
  processGiftForUser,
  resolveBinding,
} from "./hooks";
import { __resetLiveForTests, subscribeLive } from "./live";
import { DEFAULT_BINDINGS } from "./gifts";

afterEach(() => {
  __resetLiveForTests();
});

describe("parseGiftBody", () => {
  it("reads nested TikFinity envelope", () => {
    const g = parseGiftBody({
      event: "gift",
      data: { giftName: "Rose", repeatCount: 3, giftType: 1, repeatEnd: true },
    });
    expect(g).toMatchObject({ giftName: "Rose", repeatCount: 3 });
  });

  it("caps repeatCount at 10", () => {
    const g = parseGiftBody({ giftName: "Lion", repeatCount: 99 });
    expect(g?.repeatCount).toBe(10);
  });
});

describe("processGiftForUser", () => {
  it("ignores streak partials", () => {
    const gift = parseGiftBody({
      giftName: "Rose",
      giftType: 1,
      repeatEnd: false,
      repeatCount: 2,
    })!;
    expect(isStreakPartial(gift)).toBe(true);
    const r = processGiftForUser({
      userId: "u1",
      slug: "dont-touch-the-water",
      bindings: DEFAULT_BINDINGS,
      gift,
    });
    expect(r).toEqual({ ok: false, ignored: true, reason: "streak" });
  });

  it("returns unmapped for unknown gifts", () => {
    const r = processGiftForUser({
      userId: "u1",
      slug: "dont-touch-the-water",
      bindings: DEFAULT_BINDINGS,
      gift: { giftName: "NotARealGift", repeatCount: 1 },
    });
    expect(r).toEqual({ ok: false, ignored: true, reason: "unmapped" });
  });

  it("publishes a mapped gift and dedupes fingerprints", () => {
    const seen: unknown[] = [];
    subscribeLive("u1", "dont-touch-the-water", (e) => seen.push(e));

    const first = processGiftForUser({
      userId: "u1",
      slug: "dont-touch-the-water",
      bindings: DEFAULT_BINDINGS,
      gift: { giftName: "Rose", repeatCount: 1, giftId: "g1" },
    });
    expect(first).toMatchObject({
      ok: true,
      giftName: "Rose",
      action: "push_back",
    });
    expect(seen).toHaveLength(1);

    const dup = processGiftForUser({
      userId: "u1",
      slug: "dont-touch-the-water",
      bindings: DEFAULT_BINDINGS,
      gift: { giftName: "Rose", repeatCount: 1, giftId: "g1" },
    });
    expect(dup).toEqual({ ok: false, ignored: true, reason: "duplicate" });
    expect(seen).toHaveLength(1);
  });

  it("resolves bindings case-insensitively", () => {
    expect(resolveBinding(DEFAULT_BINDINGS, "rose")).toBe("push_back");
    expect(resolveBinding(DEFAULT_BINDINGS, "LION")).toBe("spawn_monster");
  });

  it("does not cross-match Love you and Love You", () => {
    const bindings = { "Love You": "up_5", "Love you": "push_back" };
    expect(resolveBinding(bindings, "Love You")).toBe("up_5");
    expect(resolveBinding(bindings, "Love you")).toBe("push_back");
    expect(resolveBinding(bindings, "love you")).toBeNull();
    expect(resolveBinding({ "Love You": "up_5" }, "Love you")).toBeNull();
  });
});
