#!/usr/bin/env bash
set -euo pipefail

# RayBridge — one-command installer for macOS
# Usage: bash scripts/install.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RAYBRIDGE_DIR="${RAYBRIDGE_DIR:-$REPO_ROOT}"
DRY_RUN=false

log()  { printf '\033[1;34m[kit]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ok]\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[!!]\033[0m  %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }
run()  { if $DRY_RUN; then log "DRY RUN: $*"; else "$@"; fi; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --raybridge-dir=*)
      err "This repo is the canonical RayBridge checkout. Clone it where you want it, then run install there."
      exit 1
      ;;
  esac
done

# ── Preflight checks ──────────────────────────────────────────────
if [[ "${OSTYPE:-}" != darwin* ]]; then
  err "This installer is for macOS only."
  exit 1
fi

if ! command -v brew &>/dev/null; then
  err "Homebrew is required. Install it first: https://brew.sh"
  exit 1
fi

# Check Raycast is installed
if [[ ! -d "/Applications/Raycast.app" ]] && ! mdfind "kMDItemCFBundleIdentifier == 'com.raycast.macos'" -count 2>/dev/null | grep -q '[1-9]'; then
  warn "Raycast does not appear to be installed. RayBridge needs it."
fi

# ── Install dependencies ──────────────────────────────────────────
need_brew() {
  local pkg="$1"
  if brew list --versions "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    log "Installing $pkg..."
    run brew install "$pkg"
  fi
}

need_brew bun
need_brew sqlcipher

# cloudflared is optional — only needed for ChatGPT web
if ! command -v cloudflared &>/dev/null; then
  log "Installing cloudflared (optional, for ChatGPT web HTTPS tunneling)..."
  run brew install cloudflared
else
  ok "cloudflared already installed"
fi

log "Running bun install in $RAYBRIDGE_DIR..."
run bash -c "cd '$RAYBRIDGE_DIR' && bun install"

# ── Create config directory ───────────────────────────────────────
run mkdir -p "$HOME/.config/raybridge"

# Copy default allowlist if none exists
if [[ ! -f "$HOME/.config/raybridge/tools.json" ]]; then
  if [[ -f "$REPO_ROOT/config/examples/tools-allowlist.json" ]]; then
    run cp "$REPO_ROOT/config/examples/tools-allowlist.json" "$HOME/.config/raybridge/tools.json"
    ok "Created default tools.json (allowlist mode — nothing exposed yet)"
  fi
fi

# ── Write RAYBRIDGE_HOME to shell profile ─────────────────────────
SHELL_RC="$HOME/.zshrc"
[[ -f "$HOME/.bashrc" ]] && [[ ! -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.bashrc"

if ! grep -q 'RAYBRIDGE_HOME' "$SHELL_RC" 2>/dev/null; then
  log "Adding RAYBRIDGE_HOME to $SHELL_RC..."
  run bash -c "echo '' >> '$SHELL_RC'"
  run bash -c "echo '# RayBridge' >> '$SHELL_RC'"
  run bash -c "echo 'export RAYBRIDGE_HOME=\"$RAYBRIDGE_DIR\"' >> '$SHELL_RC'"
fi

# ── Clear macOS quarantine/provenance flags ───────────────────────
# Files in ~/Downloads inherit quarantine attributes that cause
# "Operation not permitted" when Claude Desktop tries to execute them.
log "Clearing macOS quarantine attributes from repo scripts..."
for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/scripts/*.py; do
  [[ -f "$f" ]] && xattr -d com.apple.provenance "$f" 2>/dev/null || true
  [[ -f "$f" ]] && xattr -d com.apple.macl "$f" 2>/dev/null || true
  [[ -f "$f" ]] && xattr -d com.apple.quarantine "$f" 2>/dev/null || true
done
ok "Quarantine attributes cleared"

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│  RayBridge — installed                                   │"
echo "├──────────────────────────────────────────────────────────┤"
printf "│  %-56.56s│\n" "RayBridge:    $RAYBRIDGE_DIR"
printf "│  %-56.56s│\n" "Config:       ~/.config/raybridge/tools.json"
printf "│  %-56.56s│\n" "Shell export: RAYBRIDGE_HOME=$RAYBRIDGE_DIR"
echo "├──────────────────────────────────────────────────────────┤"
echo "│  Next steps:                                             │"
echo "│  1. Edit ~/.config/raybridge/tools.json                  │"
echo "│     (add your Raycast extensions to the allowlist)       │"
echo "│  2. Run: bash scripts/verify.sh                          │"
echo "│  3. Connect your AI client (see README.md)               │"
echo "└──────────────────────────────────────────────────────────┘"
