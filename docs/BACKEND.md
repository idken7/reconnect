# Reconnect Backend: Operations Guide

The API lives in `backend/` (Dart, `shelf`, Postgres). The wire contract is `docs/API_CONTRACT.md`; this document covers configuration, running, deploying and operating it.

## Environment variables

The server reads everything from the environment and **refuses to start** (exit code 78, message on stderr listing every problem) if a required production value is missing or unsafe.

| Variable | Default | Notes |
|----------|---------|-------|
| `ENV` | `development` | `development`, `test`, `staging` or `production`. Only `production` disables developer conveniences. |
| `PORT` | `8080` | |
| `HOST` | `0.0.0.0` | Bind address. |
| `DATABASE_URL` | none | `postgres://user:pass@host:5432/db`. **Required in production.** Without it the server uses the in-memory store (data lost on restart). Append `?sslmode=disable` for a local non-TLS Postgres; managed Postgres normally needs `sslmode=require`. Pool size: `&max_connection_count=10`. |
| `PEPPER` | random per process in dev | Server secret (>= 32 chars, random) used for HMAC of imported contact identifiers and verification codes. **Required in production, and whenever `DATABASE_URL` is set.** Changing it orphans every stored contact hash (all users would have to re-import) and invalidates pending codes, so treat it like a database key: generate once, store in the secret manager, never rotate casually. |
| `ALLOWED_ORIGINS` | empty | Comma-separated exact origins allowed by CORS (the static site). Native apps do not need CORS. `*` is rejected. |
| `VERIFICATION_PROVIDER` | `console` (non-prod), `twilio` (prod) | `console` prints codes to stdout and is **rejected when `ENV=production`**. |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` | none | Required when `VERIFICATION_PROVIDER=twilio`. |
| `ACCESS_TOKEN_TTL_SECONDS` | `900` | |
| `REFRESH_TOKEN_TTL_DAYS` | `30` | Sliding: each rotation issues a fresh 30 days. |
| `CODE_TTL_MINUTES` | `10` | Verification and password-reset code lifetime. |
| `TRUST_PROXY` | `false` | Set `true` behind Fly/Render so the client IP comes from `Fly-Client-IP` / `X-Forwarded-For` (used by rate limits) and plain-HTTP API calls are refused in production. Never enable it when the server is directly exposed: clients could spoof their IP. |
| `MIGRATIONS_DIR` | `migrations` | `/app/migrations` in the container. |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warn`, `error`. |

Never commit values for these. In Fly use `fly secrets set`; locally use your shell or an untracked `.env`.

## Running locally

### In memory (fastest)

```bash
cd backend && dart pub get && dart run bin/server.dart
```

Verification codes are printed to the console as `[dev verification] sms to +1415...: code 123456`. `000000` is also accepted (non-production + console provider only).

### With Postgres

```bash
docker run --rm -d --name reconnect-pg -p 55432:5432 \
  -e POSTGRES_PASSWORD=devpw -e POSTGRES_DB=reconnect postgres:16

cd backend
DATABASE_URL='postgres://postgres:devpw@localhost:55432/reconnect?sslmode=disable' \
PEPPER="$(openssl rand -base64 48)" \
dart run bin/server.dart
```

Keep the same `PEPPER` between restarts or contact matching will break for imported address books.

### Tests

```bash
cd backend
dart analyze && dart test          # no external services required

# Also exercise the Postgres implementation (wipes the target database!):
DATABASE_URL='postgres://postgres:devpw@localhost:55432/reconnect?sslmode=disable' \
  dart test test/postgres_test.dart
```

CI should run the Postgres group against a `postgres:16` service container with a throwaway database.

## Database and migrations

* Migrations are `backend/migrations/NNN_name.sql`, applied in filename order at startup, each in a transaction and recorded in `schema_migrations`. A Postgres advisory lock serializes concurrent starters, so rolling deploys are safe.
* Add a new migration by creating the next numbered file. Never edit an applied migration. Keep migrations backwards compatible with the previous app version (add columns as nullable/defaulted first) so a rolling deploy or rollback never breaks.
* Tables: `users`, `refresh_sessions` (one per login/device), `session_tokens` (SHA-256 of access and refresh tokens; rotated refresh tokens are kept until expiry to detect reuse), `verification_codes` (HMAC of the code, attempt counter), `user_contacts` (HMAC of each imported identifier plus the display name), `contact_preferences`.
* Expired tokens, orphaned sessions and expired codes are purged hourly, keeping rows for 7 days so clients still receive `token_expired` / `refresh_token_expired`.
* Deleting a user (`DELETE /v1/account`) is a hard `DELETE FROM users`; foreign keys cascade to everything that references them.

## Deploying to Fly.io

One-time setup:

```bash
cd backend
fly apps create reconnect-api                 # match `app` in fly.toml
fly postgres create --name reconnect-db --region iad   # or use any managed Postgres
fly postgres attach reconnect-db -a reconnect-api      # sets DATABASE_URL; see TLS note below
fly secrets set -a reconnect-api \
  PEPPER="$(openssl rand -base64 48)" \
  TWILIO_ACCOUNT_SID=... TWILIO_AUTH_TOKEN=... TWILIO_VERIFY_SERVICE_SID=...
```

