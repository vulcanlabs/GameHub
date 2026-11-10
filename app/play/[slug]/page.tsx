import { notFound, redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import { getGame } from "@/games/registry";
import { asSettings, getOrCreateGameConfig } from "@/lib/game-config";
import { isWaterSettings } from "@/lib/gifts";
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
      accessUntil: session.user.accessUntil,
    })
  ) {
    redirect("/");
  }

  const { slug } = await params;
  const game = getGame(slug);
  if (!game) notFound();
  if (game.runtime === "desktop") redirect(`/games/${slug}`);

  const config = await getOrCreateGameConfig(session.user.id, slug);
  if (!config) notFound();

  if (slug !== "dont-touch-the-water") {
    return (
      <div className="flex h-screen items-center justify-center bg-black text-white">
        No playable build for {game.title} yet.
      </div>
    );
  }

  const settings = asSettings(slug, config.settings);
  if (!isWaterSettings(settings)) notFound();

  return (
    <div className="h-screen w-screen overflow-hidden">
      <GameCanvas slug={slug} initialSettings={settings} />
    </div>
  );
}
