# Reconnect Backend

Persistent Dart HTTP backend for the Reconnect MVP.

## Run

```bash
cd backend
dart pub get
dart run bin/server.dart
```

The backend stores data at `backend/data/store.json`.

## Test

```bash
cd backend
dart analyze
dart test
```

## Auth Lifecycle

- `POST /v1/auth/signup` returns access token, refresh token, and access expiry.
- `POST /v1/auth/login` returns access token, refresh token, and access expiry.
- `POST /v1/auth/refresh` rotates refresh token and returns a new access token.
- Access tokens are short-lived (15 minutes by default).

The Flutter app expects the backend at `http://127.0.0.1:8080` on iOS/macOS and `http://10.0.2.2:8080` on Android emulators, unless `RECONNECT_API_BASE_URL` is set.
