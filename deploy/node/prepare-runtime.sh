#!/bin/sh
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
RUNTIME_DIR="${SUB_STORE_RUNTIME_DIR:-$REPO_ROOT/.runtime}"
BACKEND_DIR="$REPO_ROOT/backend"

FRONTEND_URL="${FRONTEND_URL:-https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip}"
HTTP_META_URL="${HTTP_META_URL:-https://github.com/xream/http-meta/releases/latest/download/http-meta.bundle.js}"
HTTP_META_TEMPLATE_URL="${HTTP_META_TEMPLATE_URL:-https://github.com/xream/http-meta/releases/latest/download/tpl.yaml}"
MIHOMO_VERSION_URL="${MIHOMO_VERSION_URL:-https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt}"
MIHOMO_BASE_URL="${MIHOMO_BASE_URL:-https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha}"
SHOUTRRR_BASE_URL="${SHOUTRRR_BASE_URL:-https://github.com/containrrr/shoutrrr/releases/latest/download}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need node
need curl
need unzip
need tar
need gzip

NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
if [ "$NODE_MAJOR" -lt 24 ]; then
  echo "Node.js 24+ is required. Current: $(node -v)" >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    corepack enable
    corepack prepare pnpm@11.0.9 --activate
  else
    need npm
    npm install -g pnpm@11.0.9
  fi
fi

echo "[1/5] Building backend from this repository..."
(
  cd "$BACKEND_DIR"
  pnpm install --frozen-lockfile
  pnpm bundle:esbuild
)

rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/frontend" "$RUNTIME_DIR/http-meta" "$RUNTIME_DIR/data"

cp "$BACKEND_DIR/dist/sub-store.bundle.js" "$RUNTIME_DIR/sub-store.bundle.js"
cp "$REPO_ROOT/deploy/runtime/healthcheck.mjs" "$RUNTIME_DIR/healthcheck.mjs"

echo "[2/5] Downloading frontend..."
TMP_FRONTEND="$(mktemp -d)"
curl -fL --retry 3 "$FRONTEND_URL" -o "$TMP_FRONTEND/frontend.zip"
unzip -q "$TMP_FRONTEND/frontend.zip" -d "$TMP_FRONTEND/unpacked"
if [ -d "$TMP_FRONTEND/unpacked/dist" ]; then
  cp -a "$TMP_FRONTEND/unpacked/dist/." "$RUNTIME_DIR/frontend/"
else
  cp -a "$TMP_FRONTEND/unpacked/." "$RUNTIME_DIR/frontend/"
fi
rm -rf "$TMP_FRONTEND"

echo "[3/5] Downloading HTTP-META..."
curl -fL --retry 3 "$HTTP_META_URL" -o "$RUNTIME_DIR/http-meta.bundle.js"
curl -fL --retry 3 "$HTTP_META_TEMPLATE_URL" -o "$RUNTIME_DIR/http-meta/tpl.yaml"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    MIHOMO_ARCH="amd64-v1"
    SHOUTRRR_ARCH="amd64"
    ;;
  aarch64|arm64)
    MIHOMO_ARCH="arm64"
    SHOUTRRR_ARCH="arm64"
    ;;
  armv7l|armv7)
    MIHOMO_ARCH="armv7"
    SHOUTRRR_ARCH="armv6"
    ;;
  *)
    echo "Unsupported Linux architecture for mihomo/shoutrrr: $ARCH" >&2
    exit 1
    ;;
esac

echo "[4/5] Downloading mihomo core..."
MIHOMO_VERSION="$(curl -fsSL "$MIHOMO_VERSION_URL" | tr -d '\r\n')"
test -n "$MIHOMO_VERSION"
curl -fL --retry 3 "$MIHOMO_BASE_URL/mihomo-linux-$MIHOMO_ARCH-$MIHOMO_VERSION.gz" \
  | gunzip > "$RUNTIME_DIR/http-meta/http-meta"
chmod 755 "$RUNTIME_DIR/http-meta/http-meta"

echo "[5/5] Downloading shoutrrr..."
TMP_SHOUTRRR="$(mktemp -d)"
curl -fL --retry 3 "$SHOUTRRR_BASE_URL/shoutrrr_linux_$SHOUTRRR_ARCH.tar.gz" \
  | tar -xz -C "$TMP_SHOUTRRR"
cp "$TMP_SHOUTRRR/shoutrrr" "$RUNTIME_DIR/shoutrrr"
chmod 755 "$RUNTIME_DIR/shoutrrr"
rm -rf "$TMP_SHOUTRRR"

cat > "$RUNTIME_DIR/start.sh" <<EOF
#!/bin/sh
export PATH="$RUNTIME_DIR:\$PATH"
export SUB_STORE_RUNTIME_ROOT="$RUNTIME_DIR"
export SUB_STORE_DATA_BASE_PATH="${SUB_STORE_DATA_BASE_PATH:-$RUNTIME_DIR/data}"
export SUB_STORE_FRONTEND_PATH="${SUB_STORE_FRONTEND_PATH:-$RUNTIME_DIR/frontend}"
exec "$REPO_ROOT/deploy/runtime/start.sh"
EOF
chmod 755 "$RUNTIME_DIR/start.sh"

echo
echo "Runtime prepared at: $RUNTIME_DIR"
echo "Start with:"
echo "  cp .env.example .env"
echo "  set -a; . ./.env; set +a"
echo "  $RUNTIME_DIR/start.sh"
