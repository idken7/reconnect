# syntax=docker/dockerfile:1

# ---- build: resolve dependencies and AOT-compile a single native binary ----
FROM dart:3.11 AS build
WORKDIR /app

# Dependency layer first so it is cached until pubspec changes.
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY analysis_options.yaml ./
COPY bin ./bin
COPY lib ./lib
RUN dart pub get --offline \
 && dart compile exe bin/server.dart -o /app/server

# ---- runtime: nothing but libc, CA certificates, the binary and the SQL ----
# /runtime/ (from the official dart image) holds the shared libraries and
# certificates a compiled Dart exe needs, so the final image has no shell,
# no package manager and no SDK.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
COPY migrations /app/migrations

ENV ENV=production \
    HOST=0.0.0.0 \
    PORT=8080 \
    MIGRATIONS_DIR=/app/migrations

# Unprivileged numeric user (scratch has no /etc/passwd).
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/app/server"]
