#!/usr/bin/env bash
# Exercise 6: The Disappearing Database
# This script creates a reproducible Postgres setup with persistence and auto-init.
# It generates: pg/compose.yml + pg/initdb.d/*.sql, then runs docker compose up.

set -euo pipefail

# ---- Helpers ---------------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
# docker compose can be 'docker compose' or legacy 'docker-compose'
dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "Docker Compose not found. Install Docker Desktop (includes docker compose)."
    exit 1
  fi
}

need docker

# ---- Layout ----------------------------------------------------------------
ROOT_DIR="$(pwd)"
PG_DIR="$ROOT_DIR/pg"
INIT_DIR="$PG_DIR/initdb.d"
mkdir -p "$INIT_DIR"

# ---- Compose file -----------------------------------------------------------
cat > "$PG_DIR/compose.yml" <<'YAML'
services:
  db:
    image: postgres:16-alpine
    container_name: pg-db
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: appdb
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb || exit 1"]
      interval: 2s
      timeout: 2s
      retries: 30
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./initdb.d:/docker-entrypoint-initdb.d:ro
    restart: unless-stopped

volumes:
  pg_data:
YAML

# ---- Schema init (auto-run on first startup) -------------------------------
cat > "$INIT_DIR/01_schema.sql" <<'SQL'
-- Auto-created on first init by Docker entrypoint.
-- Database: appdb (already created via POSTGRES_DB)
CREATE TABLE IF NOT EXISTS users (
  id          BIGSERIAL PRIMARY KEY,
  username    TEXT        NOT NULL UNIQUE,
  email       TEXT        NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id     BIGSERIAL PRIMARY KEY,
  name   TEXT           NOT NULL,
  price  NUMERIC(12,2)  NOT NULL DEFAULT 0,
  stock  INTEGER        NOT NULL DEFAULT 0
);
SQL

# Optional: tiny seed so QA sees data persists across restarts
cat > "$INIT_DIR/02_seed.sql" <<'SQL'
INSERT INTO users (username, email) VALUES
  ('alice', 'alice@example.com')
ON CONFLICT DO NOTHING;

INSERT INTO products (name, price, stock) VALUES
  ('Widget', 9.99, 100)
ON CONFLICT DO NOTHING;
SQL

echo "Files generated under: $PG_DIR"
echo " - compose.yml"
echo " - initdb.d/01_schema.sql"
echo " - initdb.d/02_seed.sql"

# ---- Up the stack -----------------------------------------------------------
echo "Starting PostgreSQL with Docker Compose..."
( cd "$PG_DIR" && dc up -d )

# ---- Wait for healthy -------------------------------------------------------
echo -n "Waiting for database to become healthy"
for i in {1..60}; do
  STATUS="$(docker inspect -f '{{.State.Health.Status}}' pg-db 2>/dev/null || echo "unknown")"
  if [ "$STATUS" = "healthy" ]; then
    echo " ✅"
    break
  fi
  echo -n "."
  sleep 1
done

if [ "${STATUS:-}" != "healthy" ]; then
  echo -e "\nDatabase did not become healthy in time. Run 'docker logs pg-db' to debug."
  exit 1
fi

# ---- Verify schema exists (via psql in the container) -----------------------
echo "Verifying tables..."
docker exec -i pg-db psql -U app -d appdb -v ON_ERROR_STOP=1 -c "\dt"

cat <<'DONE'

All set ✅

- PostgreSQL is running on localhost:5432
  * user:     app
  * password: secret
  * database: appdb

- Data persists in named volume 'pg_data' (survives container restarts).
- Schema auto-initialized from ./pg/initdb.d on the FIRST run only.

Useful commands:
  cd pg
  docker compose ps
  docker compose logs -f db
  docker exec -it pg-db psql -U app -d appdb
  docker compose restart db
  docker compose down    # stops containers but keeps pg_data volume
  docker volume ls       # shows 'pg_data'

Tip to test persistence:
  docker exec -it pg-db psql -U app -d appdb -c "INSERT INTO users(username,email) VALUES ('bob','bob@example.com');"
  docker compose restart db
  docker exec -it pg-db psql -U app -d appdb -c "SELECT * FROM users;"
DONE
