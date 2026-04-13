#!/usr/bin/env bash
set -euo pipefail

# RayBridge — uninstaller
# Removes this checkout, config, and shell exports. Does not uninstall brew packages.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAYBRIDGE_HOME="${RAYBRIDGE_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"

log()  { printf '\033[1;34m[kit]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!!]\033[0m  %s\n' "$*"; }

echo "This will remove:"
echo "  $RAYBRIDGE_HOME"
echo "  ~/.config/raybridge/"
echo "  RAYBRIDGE_HOME export from ~/.zshrc or ~/.bashrc"
echo ""
read -rp "Continue? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

if [[ -d "$RAYBRIDGE_HOME" ]]; then
  log "Removing $RAYBRIDGE_HOME..."
  rm -rf "$RAYBRIDGE_HOME"
else
  warn "RayBridge directory not found at $RAYBRIDGE_HOME"
fi

if [[ -d "$HOME/.config/raybridge" ]]; then
  log "Removing ~/.config/raybridge/..."
  rm -rf "$HOME/.config/raybridge"
fi

# Remove shell export
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && grep -q 'RAYBRIDGE_HOME' "$rc"; then
    log "Removing RAYBRIDGE_HOME from $rc..."
    sed -i '' '/# RayBridge/d' "$rc"
    sed -i '' '/RAYBRIDGE_HOME/d' "$rc"
  fi
done

echo ""
echo "Done. Brew packages (bun, sqlcipher, cloudflared) were left in place."
echo "Remove them manually with: brew uninstall bun sqlcipher cloudflared"
