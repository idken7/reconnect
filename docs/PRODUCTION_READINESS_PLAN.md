# Reconnect: Production Readiness Plan

Goal: take the web, server, and mobile app from "working prototype" to something real users can safely sign up for and use.

This plan addresses every gap found in the readiness review. Phases are ordered by dependency; items marked **[parallel]** can be done alongside other work in the same phase.

Effort key: S = under 1 day, M = 1-3 days, L = 3-7 days (single developer).

---

## Decisions needed up front

These change the shape of the work. Recommended defaults are in bold; the plan assumes them.

| # | Decision | Recommendation | Why |
|---|----------|----------------|-----|
| D1 | Backend language | **Keep Dart** (restructure onto `shelf` + `shelf_router`) | Shares models with the app, existing tests carry over. A rewrite buys nothing at this scale. |
| D2 | Database | **Postgres** (managed) | Concurrent writes, transactions, backups, indexes for matching. |
| D3 | Hosting | **Fly.io or Render** + managed Postgres | Cheap, HTTPS and secrets built in, simple Docker deploys. |
| D4 | Identity verification | **Phone OTP (Twilio Verify) as primary; email as secondary** | Matching is by phone/email. Without verification anyone can claim someone else's number and see who has it in their contacts. |
| D5 | What "web" means | **Phase 1: static site (landing, privacy policy, terms, account-deletion page). Phase 2 (optional): Flutter web app** | Contact import and background location don't work in browsers, so a full web client is a different, reduced product. |
| D6 | Password hashing | **Argon2id** (fall back to bcrypt if the Dart package is too slow in benchmarks) | Current unsalted SHA-256 is crackable. |
| D7 | Launch scope | **Private TestFlight/Play internal beta first, then public store release** | Lets us ship the security-critical fixes before any public exposure. |

---

## Phase 0: Emergency hygiene (do first, before anything is deployed) (S)

Nothing here needs design; it removes live risk.

1. **Remove `backend/data/store.json` from git** and add `backend/data/` to `.gitignore`.
2. **Purge it from history** (`git filter-repo --path backend/data/store.json --invert-paths`) since it contains real-looking accounts and weak hashes. Coordinate a force-push; tell any collaborators to re-clone. Treat `test@yahoo.com` and any other real addresses in it as exposed.
3. **Remove the seeded account** (`avery@example.com` / `password123`) from the server's startup path. Move test fixtures into the test suite only.
4. **Scrub the README/docs** of working credentials (README, `docs/DEVELOPMENT.md`, `SETUP_COMPLETE.txt`).
5. **Consolidate stray docs** (`SETUP_COMPLETE.txt`, `NAVIGATOR_CONTEXT_FIX.md`, `FEATURE_BUTTONS_VERIFICATION.md`, `INFRASTRUCTURE_SETUP.md`) into `docs/` or delete them, so the README is the one source of truth.

**Done when:** a fresh clone contains no user data, no default credentials, and `git log --all -- backend/data/store.json` is empty.

---

## Phase 1: Server foundation (L)

Restructure `backend/bin/server.dart` (878 lines, one file) into modules, then fix infrastructure issues.

### 1.1 Structure and config (M)
- Split into `lib/` modules: `config`, `db`, `auth`, `routes/*`, `services/*`, `middleware/*`; keep `bin/server.dart` as a thin entrypoint.
- Move to `shelf` with a middleware pipeline (logging, error handling, CORS, auth, rate limit, body limit).
- Read config from environment variables: `PORT`, `DATABASE_URL`, `ALLOWED_ORIGINS`, `ENV`, token TTLs, Twilio keys. Fail fast on missing required values.
- Bind to `0.0.0.0` only via config; handle `SIGTERM` (not just SIGINT) for graceful shutdown in containers.
- Add `/health` (liveness) and `/ready` (DB reachable).

### 1.2 Database (L)
- Add Postgres via the `postgres` package with a pooled connection and a simple versioned migration runner (`migrations/001_init.sql`, ...).
- Schema (initial):
  - `users` (id, email, email_verified_at, phone_e164, phone_verified_at, password_hash, name, home_city, bio, profile_image_url, current_location, location_shared bool, created_at, deleted_at)
  - `refresh_sessions` (id, user_id, token_hash, device_label, created_at, expires_at, revoked_at)
  - `access tokens`: switch to short-lived signed tokens (JWT/HMAC) so there's no table lookup per request, or keep a hashed-token table. **Never store raw tokens.**
  - `user_contacts` (user_id, identifier_hash, kind, display_name, preference, created_at), the imported address book, stored as hashes of normalized phone/email plus the display name the user already knows.
  - `contact_preferences` (user_id, target_user_id, preference)
  - `audit_log` (optional, for auth events)
