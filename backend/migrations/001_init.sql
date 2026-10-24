-- Reconnect initial schema.
-- Timestamps are timestamptz (UTC). Ids are opaque app-generated strings.

CREATE TABLE users (
  id                  text PRIMARY KEY,
  email               text NOT NULL,
  email_hash          text NOT NULL,
  email_verified_at   timestamptz,
  phone_e164          text NOT NULL,
  phone_hash          text NOT NULL,
  phone_verified_at   timestamptz,
  password_hash       text NOT NULL,
  name                text NOT NULL DEFAULT '',
  home_city           text NOT NULL DEFAULT '',
  bio                 text NOT NULL DEFAULT '',
  profile_image_url   text NOT NULL DEFAULT '',
  current_location    text NOT NULL DEFAULT 'Other',
  location_shared     boolean NOT NULL DEFAULT false,
  last_active_at      timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX users_email_key ON users (email);
CREATE UNIQUE INDEX users_phone_key ON users (phone_e164);
-- Matching only ever considers verified identifiers.
CREATE INDEX users_phone_hash_idx ON users (phone_hash) WHERE phone_verified_at IS NOT NULL;
CREATE INDEX users_email_hash_idx ON users (email_hash) WHERE email_verified_at IS NOT NULL;

-- One row per login/device. Holds the whole refresh-token family.
CREATE TABLE refresh_sessions (
  id            text PRIMARY KEY,
  user_id       text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  device_label  text NOT NULL DEFAULT '',
  created_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz
);

CREATE INDEX refresh_sessions_user_idx ON refresh_sessions (user_id);

-- SHA-256 of access and refresh tokens. Raw tokens are never stored.
CREATE TABLE session_tokens (
  id          text PRIMARY KEY,
  session_id  text NOT NULL REFERENCES refresh_sessions (id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('access', 'refresh')),
  token_hash  text NOT NULL,
  expires_at  timestamptz NOT NULL,
  rotated_at  timestamptz
);

CREATE UNIQUE INDEX session_tokens_hash_key ON session_tokens (token_hash);
CREATE INDEX session_tokens_session_idx ON session_tokens (session_id);
CREATE INDEX session_tokens_expires_idx ON session_tokens (expires_at);

-- Single active code per (purpose, target). code_hash is null when the
-- verification provider (Twilio Verify) holds the code.
CREATE TABLE verification_codes (
  id           text PRIMARY KEY,
  purpose      text NOT NULL,
  target       text NOT NULL,
  user_id      text REFERENCES users (id) ON DELETE CASCADE,
  code_hash    text,
  attempts     integer NOT NULL DEFAULT 0,
  expires_at   timestamptz NOT NULL,
  consumed_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX verification_codes_target_key ON verification_codes (purpose, target);
CREATE INDEX verification_codes_expires_idx ON verification_codes (expires_at);

-- Imported address book: HMAC(pepper, normalized identifier) + display name only.
CREATE TABLE user_contacts (
  user_id          text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  identifier_hash  text NOT NULL,
  kind             text NOT NULL CHECK (kind IN ('phone', 'email')),
  entry_index      integer NOT NULL,
  display_name     text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, identifier_hash)
);

CREATE INDEX user_contacts_hash_idx ON user_contacts (identifier_hash);

-- Private per-viewer preference about another user; never exposed to that user.
CREATE TABLE contact_preferences (
  user_id         text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  target_user_id  text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  preference      text NOT NULL CHECK (preference IN ('loveToSee', 'neutral', 'ratherAvoid')),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_user_id)
);

CREATE INDEX contact_preferences_target_idx ON contact_preferences (target_user_id);
