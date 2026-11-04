# Install and first use

Game Hub is two programs on the stream PC: the Next.js hub, and a Godot game. TikFinity stays a third program. Only the hub talks to it.

## What you install

| Piece | Where |
| --- | --- |
| Node.js 20+ | Hub, bridge |
| Godot 4.3 or newer | Don’t Touch the Water |
| Google OAuth client | Sign-in |
| TikFinity | Only when you go live |

## Hub

From the repo root:

```bash
cp .env.example .env
```

Set these in `.env`:

| Name | Value |
| --- | --- |
| `AUTH_SECRET` | `openssl rand -base64 32` |
| `AUTH_GOOGLE_ID` / `AUTH_GOOGLE_SECRET` | Web client from Google Cloud Console |
| `AUTH_URL` | `http://localhost:3000` and nothing after it |
| `DATABASE_URL` | `file:./dev.db` (already in the example) |

Google Cloud Console → credentials → OAuth client → Web application:

- Authorized redirect URI: `http://localhost:3000/api/auth/callback/google`
- Authorized JavaScript origin: `http://localhost:3000`

Then:

```bash
npm install
npx prisma db push
npm run dev
```

Open http://localhost:3000 and continue with Google.

The owner email is an admin and can open games immediately. Every other account starts inactive. An admin opens **Users**, activates the account, and sets an end date (+1 day, +7 days, +30 days, or a calendar day). **Cancel** clears that end date. When the time passes, or after Cancel, the game poll returns 403 and the Godot window goes back to the link screen.

## Godot game

1. Install Godot 4.3 or newer from [godotengine.org](https://godotengine.org/).
2. Import `games/dont-touch-the-water/godot`.
3. Press Play in the editor (F5). Export a desktop build later from the Godot editor if you want a window without the editor. There is no installer to ship.

The first screen asks for three things:

| Field | What to type |
| --- | --- |
| Hub URL | `http://localhost:3000` (or the hub’s origin if it is not on this machine) |
| Link code | From the hub, on Don’t Touch the Water → **Create link code**. It lasts 5 minutes and works once. |
| This PC | Any name you will recognize on the hub device list |

The game remembers the hub URL only. Each launch asks for a new link code. Creating a code works until the account end date. **Cancel** on Users clears that date.

## First session

1. Hub → Don’t Touch the Water.
2. Map a few gifts, or leave the defaults (Rose pushes back, TikTok pushes forward, and so on).
3. Create a link code and enter it in the Godot window.
4. Click **Click to look**. WASD moves, Shift sprints, Space jumps, Esc pauses.
5. Press **Test** on a gift in the hub. The Godot window should move, spawn, or jump checkpoints.
6. Esc opens pause. Monster, difficulty, field of view, push strength, and the custom checkpoint step save back to the same settings as the hub.

Difficulty rebuilds the course. The Three.js files under `games/dont-touch-the-water/` are the previous browser build. The hub no longer opens them. They stay until that folder is removed.

## Going live

On the same PC as TikFinity:

```bash
node bridge/tikfinity-bridge.mjs --url 'http://localhost:3000/api/v1/hooks/TOKEN/events'
```

The token is on the game page. The bridge reads `ws://127.0.0.1:21213/` and posts gifts to the hub. The Godot game never opens that socket.

Keep the hub process running. Gift delivery is in memory inside that one Node process. A second hub process would not see the same gifts.

## If something fails

| What you see | Check |
| --- | --- |
| Login says Google is not configured | `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET`, then restart `npm run dev` |
| `redirect_uri_mismatch` | `AUTH_URL` is the origin only. Redirect URI in Google is `/api/auth/callback/google` |
| Account pending or access ended | Admin → Users. `active` on, and `accessUntil` in the future |
| Link code rejected | Code expired, already used, or the slug is not a desktop game |
| Test does nothing in Godot | Game window is polling (hub device list says “polling”), and the gift is mapped |
| Gifts during a stream do nothing | Bridge is running, URL token matches the page, TikFinity is on this PC |
