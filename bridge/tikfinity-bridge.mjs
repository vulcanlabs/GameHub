#!/usr/bin/env node
/**
 * Forwards TikFinity local WebSocket gift events to a GameHub hook URL.
 *
 * Usage:
 *   node bridge/tikfinity-bridge.mjs --url http://localhost:3000/api/v1/hooks/TOKEN/events
 *
 * Options:
 *   --url     Required. Your personal hook URL from the Game Hub dashboard.
 *   --ws      TikFinity Events API (default ws://127.0.0.1:21213/)
 *   --slug    Game slug sent with each event (default dont-touch-the-water)
 */

const args = process.argv.slice(2);
function flag(name, fallback) {
  const i = args.indexOf(`--${name}`);
  if (i === -1) return fallback;
  return args[i + 1] ?? fallback;
}

const url = flag("url");
const wsUrl = flag("ws", "ws://127.0.0.1:21213/");
const slug = flag("slug", "dont-touch-the-water");

if (!url) {
  console.error(
    "Missing --url. Copy your hook URL from the Game Hub game page.",
  );
  process.exit(1);
}

let socket;
let reconnectTimer;

async function forward(gift) {
  const body = {
    event: "gift",
    slug,
    data: gift,
    giftName: gift.giftName,
    repeatCount: gift.repeatCount,
    giftType: gift.giftType,
    repeatEnd: gift.repeatEnd,
    coins: gift.coins,
    giftId: gift.giftId,
  };
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const text = await res.text();
    console.log(`[hook ${res.status}]`, text);
  } catch (err) {
    console.error("[hook error]", err.message || err);
  }
}

function connect() {
  console.log(`Connecting to TikFinity at ${wsUrl} …`);
  socket = new WebSocket(wsUrl);

  socket.addEventListener("open", () => {
    console.log("TikFinity connected. Forwarding gifts to", url);
  });

  socket.addEventListener("message", (ev) => {
    let msg;
    try {
      msg = JSON.parse(typeof ev.data === "string" ? ev.data : String(ev.data));
    } catch {
      return;
    }
    if (msg.event !== "gift") return;
    const data = msg.data || msg;
    console.log(
      `gift: ${data.giftName || "?"} ×${data.repeatCount || 1}`,
    );
    forward(data);
  });

  socket.addEventListener("close", () => {
    console.warn("TikFinity socket closed. Reconnecting in 2.5s…");
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connect, 2500);
  });

  socket.addEventListener("error", () => {
    // close handler reconnects
  });
}

connect();
