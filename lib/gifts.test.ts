import { describe, expect, it } from "vitest";
import {
  GIFT_CATALOG,
  giftEmoji,
  normalizeBindingNames,
} from "./gifts";

describe("gift catalog", () => {
  it("matches the US TikTok names and coin prices", () => {
    const coins = Object.fromEntries(
      GIFT_CATALOG.map((g) => [g.name, g.coins]),
    );
    expect(coins["Hand Heart"]).toBe(100);
    expect(coins["Hand Hearts"]).toBeUndefined();
    expect(coins["Love you"]).toBe(1);
    expect(coins["Love You"]).toBe(199);
    expect(coins["Paper Crane"]).toBe(99);
    expect(coins["Little Crown"]).toBe(99);
    expect(coins["Fireworks"]).toBe(1088);
    expect(coins["Diamond"]).toBe(1099);
    expect(coins["Whale Diving"]).toBe(2150);
    expect(coins["Sports Car"]).toEqual([4999, 7000]);
    expect(coins["Interstellar"]).toBe(10000);
    expect(coins["Castle Fantasy"]).toBe(20000);
    expect(coins["Phoenix"]).toBe(25999);
    expect(coins["Dragon Flame"]).toBe(26999);
    expect(coins["TikTok Universe+"]).toBe(34999);
    expect(coins["TikTok Universe"]).toBe(44999);
    expect(coins.Universe).toBeUndefined();
    expect(coins.Dragon).toBeUndefined();
    expect(coins.Castle).toBeUndefined();
    expect(coins["Flower Heart"]).toBeUndefined();
    expect(coins.Yacht).toBeUndefined();
    expect(giftEmoji("Love you")).toBe("😘");
    expect(giftEmoji("Love You")).toBe("🤟");
  });

  it("rewrites retired gift names without clobbering the new key", () => {
    expect(
      normalizeBindingNames({
        "Hand Hearts": "up_5",
        Universe: "down_5",
        Dragon: "spawn_monster",
        Castle: "reset",
      }),
    ).toEqual({
      "Hand Heart": "up_5",
      "TikTok Universe+": "down_5",
      "Dragon Flame": "spawn_monster",
      "Castle Fantasy": "reset",
    });

    expect(
      normalizeBindingNames({
        Universe: "down_5",
        "TikTok Universe+": "push_forward",
      }),
    ).toEqual({ "TikTok Universe+": "push_forward" });
  });
});
