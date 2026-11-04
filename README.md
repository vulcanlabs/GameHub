# Game Hub

Workshop for TikTok LIVE interactive games. The hub is a Next.js app (accounts, gift bindings, per-user TikFinity hook). Don’t Touch the Water runs as a Godot app and only receives gifts from the hub.

## Documentation

| Doc | Topic |
| --- | --- |
| [docs/install.md](docs/install.md) | Install Godot and the hub, first session |
| [docs/architecture.md](docs/architecture.md) | How accounts, gifts, and the game connect |
| [docs/dont-touch-the-water.md](docs/dont-touch-the-water.md) | Controls and gift actions |
| [docs/adding-a-game.md](docs/adding-a-game.md) | New game checklist |
| [docs/tikfinity.md](docs/tikfinity.md) | Bridge, hooks, SSE |
| [docs/auth-and-roles.md](docs/auth-and-roles.md) | Google OAuth, admin/user |
| [AGENTS.md](AGENTS.md) | Agent entry (Next.js + doc index) |
| [openapi/openapi.yaml](openapi/openapi.yaml) | API contract |

Cursor: project rules in `.cursor/rules/`, skills in `.cursor/skills/`.

## Stack

- Next.js App Router
- Auth.js (Google)
- Prisma + SQLite
- Godot 4 (`games/dont-touch-the-water/godot`)
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
- **user** — new Google sign-ups. Start **inactive** with no end date. An admin activates them and sets `accessUntil`. Games close when that time passes.

## Play flow

Full steps: [docs/install.md](docs/install.md).

1. Sign in with Google. An admin sets `accessUntil` for anyone who is not an admin.
2. Open **Don’t Touch the Water** and create a link code.
3. Press Play in Godot on `games/dont-touch-the-water/godot`. Enter the hub URL and the code. Click to look.
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
| GET | `/api/v1/admin/users` | Admin session |
| PATCH/DELETE | `/api/v1/admin/users/{id}` | Admin session (`active` and/or `accessUntil`) |
| POST | `/api/v1/devices/codes` | Session (one-time desktop link code) |
| POST | `/api/v1/devices/link` | Pair code (returns a device token once) |
| GET | `/api/v1/devices?slug=` | Session (linked devices) |
| DELETE | `/api/v1/devices/{id}` | Session (revoke) |
| GET | `/api/v1/devices/live?slug=` | Device bearer (long-poll) |
| POST | `/api/v1/devices/state` | Device bearer (status / heartbeat) |
| GET/PUT | `/api/v1/devices/settings?slug=` | Device bearer (same settings as the hub) |

## Add a game

1. Create `games/<slug>/`. Web games use a React entry. Desktop games are a Godot 4 project.
2. Register it in [`games/registry.ts`](games/registry.ts) with `runtime: "web"` or `"desktop"`.
3. Wire `/play/[slug]` only for web games. Desktop games link from the hub.

## Scripts

| Script | What |
| --- | --- |
| `npm run dev` | Next.js dev server |
| `npm test` | Vitest (hook processing) |
| `npm run db:push` | Apply Prisma schema to SQLite |
| `npm run build` | Production build |

## Legacy

The original single-file Claude export is in [`legacy/`](legacy/). Behavior reference only.
