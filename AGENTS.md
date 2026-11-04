<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# Game Hub agent guide

## Docs

| Doc | When |
| --- | --- |
| [docs/install.md](docs/install.md) | Install, first use, go live |
| [docs/architecture.md](docs/architecture.md) | How the hub, bridge, and games connect |
| [docs/dont-touch-the-water.md](docs/dont-touch-the-water.md) | Godot course, controls, actions |
| [docs/adding-a-game.md](docs/adding-a-game.md) | New game checklist |
| [docs/tikfinity.md](docs/tikfinity.md) | Hooks, bridge, SSE |
| [docs/auth-and-roles.md](docs/auth-and-roles.md) | Google OAuth, admin/user, lease |
| [openapi/openapi.yaml](openapi/openapi.yaml) | HTTP contract |
| [README.md](README.md) | Run / env |

## Project skills (`.cursor/skills/`)

- `gamehub-architecture` — map the repo
- `gamehub-godot` — desktop Godot client, device poll, Don’t Touch the Water
- `add-gamehub-game` — scaffold a game
- `gamehub-tikfinity` — gift pipeline
- `gamehub-auth-roles` — auth and roles

## Project rules (`.cursor/rules/`)

- `gamehub-core.mdc` — always on
- `games-three.mdc` — `games/**`
- `api-v1.mdc` — `app/api/**`
