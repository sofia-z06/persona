CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    pseudo TEXT,
    interests TEXT[] NOT NULL DEFAULT '{}',
    send_time TIME,
    timezone TEXT NOT NULL DEFAULT 'Europe/Paris',
    consent_at TIMESTAMPTZ NOT NULL,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'unsubscribed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS otp (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS otp_email_idx ON otp (email);

CREATE TABLE IF NOT EXISTS auth_flow (
    session_id TEXT PRIMARY KEY,
    step TEXT NOT NULL CHECK (step IN ('awaiting_email', 'awaiting_code', 'awaiting_consent')),
    email TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);