#!/usr/bin/env bash
set -euo pipefail

# GUI apps launch MCP servers with a minimal PATH that excludes Homebrew.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAYBRIDGE_HOME="${RAYBRIDGE_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-3000}"

if [[ ! -d "$RAYBRIDGE_HOME" || ! -f "$RAYBRIDGE_HOME/package.json" || ! -f "$RAYBRIDGE_HOME/src/index.ts" ]]; then
  echo "RayBridge checkout not found at $RAYBRIDGE_HOME" >&2
  echo "Run: bash scripts/install.sh" >&2
  exit 1
fi

"$SCRIPT_DIR/check-keychain.sh"

if [[ -z "${MCP_API_KEY:-}" ]]; then
  echo "WARNING: MCP_API_KEY is not set. The /mcp endpoint will be unauthenticated." >&2
  echo "Set it with: MCP_API_KEY=\$(openssl rand -hex 32) bash scripts/start-http.sh" >&2
  echo ""
fi

echo "Starting RayBridge HTTP on http://${MCP_HOST}:${MCP_PORT}/mcp"
exec bun run "$RAYBRIDGE_HOME/src/index.ts" --http --host "$MCP_HOST" --port "$MCP_PORT"
