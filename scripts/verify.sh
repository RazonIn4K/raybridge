#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAYBRIDGE_HOME="${RAYBRIDGE_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PASS=0
FAIL=0

check() {
  local label="$1"; shift
  if "$@" &>/dev/null; then
    printf '\033[1;32m✓\033[0m %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '\033[1;31m✗\033[0m %s\n' "$label"
    FAIL=$((FAIL + 1))
  fi
}

echo "RayBridge — verification"
echo "───────────────────────────────────────"

check "bun installed"           command -v bun
check "sqlcipher installed"     command -v sqlcipher
if [[ "${RAYBRIDGE_CHECK_CLOUDFLARED:-0}" == "1" ]]; then
  check "cloudflared installed" command -v cloudflared
elif command -v cloudflared &>/dev/null; then
  printf '\033[1;32m✓\033[0m cloudflared installed (optional)\n'
  PASS=$((PASS + 1))
else
  printf '\033[1;33m-\033[0m cloudflared not installed (optional; set RAYBRIDGE_CHECK_CLOUDFLARED=1 to require it)\n'
fi
check "RayBridge repo present"  test -d "$RAYBRIDGE_HOME/src"
check "node_modules present"    test -d "$RAYBRIDGE_HOME/node_modules"
check "tools.json exists"       test -f "$HOME/.config/raybridge/tools.json"
check "Raycast installed"       test -d "/Applications/Raycast.app"

if "$SCRIPT_DIR/check-keychain.sh" &>/dev/null; then
  printf '\033[1;32m✓\033[0m %s\n' "Raycast Keychain access"
  PASS=$((PASS + 1))
else
  printf '\033[1;33m!\033[0m Raycast Keychain access is still waiting for approval\n'
  printf '  Open the macOS prompt for your terminal app, choose "Always Allow", then re-run.\n'
  FAIL=$((FAIL + 1))
fi

# Check for extensions with tools
EXT_DIR="$HOME/.config/raycast/extensions"
if [[ -d "$EXT_DIR" ]]; then
  TOOL_COUNT=$(find "$EXT_DIR" -name "package.json" -exec grep -l '"tools"' {} \; 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$TOOL_COUNT" -gt 0 ]]; then
    printf '\033[1;32m✓\033[0m %s extensions with AI tools found\n' "$TOOL_COUNT"
    PASS=$((PASS + 1))
  else
    printf '\033[1;33m!\033[0m No extensions with AI tool definitions found in %s\n' "$EXT_DIR"
    printf '  Install Raycast Store extensions that support AI tools.\n'
    printf '  See: docs/finding-extensions.md\n'
    FAIL=$((FAIL + 1))
  fi
else
  printf '\033[1;33m!\033[0m Extension directory not found: %s\n' "$EXT_DIR"
  FAIL=$((FAIL + 1))
fi

# Check Claude Desktop config
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [[ -f "$CLAUDE_CONFIG" ]] && grep -q "raybridge" "$CLAUDE_CONFIG" 2>/dev/null; then
  printf '\033[1;32m✓\033[0m Claude Desktop config includes raybridge\n'
  PASS=$((PASS + 1))
else
  printf '\033[1;33m-\033[0m Claude Desktop not yet configured (optional)\n'
fi

echo ""
echo "$PASS passed, $FAIL issues"
if [[ $FAIL -eq 0 ]]; then
  echo "Ready to connect AI clients."
  exit 0
fi

echo "Fix the issues above, then re-run."
exit "$FAIL"
