import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PrismaClient } from "@prisma/client";
import { generateHookToken } from "./hooks";
import { DEFAULT_BINDINGS, DEFAULT_SETTINGS } from "./gifts";
import { __resetLiveForTests } from "./live";

const prisma = new PrismaClient();

describe("hook token lookup (contract)", () => {
  let token: string;
  let userId: string;

  beforeAll(async () => {
    __resetLiveForTests();
    token = generateHookToken();
    const user = await prisma.user.create({
      data: {
        email: `test-${Date.now()}@example.com`,
        name: "Hook Test",
        hookToken: token,
        gameConfigs: {
          create: {
            slug: "dont-touch-the-water",
            bindings: DEFAULT_BINDINGS,
            settings: DEFAULT_SETTINGS,
          },
        },
      },
    });
    userId = user.id;
  });

  afterAll(async () => {
    await prisma.gameConfig.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } }).catch(() => undefined);
    await prisma.$disconnect();
  });

  it("finds user by hook token", async () => {
    const user = await prisma.user.findUnique({ where: { hookToken: token } });
    expect(user?.id).toBe(userId);
  });

  it("unknown token returns null (API maps to 401)", async () => {
    const user = await prisma.user.findUnique({
      where: { hookToken: "not-a-real-token" },
    });
    expect(user).toBeNull();
  });
});
