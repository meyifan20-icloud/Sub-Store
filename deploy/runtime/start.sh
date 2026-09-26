#!/bin/sh
set -eu

APP_ROOT="${SUB_STORE_RUNTIME_ROOT:-/opt/app}"
DATA_ROOT="${SUB_STORE_DATA_BASE_PATH:-$APP_ROOT/data}"
FRONTEND_ROOT="${SUB_STORE_FRONTEND_PATH:-$APP_ROOT/frontend}"
HTTP_META_ENABLED="${HTTP_META_ENABLED:-true}"
HTTP_META_HOST="${HTTP_META_HOST:-127.0.0.1}"
HTTP_META_PORT="${HTTP_META_PORT:-9876}"
META_TEMP_FOLDER="${META_TEMP_FOLDER:-/tmp/http-meta}"

mkdir -p "$DATA_ROOT" "$META_TEMP_FOLDER"

export SUB_STORE_DATA_BASE_PATH="$DATA_ROOT"
export SUB_STORE_FRONTEND_PATH="$FRONTEND_ROOT"

if [ "$HTTP_META_ENABLED" = "true" ] && [ -f "$APP_ROOT/http-meta.bundle.js" ]; then
  echo "[Sub-Store] starting HTTP-META on $HTTP_META_HOST:$HTTP_META_PORT"
  META_FOLDER="$APP_ROOT/http-meta" \
  META_TEMP_FOLDER="$META_TEMP_FOLDER" \
  HOST="$HTTP_META_HOST" \
  PORT="$HTTP_META_PORT" \
  BODY_JSON_LIMIT="${BODY_JSON_LIMIT:-1mb}" \
  node "$APP_ROOT/http-meta.bundle.js" > "$DATA_ROOT/http-meta.log" 2>&1 &
fi

echo "[Sub-Store] starting backend"
cd "$DATA_ROOT"
exec node "$APP_ROOT/sub-store.bundle.js"
