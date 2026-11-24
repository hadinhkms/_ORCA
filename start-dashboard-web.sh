#!/usr/bin/env bash
# macOS/Linux counterpart of start-dashboard-web.bat/.vbs: starts Orca Host (Web + Mobile on port 6769).
# Usage: ./start-dashboard-web.sh          start in background and open the browser
#        ./start-dashboard-web.sh --run    run in the foreground (logs to the terminal)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=6769
URL="http://127.0.0.1:${PORT}/web-index.html"
LOG="${ROOT}/start-dashboard-web.log"
cd "$ROOT"

for dir in /opt/homebrew/opt/node@24/bin /usr/local/opt/node@24/bin "$HOME/.bun/bin"; do
  [[ -d "$dir" ]] && PATH="$dir:$PATH"
done
export PATH
if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
  set +u
  # shellcheck disable=SC1091
  source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" --no-use && nvm use 24 >/dev/null
  set -u
fi

is_listening() { lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; }

is_ready() { curl -fs -o /dev/null --max-time 1 "$URL"; }

open_url() {
  if command -v open >/dev/null; then open "$URL"; elif command -v xdg-open >/dev/null; then xdg-open "$URL"; fi
}

run_host() {
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [[ "$major" == "24" ]] || echo "Warning: Node 24 is required, found $(node -v)." >&2

  if [[ ! -f out/web/web-index.html ]]; then
    echo "Building out/web bundle ..."
    node node_modules/vite/bin/vite.js build --config vite.web.config.ts
  fi

  node config/scripts/workspace-package-build/build-workspace-packages.mjs

  if [[ ! -f out/cli/index.js ]]; then
    echo "Building out/cli bundle ..."
    ORCA_CLI_BUILD_COMPILER="${ORCA_CLI_BUILD_COMPILER:-tsrs}" node config/scripts/cli-build/build-cli.mjs
    node config/scripts/cli-build/verify-cli-bin.mjs --fix-executable --fix-package-json
  fi

  # Orca Mobile loads its workspace UI from this bundle; without it the phone says "Update Orca".
  if [[ ! -f out/mobile-web/manifest.json ]]; then
    echo "Building out/mobile-web bundle ..."
    node config/scripts/build/mobile-web-app/build-mobile-web-app-bundle.mjs
  fi

  node config/scripts/native-build/node-addons/ensure-native-runtime.mjs --runtime=electron
  exec node config/scripts/development/launch/run-electron-vite-dev.mjs -- --orca-start-in-tray
}

if is_listening; then
  echo "Orca Host already listening on port ${PORT}."
  [[ "${1:-}" == "--run" ]] || open_url
  exit 0
fi

if [[ "${1:-}" == "--run" ]]; then
  run_host
fi

echo "[$(date)] Starting Orca Host on port ${PORT} ..." >"$LOG"
nohup "$0" --run >>"$LOG" 2>&1 &
echo "Starting Orca Host in the background (log: ${LOG}) ..."

for _ in $(seq 1 240); do
  if is_ready; then
    echo "Ready: ${URL}"
    open_url
    exit 0
  fi
  if ! kill -0 $! 2>/dev/null; then
    echo "Orca Host exited during startup. Last log lines:" >&2
    tail -n 30 "$LOG" >&2
    exit 1
  fi
  sleep 0.5
done

echo "Orca Host is still starting after 2 minutes; check ${LOG}." >&2
