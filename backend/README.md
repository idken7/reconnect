# Reconnect Backend

Dart HTTP API (`shelf` + `shelf_router`) backed by Postgres. The contract it
implements is `docs/API_CONTRACT.md`; operations, configuration, deployment and
backups are in `docs/BACKEND.md`.

## Run locally

```bash
cd backend
dart pub get
dart run bin/server.dart          # in-memory store, console verification codes
```

Without `DATABASE_URL` the server keeps everything in memory (lost on restart)
and prints verification codes to the console. In any non-production `ENV` the
code `000000` is accepted too. To use Postgres, see `docs/BACKEND.md`.

The Flutter app expects the backend at `http://127.0.0.1:8080` on iOS/macOS and
`http://10.0.2.2:8080` on Android emulators unless `RECONNECT_API_BASE_URL` is set.

## Test

```bash
cd backend
dart analyze
dart test                          # no external services needed
```

Postgres tests run only when `DATABASE_URL` points at a throwaway database
(`DATABASE_URL=postgres://postgres:pw@localhost:55432/reconnect_test?sslmode=disable dart test test/postgres_test.dart`).

## Layout

```
bin/server.dart      thin entrypoint (config, start, signal handling)
lib/config.dart      env var parsing, fail-fast validation
lib/app.dart         middleware pipeline, startServer / shutdown
lib/db/              Repository interface, Postgres + in-memory implementations, migrator
lib/auth/            Argon2id hasher, token and HMAC helpers, common-password list
lib/middleware/      request context/logging/errors, security headers, CORS, rate limit, body limit, auth
lib/routes/          auth, account, contacts/profile/location, health
lib/services/        auth, verification (+ providers), matching, dashboard, rate limiter
migrations/          versioned SQL, applied at startup
```
