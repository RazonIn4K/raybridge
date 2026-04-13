# Security Model

## How RayBridge accesses Raycast data

RayBridge extracts OAuth tokens from Raycast's encrypted SQLite database at:

```
~/Library/Application Support/com.raycast.macos/raycast-enc.sqlite
```

The encryption key is pulled from macOS Keychain. Tokens originally scoped to individual Raycast extensions become available to any MCP client connected to RayBridge.

## Risk: OAuth token exposure

A compromised `MCP_API_KEY` with HTTP mode running on `0.0.0.0` could grant an attacker access to OAuth tokens for every authenticated Raycast extension — GitHub, Linear, Slack, Notion, Asana, etc.

## Mandatory mitigations

1. **Use allowlist mode** in `~/.config/raybridge/tools.json` — expose only extensions you actively need
2. **Prefer stdio transport** for local clients (Claude Desktop, Claude Code, Codex) — no network exposure
3. **Bind to localhost** — always set `MCP_HOST=127.0.0.1` for HTTP mode
4. **Set MCP_API_KEY** — use `openssl rand -hex 32` for a strong bearer token
5. **Use Cloudflare Access** if exposing over the internet — adds identity verification and IP restrictions on top of the tunnel

## OAuth token lifecycle

RayBridge reads tokens but never refreshes them. When a token expires, tool calls will fail until Raycast itself refreshes the token (typically by opening the extension in Raycast). There is no automatic recovery path.

## Compliance notes

**Anthropic (Claude Pro/Max):** Using MCP servers with Claude Desktop and Claude Code is the intended use case. Do not build a hosted service for multiple users on a single Claude subscription.

**OpenAI (Codex + ChatGPT):** Codex CLI with MCP servers is officially supported. ChatGPT Developer Mode MCP apps are in beta. Using your own subscription to power personal automation is fine; reselling access is not.
