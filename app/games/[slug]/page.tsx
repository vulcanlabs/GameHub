import { notFound, redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import { getGame } from "@/games/registry";
import { HubShell } from "@/components/HubShell";
import { GameDashboard } from "@/components/GameDashboard";
import { PendingAccess } from "@/components/PendingAccess";
import {
  asBindings,
  asSettings,
  getOrCreateGameConfig,
} from "@/lib/game-config";
import { prisma } from "@/lib/prisma";
import { hookUrl } from "@/lib/hooks";
import { canAccessGames } from "@/lib/roles";

export default async function GamePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const session = await auth();
  if (!session?.user?.id) redirect("/login");
  if (
    !canAccessGames({
      role: session.user.role,
      active: session.user.active,
    })
  ) {
    return <PendingAccess />;
  }

  const { slug } = await params;
  const game = getGame(slug);
  if (!game) notFound();

  const config = await getOrCreateGameConfig(session.user.id, slug);
  if (!config) notFound();

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { hookToken: true },
  });
  if (!user) redirect("/login");

  return (
    <HubShell active={slug}>
      <GameDashboard
        game={game}
        initialBindings={asBindings(config.bindings)}
        initialSettings={asSettings(config.settings)}
        initialHook={{
          token: user.hookToken,
          url: hookUrl(user.hookToken),
        }}
      />
    </HubShell>
  );
}