- Indexes on `users(email)`, `users(phone_e164)`, `user_contacts(identifier_hash)`, `refresh_sessions(token_hash)`.
- One-time script to import existing dev data is **not needed** (see Phase 0: no real users to migrate).

### 1.3 Credentials and sessions (M)
- Replace SHA-256 with Argon2id; store params with the hash so they can be upgraded. Re-hash on login if params are outdated.
- Hash refresh tokens at rest (SHA-256 is fine for high-entropy random tokens).
- Allow multiple concurrent sessions per user (remove the "delete other access tokens on login" behavior in `_createAuthSession`); one refresh session per device.
- Refresh-token rotation with reuse detection: if a rotated-out token is presented again, revoke that whole session family.
- Add `POST /v1/auth/logout` (revoke current session) and `POST /v1/auth/logout-all`.
- Password policy: min 8 chars plus a check against a common-passwords list; reject emails/phones that fail validation (real email regex, E.164 parse).
- Password reset: `POST /v1/auth/password-reset/request` and `/confirm` using an emailed or SMS single-use code with a short TTL.

### 1.4 Abuse protection (M)
- Rate limiting (per IP and per account): e.g. login 5/min/IP and 10/hour/account with exponential lockout, signup 5/hour/IP, OTP send 3/hour/number, general API 120/min/user. Start with an in-memory limiter behind one instance; move to Postgres or Redis if scaled to multiple instances.
- Request body limit (e.g. 1 MB; contact import capped, say 5,000 contacts, with a larger limit only on that route).
- Strict input validation on every route (types, lengths, enums for `preference` and `location`); return 400, not 500, on malformed JSON or wrong types (currently `jsonDecode(...) as Map` and `entry as Map` casts throw).
- Constant-time compare for token and hash checks; identical error and timing for unknown email vs wrong password.

### 1.5 Transport, errors, observability (M)
- TLS terminates at the host (Fly/Render); enforce HTTPS and add HSTS and standard security headers.
- CORS: allow only configured origins (the web site), not `*`. Native apps don't need CORS.
- Error handler: log the full error + request id server-side, return a generic `{code, error, requestId}` to clients. Never return `error.toString()`.
- Structured JSON logging with request id, user id, route, latency; redact tokens, passwords, phone/email.
- Error reporting (Sentry) and basic metrics (request rate, p95 latency, 5xx rate).

### 1.6 Deploy artifacts (S)
- `backend/Dockerfile` (multi-stage: `dart compile exe`, small runtime image, non-root user).
- `fly.toml` or `render.yaml`, secrets set via the host's secret store.
- Staging and production environments with separate databases.
- Automated daily Postgres backups plus a documented, tested restore.

**Done when:** the server runs from a container against Postgres, no secrets or data live in the repo, load tests at ~50 req/s pass without errors, and brute-force login attempts get locked out.

---

## Phase 2: Real product logic on the server (L)

This replaces the hardcoded 5-person `directoryContacts` list, the biggest functional gap.

### 2.1 Identity verification (M)
- Send OTP on signup via Twilio Verify; mark `phone_verified_at`. Only verified identifiers participate in matching.
- Email verification link (secondary).
- Normalize phones to E.164 using a proper library or rules with a default region taken from the device locale/home city (current `_normalizePhone` just strips punctuation, so `555-1234` and `+1 555-1234` never match).

