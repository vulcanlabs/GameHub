import { notFound, redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import { getGame } from "@/games/registry";
import { asSettings, getOrCreateGameConfig } from "@/lib/game-config";
import { GameCanvas } from "@/games/dont-touch-the-water";
import { canAccessGames } from "@/lib/roles";

export default async function PlayPage({
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
    redirect("/");
  }

  const { slug } = await params;
  const game = getGame(slug);
  if (!game) notFound();

  const config = await getOrCreateGameConfig(session.user.id, slug);
  if (!config) notFound();

  if (slug !== "dont-touch-the-water") {
    return (
      <div className="flex h-screen items-center justify-center bg-black text-white">
        No playable build for {game.title} yet.
      </div>
    );
  }

  return (
    <div className="h-screen w-screen overflow-hidden">
      <GameCanvas slug={slug} initialSettings={asSettings(config.settings)} />
    </div>
  );
}
