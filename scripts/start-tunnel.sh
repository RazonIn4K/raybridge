#!/usr/bin/env bash
set -euo pipefail

MCP_PORT="${MCP_PORT:-3000}"
MCP_HOST="${MCP_HOST:-127.0.0.1}"

if ! command -v cloudflared &>/dev/null; then
  echo "cloudflared is not installed. Run: brew install cloudflared" >&2
  exit 1
fi

echo "Exposing http://${MCP_HOST}:${MCP_PORT} via Cloudflare Tunnel..."
echo "Copy the https://xyz.trycloudflare.com URL into ChatGPT Developer Mode."
echo ""
exec cloudflared tunnel --url "http://${MCP_HOST}:${MCP_PORT}"
