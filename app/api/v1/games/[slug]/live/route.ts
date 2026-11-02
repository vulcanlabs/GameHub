import { apiError } from "@/lib/errors";
import { getGame } from "@/games/registry";
import { subscribeLive, type LiveEvent } from "@/lib/live";
import { requireActivePlayer } from "@/lib/session-guards";

export async function GET(
  _req: Request,
  ctx: { params: Promise<{ slug: string }> },
) {
  const gate = await requireActivePlayer();
  if ("error" in gate) return gate.error;

  const { slug } = await ctx.params;
  if (!getGame(slug)) return apiError(404, "not_found", "Unknown game");

  const userId = gate.session.user.id;
  const encoder = new TextEncoder();
  let cleanup: (() => void) | undefined;
  let heartbeat: ReturnType<typeof setInterval> | undefined;

  const stream = new ReadableStream({
    start(controller) {
      const send = (event: LiveEvent) => {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify(event)}\n\n`),
        );
      };
      cleanup = subscribeLive(userId, slug, send);
      send({ type: "status", message: "connected" });
      heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(`: ping\n\n`));
        } catch {
          /* closed */
        }
      }, 15000);
    },
    cancel() {
      if (heartbeat) clearInterval(heartbeat);
      cleanup?.();
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}
