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

1. **Use allowlist mode** in `~/.config/raybridge/tools.json` — expose only extensions you actively need; RayBridge exposes no extension tools when the config file is missing
2. **Prefer stdio transport** for local clients (Claude Desktop, Claude Code, Codex) — no network exposure
3. **Bind to localhost** — always set `MCP_HOST=127.0.0.1` for HTTP mode
4. **Set MCP_API_KEY** — use `openssl rand -hex 32` for a strong bearer token
5. **Use Cloudflare Access** if exposing over the internet — adds identity verification and IP restrictions on top of the tunnel
6. **Keep Raycast API shims gated** — clipboard, `open`, Finder, AppleScript, command launch, and destructive system actions are controlled by the `raycastApi` block in `tools.json`

## Extension execution boundary

RayBridge runs each Raycast extension tool call in a short-lived Bun worker process by default. This prevents a tool from poisoning the main server's module cache or shim state, and it lets RayBridge terminate calls that exceed `RAYBRIDGE_TOOL_TIMEOUT_MS` (default: 120 seconds).

This is process isolation, not a full macOS sandbox. The worker still runs as the same local user and can access files and network resources allowed to that user. Keep allowlist mode enabled and only expose tools you intend to trust.

Set `RAYBRIDGE_IN_PROCESS=true` only for local debugging when you need the older direct execution path.

## HTTP request handling

HTTP mode disables the Express fingerprint header, compares bearer tokens using a timing-safe comparison, and returns JSON errors for invalid or oversized MCP request bodies. The `/mcp` JSON body limit defaults to `1mb` and can be changed with `MCP_MAX_BODY_SIZE`.

Tool call logs redact common secret-shaped fields and bearer tokens. Successful calls log result length rather than a result preview.

## OAuth token lifecycle

RayBridge reads tokens but never refreshes them. When a token expires, tool calls will fail until Raycast itself refreshes the token (typically by opening the extension in Raycast). There is no automatic recovery path.

## Compliance notes

**Anthropic (Claude Pro/Max):** Using MCP servers with Claude Desktop and Claude Code is the intended use case. Do not build a hosted service for multiple users on a single Claude subscription.

**OpenAI (Codex + ChatGPT):** Codex CLI with MCP servers is officially supported. ChatGPT Developer Mode MCP apps are in beta. Using your own subscription to power personal automation is fine; reselling access is not.