### 2.2 Contact discovery and matching (L)
- `POST /v1/contacts/import`: client sends normalized phones/emails (ideally pre-hashed with a server-provided salt/pepper, so raw address books aren't uploaded); server stores `user_contacts` hashes and display names.
- **Matching:** a contact is "on app" if their identifier hash equals a verified user's identifier hash.
  - `mutual` = both users have each other in their contacts.
  - `oneWay` = you have them, they don't have you.
  - `notOnApp` = no user match (store only the name the user already has).
- Recompute matches when a new user verifies (so existing users' "not on app" contacts can become matches), via a background job or on-read query.
- Privacy rules: never reveal a user to someone who doesn't already have their identifier; one-way matches should not expose location unless the other user opted in.

### 2.3 Location and suggestions (M)
- Store each user's `current_location` (city level only) and a `location_shared` consent flag; only mutual matches who've opted in appear in "nearby."
- Replace the fixed 4-city list with a normalized city model (or keep a configurable list with a "Other" option); stop defaulting unknown coordinates to Brooklyn (`_locationFromCoordinates` fallback).
- Replace string `lastSeen` placeholders ("2 weeks ago") with real timestamps (last interaction/last seen) computed server-side.
- Preferences (`loveToSee`/`neutral`/`ratherAvoid`) stored per `(user, contact)`; "rather avoid" is private to the user and never exposed to the contact.

### 2.4 Account lifecycle (M)
- `DELETE /v1/account`: hard-delete user, sessions, contacts, preferences (required by Apple App Store policy); scheduled purge of backups within the stated retention window.
- `GET /v1/account/export`: JSON export of the user's data.
- `PATCH /v1/profile`: validate `profileImageUrl` (https only, allowlisted host), or add upload to object storage if profile images are a real feature.

**Done when:** two real accounts that each have the other's verified phone/email in their address book appear as a mutual match, and a stranger cannot discover either of them.

---

## Phase 3: Mobile app (iOS + Android) (L)

### 3.1 Environment and release configuration (S)
- Make `prod` the default for release builds: use `--dart-define=FLAVOR=prod` in build scripts, and assert in release mode that the flavor is set (`kReleaseMode && flavor == 'dev'` → fail loudly). Better: select flavor from `kReleaseMode` by default.
- Set real `apiBaseUrl` for production and staging in `lib/config/environment.dart`; fix the `staging()` config that currently reports `Environment.production`.
- Update `scripts/build_testflight.sh` to pass the flavor and the API URL.

### 3.2 Remove silent demo data (M)
- Gate all mock/seed data behind an explicit `isDevelopment` or "Demo mode" switch. In release builds, an unreachable backend shows a proper offline/error state with retry; it never fabricates 30 contacts (`app_state.dart:130-170`).
- Remove the auto-onboarding with `dev-mode-test-token` from any non-debug path.
- If a demo mode is desired for App Review, make it an explicit, labeled "Try demo" button.

### 3.3 Secure token storage (S)
- Move access/refresh tokens from `SharedPreferences` to `flutter_secure_storage` (Keychain / EncryptedSharedPreferences); migrate and delete the old keys on first launch.
- Handle refresh-token reuse/revocation (server may now revoke): on `401 invalid_refresh_token`, sign out cleanly.

### 3.4 Features the backend now requires (M)
- Phone/email verification screens in onboarding.
- Log out (and "log out everywhere") in Profile.
- Delete account flow (confirmation, calls `DELETE /v1/account`, clears local data).
- Password reset flow.
- Location consent toggle; explain what is shared.
- Hash/normalize contacts on device before upload; show a clear explanation before the contacts permission prompt.
- Proper error states, loading states, and offline handling throughout.

### 3.5 Android release (S)
- Create an upload keystore and a `key.properties` (gitignored); configure `signingConfigs.release` and remove the debug-key signing in `android/app/build.gradle.kts`.
- Set final `applicationId`, a proper app label ("Reconnect"), launcher icons, and `minSdk`/`targetSdk` per current Play requirements.
- Enable R8/minify; add ProGuard rules if needed; build an `.aab`.
- Block cleartext HTTP (default on modern Android) and verify there are no debug-only network configs.

### 3.6 iOS release (S)
- Set Team ID and signing in Xcode; confirm bundle id `com.reconnect.reconnect` is the one you own (or change it).
- Add a **privacy manifest** (`PrivacyInfo.xcprivacy`) covering required-reason APIs and collected data types (contacts, location, email, phone).
- Review Info.plist usage strings (already present for contacts and location) and add any new ones.
- Confirm App Transport Security is not weakened.

### 3.7 Dependency and quality pass (S) [parallel]
- Run `flutter pub outdated`; update `geolocator` (^12), `permission_handler` (^11) and others to supported versions; re-test.
- The vendored `third_party/flutter_contacts` fork: record why it's forked, track upstream, and remove checked-in generated `doc/api` HTML (hundreds of files).
- Resolve the "Flutter new version available" warning in CI by pinning a Flutter version (`flutter-version:`) instead of floating `stable`.

**Done when:** a release build pointed at staging signs up, verifies, imports contacts, sees real matches, logs out, and deletes the account, with no demo data anywhere; Android `.aab` is signed with the release key; iOS archive validates in Xcode Organizer.

---

## Phase 4: Web (M, plus L if full app)

Depends on D5.

### 4.1 Static site (recommended first)
- Create `web-site/` (static HTML or a small framework; host on Cloudflare Pages/Netlify/Fly).
- Pages: landing, **privacy policy**, **terms of service**, **support/contact**, **account & data deletion** instructions (also required by Google Play).
- Used as the privacy-policy URL in both stores and the CORS-allowed origin.

### 4.2 Flutter web app (optional, later)
- `flutter create --platforms web .`
- Audit plugins for web support: `flutter_contacts` (no address-book access in browsers), `geolocator` (works, requires HTTPS), `permission_handler` (limited), `share_plus` (partial).
- Design web as a reduced client (sign in, view matches, manage profile, delete account) or skip it.
- If shipped: add a `build-web` job to CI, set CORS on the server to the web origin, host over HTTPS, and keep tokens in memory + HttpOnly cookie rather than `localStorage`.

---

## Phase 5: Testing and CI/CD (M, ongoing alongside other phases)

### 5.1 Backend tests
- Run Postgres as a service container in GitHub Actions; run migrations in the test setup.
- Unit tests: password hashing and upgrade, token rotation and reuse detection, phone/email normalization, matching logic (mutual / one-way / not-on-app, privacy cases).
- Integration tests for every route including failure paths: malformed JSON, oversized body, wrong types, expired/revoked tokens, rate-limit lockout, account deletion removes all data, unauthenticated access is rejected everywhere.
- Add `dart analyze` to the `backend-test` CI job (currently only `dart test`).

### 5.2 App tests
- Keep the existing 95 tests; add tests for: no demo data in release mode, secure-storage migration, logout/delete flows, verification flow, offline error state.
- Add an end-to-end smoke test (integration_test) against a staging backend.

### 5.3 CI/CD
- CI: add release-mode builds (`flutter build appbundle --release` with a CI keystore from secrets, `flutter build ios --release --no-codesign`), pin the Flutter version, and add dependency scanning (`dart pub outdated`, Dependabot).
- CD: deploy backend to staging on merge to `main`, to production on a tagged release with a manual approval; run migrations as a deploy step before the new version starts.
- Secret scanning (gitleaks) in CI to prevent a repeat of the committed `store.json`.

---

## Phase 6: Compliance, launch, and operations (M)

- **Privacy policy and ToS** published (Phase 4); the policy must describe contacts upload, hashing, location use, retention, deletion, and third parties (Twilio, host, Sentry).
- **App Store Connect:** privacy nutrition labels (Contacts, Location, Email, Phone, Identifiers), contacts-permission justification, account-deletion path, review notes with a test account.
- **Google Play:** Data safety form, account-deletion URL, permission declarations (`READ_CONTACTS` is sensitive and requires justification).
- **Operations:** uptime monitor on `/health`, alerts on 5xx rate and DB errors, written runbook (deploy, rollback, restore from backup, rotate secrets), and on-call contact.
- **Rollout:** internal TestFlight/Play internal track → a small closed beta (20-50 users) → public release. Watch error rates and signup completion at each step.
- **Cost/limits:** Twilio and host costs per user; set billing alerts.

---

## Suggested sequence and timeline (one developer, rough)

| Order | Work | Effort | Can parallelize with |
|-------|------|--------|----------------------|
| 1 | Phase 0 hygiene | 0.5 day | none, do first |
| 2 | Phase 1 server foundation | ~1.5 weeks | Phase 4.1 static site, Phase 3.7 deps |
| 3 | Phase 2 real matching + verification | ~1.5 weeks | Phase 3.1-3.3 app config/storage |
| 4 | Phase 3.4-3.6 app features + release signing | ~1 week | Phase 5 tests |
| 5 | Phase 5 CI/CD hardening | ~3 days (spread through) | all |
| 6 | Phase 6 compliance + closed beta | ~1 week | none, final gate |
| 7 | Phase 4.2 Flutter web (optional) | ~1-2 weeks | after launch |

Total to a closed beta: roughly 5-6 weeks. A public launch follows after beta feedback.

## Release gates (all must be true before public launch)

- [ ] No credentials, user data, or secrets in git (history cleaned, gitleaks green).
- [ ] Passwords use Argon2id; tokens hashed at rest; brute-force protection tested.
- [ ] Real user-to-user matching with verified identifiers; privacy rules tested.
- [ ] Server on managed Postgres with tested backups, HTTPS, restricted CORS, monitoring and alerts.
- [ ] Release app builds point at production, show no demo data, store tokens securely.
- [ ] Account deletion works in-app and on the web; privacy policy and ToS live.
- [ ] Android signed with release key; iOS archive validated; store listings and privacy forms complete.
- [ ] CI runs analyze, tests (with Postgres), and release builds on every PR.
- [ ] Closed beta completed with no open severity-1 or -2 issues.
