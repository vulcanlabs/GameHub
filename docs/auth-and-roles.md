# Auth and roles

## Google OAuth

| Env | Meaning |
| --- | --- |
| `AUTH_URL` | Site origin only, e.g. `http://localhost:3000` |
| `AUTH_SECRET` | Auth.js secret |
| `AUTH_GOOGLE_ID` / `AUTH_GOOGLE_SECRET` | Web client credentials |
| `ADMIN_EMAILS` | Optional comma-separated extra admin emails |

**Never** set `AUTH_URL` to `/api/auth/callback/google`. Auth.js appends that path. Wrong `AUTH_URL` produces `redirect_uri_mismatch` (often a doubled `/callback/google`).

Google Console → Web application client → Authorized redirect URI:

`http://localhost:3000/api/auth/callback/google`

Authorized JavaScript origin: `http://localhost:3000`.

## Roles

| Role | Who | Active |
| --- | --- | --- |
| `admin` | `etienne.landman@vulcanlabs.com` + `ADMIN_EMAILS` | Always (forced in session) |
| `user` | Everyone else | Default `false` until admin activates, and `accessUntil` must be in the future |

Logic lives in `lib/roles.ts`. Session enrichment in `lib/auth.ts`. Route guards in `lib/session-guards.ts`.

On `createUser`: set `hookToken`, `role`, `active` (admin → active true). On `signIn` for admin emails: re-assert `role: admin`, `active: true`.

## Admin users UI

`/admin/users` — list, activate/deactivate, set `accessUntil` (+1 day, +7 days, +30 days, or a calendar date), cancel that date, delete.

- Cannot deactivate or delete admins.
- Cannot deactivate or delete yourself.

API: `GET /api/v1/admin/users`, `PATCH|DELETE /api/v1/admin/users/{id}`.

## Gating

`canAccessGames({ role, active, accessUntil })` — admins always pass. Other users need `active` and a future `accessUntil`.

Used by hub nav, home/library/game/play pages, hook ingest, device polls, and game APIs via `requireActivePlayer()`. Expired access returns `403` with code `expired`. Inactive accounts return `403` with code `inactive`.
