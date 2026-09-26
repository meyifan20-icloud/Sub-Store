#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFIX_ROOT="$HOME/.sub-store"
RUNTIME_DIR="$PREFIX_ROOT/runtime"
DATA_DIR="$PREFIX_ROOT/data"

pkg update -y
pkg install -y git curl unzip tar gzip nodejs-lts

NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
if (( NODE_MAJOR < 24 )); then
  echo "Termux repository currently provides $(node -v); Sub-Store source requires Node.js 24+." >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    corepack enable
    corepack prepare pnpm@11.0.9 --activate
  else
    npm install -g pnpm@11.0.9
  fi
fi

cd "$REPO_ROOT/backend"
pnpm install --frozen-lockfile
pnpm bundle:esbuild

rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/frontend" "$DATA_DIR"
cp dist/sub-store.bundle.js "$RUNTIME_DIR/sub-store.bundle.js"

TMP_FRONTEND="$(mktemp -d)"
curl -fL --retry 3 \
  https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip \
  -o "$TMP_FRONTEND/frontend.zip"
unzip -q "$TMP_FRONTEND/frontend.zip" -d "$TMP_FRONTEND/unpacked"
if [[ -d "$TMP_FRONTEND/unpacked/dist" ]]; then
  cp -a "$TMP_FRONTEND/unpacked/dist/." "$RUNTIME_DIR/frontend/"
else
  cp -a "$TMP_FRONTEND/unpacked/." "$RUNTIME_DIR/frontend/"
fi
rm -rf "$TMP_FRONTEND"

cat > "$PREFIX_ROOT/start.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export SUB_STORE_RUNTIME_ROOT="$RUNTIME_DIR"
export SUB_STORE_DATA_BASE_PATH="$DATA_DIR"
export SUB_STORE_FRONTEND_PATH="$RUNTIME_DIR/frontend"
export SUB_STORE_BACKEND_API_HOST="${SUB_STORE_BACKEND_API_HOST:-127.0.0.1}"
export SUB_STORE_BACKEND_API_PORT="${SUB_STORE_BACKEND_API_PORT:-3001}"
export SUB_STORE_BACKEND_MERGE="${SUB_STORE_BACKEND_MERGE:-true}"
export SUB_STORE_FRONTEND_BACKEND_PATH="${SUB_STORE_FRONTEND_BACKEND_PATH:-/2cXaAxRGfddmGz2yx1wA}"
export HTTP_META_ENABLED=false
cd "$DATA_DIR"
exec node "$RUNTIME_DIR/sub-store.bundle.js"
EOF
chmod 755 "$PREFIX_ROOT/start.sh"

echo
echo "Termux runtime prepared."
echo "Start: $PREFIX_ROOT/start.sh"
echo
echo "Note: core Sub-Store + local frontend is enabled."
echo "HTTP-META/mihomo/shoutrrr native tools are intentionally not auto-installed on Android/Termux;"
echo "use Docker/Linux Node for the validated full native-tool stack."
