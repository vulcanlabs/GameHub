---
name: gamehub-auth-roles
description: >-
  Change Google Auth.js setup, admin/user roles, account activation, or admin
  users API/UI. Use for OAuth redirect issues, ADMIN_EMAILS, activate/delete
  users, or access gating.
---

# Auth and roles

Read `docs/auth-and-roles.md`.

## OAuth footgun

`AUTH_URL` = origin only (`http://localhost:3000`).  
Google redirect URI = `http://localhost:3000/api/auth/callback/google`.  
Putting the callback into `AUTH_URL` doubles the path and causes `redirect_uri_mismatch`.

## Roles

- Admin emails: hard-coded owner in `lib/roles.ts` + optional `ADMIN_EMAILS`.
- New users: `role=user`, `active=false`.
- Admins always treated active in session.
- Admin UI `/admin/users`; API under `app/api/v1/admin/users/`.
- Never allow delete/deactivate of self or admin accounts.

## Code map

| Piece | File |
| --- | --- |
| NextAuth config | `lib/auth.ts` |
| Role helpers | `lib/roles.ts` |
| Route guards | `lib/session-guards.ts` |
| Session types | `types/next-auth.d.ts` |
