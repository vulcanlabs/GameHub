# Game Hub

Workshop for TikTok LIVE interactive games. The hub is a Next.js app (accounts, gift bindings, per-user TikFinity hook). Each game lives under `games/` and uses Three.js.

## Stack

- Next.js App Router
- Auth.js (Google)
- Prisma + SQLite
- Three.js (`dont-touch-the-water`)
- Local TikFinity bridge (`bridge/tikfinity-bridge.mjs`)

## Quick start

```bash
cp .env.example .env
# set AUTH_SECRET (openssl rand -base64 32)
# set AUTH_GOOGLE_ID and AUTH_GOOGLE_SECRET (see below)

npm install
npx prisma db push
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Google OAuth

1. Create an OAuth 2.0 Client ID in [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. Application type: Web application.
3. Authorized redirect URI: `http://localhost:3000/api/auth/callback/google`
4. Put the client ID and secret in `.env` as `AUTH_GOOGLE_ID` and `AUTH_GOOGLE_SECRET`.
5. Restart `npm run dev`.

Until those are set, `/login` shows a setup error. There is no password or anonymous play.

## TikFinity hook

TikFinity only exposes gifts on the streamer’s PC at `ws://127.0.0.1:21213/`. Game Hub gives each user a secret HTTP URL:

```
http://localhost:3000/api/v1/hooks/<token>/events
```

Copy it from the game page. On the streaming PC (with TikFinity running):

```bash
node bridge/tikfinity-bridge.mjs --url 'http://localhost:3000/api/v1/hooks/TOKEN/events'
```

If the hub is on another machine, use that host in the URL. The bridge must still run on the same PC as TikFinity.

Rotate the token from the dashboard if it leaks.

## Roles

- **admin** — `etienne.landman@vulcanlabs.com` (plus any emails in `ADMIN_EMAILS`). Always active. Sidebar → **Users** to activate others.
- **user** — new Google sign-ups. Start **inactive**; they see home but no games until an admin activates them.

## Play flow

1. Sign in with Google (admin is active immediately; other users wait for activation).
2. Open **Don’t Touch the Water**, set gift → action bindings.
3. Press **Play** (allow pop-ups). Click the game canvas to lock the mouse.
4. Use **Test** on a gift, or run the bridge while live.

## API

Contract: [`openapi/openapi.yaml`](openapi/openapi.yaml).

| Method | Path | Auth |
| --- | --- | --- |
| POST | `/api/v1/hooks/{token}/events` | Hook token |
| GET/POST | `/api/v1/hooks/me` | Session (get / rotate) |
| GET/PUT | `/api/v1/games/{slug}/bindings` | Session |
| GET/PUT | `/api/v1/games/{slug}/settings` | Session |
| GET | `/api/v1/games/{slug}/live` | Session (SSE) |
| POST | `/api/v1/games/{slug}/test` | Session |

## Add a game

1. Create `games/<slug>/` with a playable React entry.
2. Register it in [`games/registry.ts`](games/registry.ts).
3. Wire `/play/[slug]` to load it.

## Scripts

| Script | What |
| --- | --- |
| `npm run dev` | Next.js dev server |
| `npm test` | Vitest (hook processing) |
| `npm run db:push` | Apply Prisma schema to SQLite |
| `npm run build` | Production build |

## Legacy

The original single-file Claude export is in [`legacy/`](legacy/). Behavior reference only.
