import { afterEach, describe, expect, it } from "vitest";
import { __resetLiveForTests, publishAction, takeLive } from "./live";

afterEach(() => {
  __resetLiveForTests();
});

describe("takeLive", () => {
  it("returns actions queued before the poll", async () => {
    publishAction("user-1", "pulse-beacon", {
      giftName: "Rose",
      action: "push_forward",
      repeatCount: 1,
    });
    const events = await takeLive("user-1", "pulse-beacon", 50);
    expect(events).toEqual([
      {
        type: "action",
        slug: "pulse-beacon",
        giftName: "Rose",
        action: "push_forward",
        repeatCount: 1,
      },
    ]);
  });

  it("resolves an empty list when nothing arrives", async () => {
    const events = await takeLive("user-1", "pulse-beacon", 30);
    expect(events).toEqual([]);
  });

  it("wakes a waiting poll", async () => {
    const pending = takeLive("user-1", "pulse-beacon", 1000);
    publishAction("user-1", "pulse-beacon", {
      giftName: "GG",
      action: "reset",
      repeatCount: 2,
    });
    const events = await pending;
    expect(events[0]).toMatchObject({ action: "reset", repeatCount: 2 });
  });
});
