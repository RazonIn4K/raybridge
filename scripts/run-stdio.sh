#!/usr/bin/env bash
set -euo pipefail

# GUI apps (Claude Desktop, Codex IDE) launch MCP servers with a minimal
# PATH that excludes Homebrew. Add common Homebrew prefixes so bun, node,
# python3, and sqlcipher are reachable regardless of how the script is invoked.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAYBRIDGE_HOME="${RAYBRIDGE_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [[ ! -d "$RAYBRIDGE_HOME" ]]; then
  echo "RayBridge not found at $RAYBRIDGE_HOME" >&2
  echo "Run: bash scripts/install.sh" >&2
  exit 1
fi

"$SCRIPT_DIR/check-keychain.sh"

exec bun run "$RAYBRIDGE_HOME/src/index.ts"