Edit `ALLOWED_ORIGINS` in `fly.toml` to the static site origin. Fly's internal Postgres URL usually ends in `?sslmode=disable` (private network); for an external managed Postgres use `sslmode=require`.

Deploy (and every later release):

```bash
cd backend && fly deploy
fly status -a reconnect-api && curl https://<app>.fly.dev/ready
```

Notes:

* The image is a `scratch` image containing only the AOT-compiled binary, CA certificates and migrations, running as UID 10001. It has no shell, so use `fly logs` rather than `fly ssh console` for debugging.
* `kill_signal = "SIGTERM"`: the server stops accepting connections, drains in-flight requests (10 s) and closes the DB pool.
* **Run a single machine.** The rate limiter is in-memory; with N machines every limit is effectively N times larger and lockouts are per machine. Move limiter state to Postgres/Redis before scaling out (`RateLimiter` is the only component to change).
* Staging: create a second app (`reconnect-api-staging`) with its own database and secrets and `ENV=staging`. Staging may use `VERIFICATION_PROVIDER=console`; its logs then contain codes, so do not point real users at it.
* Rollback: `fly releases -a reconnect-api` then `fly deploy --image <previous image>`. Because migrations are additive, the previous version keeps working against the newer schema.
* Health: liveness `GET /health`, readiness `GET /ready` (503 when the database is unreachable). Alert on `/ready` failures, a rising 5xx rate in the JSON logs (`"status":5xx`), and 429 spikes.

### Docker without Fly

```bash
docker build -t reconnect-api backend
docker run --rm -p 8080:8080 \
  -e DATABASE_URL=... -e PEPPER=... -e ALLOWED_ORIGINS=https://reconnect.example \
  -e TWILIO_ACCOUNT_SID=... -e TWILIO_AUTH_TOKEN=... -e TWILIO_VERIFY_SERVICE_SID=... \
  reconnect-api
```

The image defaults to `ENV=production`; use `-e ENV=staging -e VERIFICATION_PROVIDER=console` for a local container without Twilio.

## Backups and restore

Use a managed Postgres with automated daily backups and point-in-time recovery. On Fly Postgres or any other host, additionally keep an independent logical backup:

```bash
# Backup (run from a trusted machine or a scheduled job; store encrypted, off-platform)
pg_dump --format=custom --no-owner "$DATABASE_URL" > reconnect-$(date +%F).dump

# Restore into an empty database (staging first!)
createdb reconnect_restore
pg_restore --no-owner --dbname=reconnect_restore reconnect-2026-01-01.dump
```

Restore drill (do this before launch and quarterly):

1. Restore the latest backup into a scratch database.
2. Start the server against it with the **production `PEPPER`** (without it, imported contacts stop matching) and check `/ready`.
3. Log in with a known test account and call `GET /v1/dashboard`.

Account deletion and backups: deleted users remain in backups until those backups age out. Keep retention short (for example 30 days), state it in the privacy policy, and if a backup is restored, replay deletions requested since the backup time before reopening traffic.

Rotate `PEPPER` only with a planned re-import window: old hashes cannot be recomputed server-side because raw identifiers are never stored.

## Security model, briefly

* Passwords: Argon2id (19 MiB, 2 iterations, 1 lane, about 50 to 170 ms), random per-hash salt, parameters stored in the hash string; hashes are upgraded on the next successful login when parameters change. Hashing runs in a worker isolate, at most 2 at a time.
* Access and refresh tokens are 256-bit random values stored only as SHA-256. Refresh tokens rotate on every use; presenting an already-rotated token revokes that whole session (`refresh_token_reused`). Every login creates an independent session.
* Imported contacts are normalized (E.164 phones, lower-cased emails) and stored as `HMAC-SHA256(PEPPER, kind:value)` plus the display name from the user's own address book. Matching only considers other users' **verified** identifiers, is recomputed on every read, and exposes no email or phone. City and last-active time are only visible to **mutual** matches, and the city only when its owner enabled `locationShared`.
* Rate limits (in-memory, per instance): login 5/min/IP plus per-account lockout (5 failures, then 15 s doubling up to 1 h) and 10 failed logins/hour/account; signup 5/hour/IP; code sends 3/hour per destination and 20/hour/IP; API 120/min/user and 600/min/IP. 429 responses carry `Retry-After`.
* Bodies: 1 MB cap, 5 MB on `/v1/contacts/import` (max 5000 contacts). CORS only for `ALLOWED_ORIGINS`. Security headers on every response. Unhandled errors return a generic 500 with a `requestId`; the details are in the server log only.
* Logs are JSON lines on stdout with a request id, user id, route, status and latency. Keys that look sensitive are redacted and emails, phone numbers and bearer tokens are scrubbed from free text.

## Known limitations

* Anyone can sign up with an email or phone they do not own; the identifier is unusable for matching until verified, but it stays reserved, so the real owner gets `account_exists` until the squatter's account is removed. Consider a takeover flow for unverified accounts before public launch.
* Phone parsing is rule-based: default region is the US/NANP; other regions require the `+` prefix.
* `lastSeenAt` is the other user's last authenticated activity (refreshed at most every 5 minutes) and is shown only to mutual matches.
* No error reporting service or metrics endpoint yet; use the structured logs and the platform's metrics.
