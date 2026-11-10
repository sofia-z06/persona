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

-- ============================================================
-- articles : articles récupérés depuis les sources de news
-- ============================================================
CREATE TABLE IF NOT EXISTS articles (
    id SERIAL PRIMARY KEY,
    url TEXT NOT NULL UNIQUE CHECK (url ~* '^https?://'),
    title TEXT NOT NULL,
    summary TEXT,
    source TEXT,
    tags TEXT[] NOT NULL DEFAULT '{}',
    published_at TIMESTAMPTZ,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- filtrer vite par tag, ex : WHERE tags && users.interests
CREATE INDEX IF NOT EXISTS articles_tags_idx ON articles USING GIN (tags);

-- ============================================================
-- sent_articles : historique des envois (un article envoyé une seule fois par user)
-- ============================================================
CREATE TABLE IF NOT EXISTS sent_articles (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    article_id INTEGER NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, article_id)
);

-- la PK couvre les recherches par user_id ; cet index couvre celles par article_id
CREATE INDEX IF NOT EXISTS sent_articles_article_idx ON sent_articles (article_id);
-- #21 : cache des résumés LLM
ALTER TABLE articles ADD COLUMN IF NOT EXISTS summarized_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_sent_at TIMESTAMPTZ;