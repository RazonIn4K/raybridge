# HTTP Deployment

stdio is RayBridge's primary transport; run HTTP only when a remote client (ChatGPT web, n8n on a VPS, another machine) needs in. This doc covers the server's HTTP behavior, the exposure options, and the security posture. Click-by-click ChatGPT setup lives in [chatgpt-setup.md](chatgpt-setup.md); hosting options are summarized from [infrastructure.md](infrastructure.md).

## Starting the server

```bash
# Default bind: http://127.0.0.1:3000
bash scripts/start-http.sh

# With Bearer auth (recommended for any client that can send headers)
MCP_API_KEY=$(openssl rand -hex 32) bash scripts/start-http.sh

# Direct, with custom bind
MCP_API_KEY=... bun run src/index.ts --http --host 127.0.0.1 --port 3000
```

Starting without `MCP_API_KEY` logs a WARNING and serves `/mcp` unauthenticated (`src/index.ts:420-424`). That is acceptable only for the ChatGPT no-auth flow behind a tunnel, never for a directly exposed port.

## Endpoints and session model

| Endpoint | Method | Behavior |
|----------|--------|----------|
| `/health` | GET | `{status, sessions, extensions, tools}`; never authenticated |
| `/mcp` | POST | Initialize request creates a session; subsequent requests carry `Mcp-Session-Id` |
| `/mcp` | DELETE | Terminates the session named in `Mcp-Session-Id` |

Session model (decision AD-6): each session gets its own MCP `Server` over a StreamableHTTP transport, all sharing one mutable `ServerContext` (`src/http-server.ts:132-154`). A config or extension change reloads that context in place, so every live session sees it immediately. Sessions idle for 30 minutes are reaped on a 5-minute sweep (`src/http-server.ts:172-183`); clients must re-initialize after expiry.

Request hygiene: Bearer comparison is timing-safe (`src/http-server.ts:29-37`); JSON bodies are capped at `MCP_MAX_BODY_SIZE` (default 1mb, 413 on excess); malformed JSON returns 400; CORS allows the MCP headers ChatGPT and browsers need.

## Exposure options

**Cloudflare quick tunnel (free, ephemeral).** `bash scripts/start-tunnel.sh` gives a random `https://*.trycloudflare.com` URL; append `/mcp`. URL changes every restart, so reconfigure the remote client each time. The random URL is effectively the only secret in the ChatGPT no-auth flow, which is tolerable precisely because it is ephemeral.

**Cloudflare named tunnel (stable URL).**

```bash
cloudflared tunnel create raybridge
cloudflared tunnel route dns raybridge mcp.yourdomain.com
cloudflared tunnel run --url http://127.0.0.1:3000 raybridge
```

A stable URL is discoverable, so pair it with Cloudflare Access (email OTP or IP allowlist policy in Zero Trust) and/or `MCP_API_KEY`.

**n8n.** The MCP Client Tool node speaks MCP directly: point it at `http://localhost:3000/mcp` (same host) or the tunnel URL (VPS), with a Bearer credential when `MCP_API_KEY` is set. `scripts/call-raybridge.py` is the equivalent for plain scripts.

**Remote hosting (Cloud Run, droplet, Vultr).** Mostly a trap: RayBridge reads `~/.config/raycast/extensions/` and Raycast's encrypted database via the macOS Keychain, none of which exist on a Linux box. A container can only serve a frozen snapshot of extension code with manually supplied tokens. Treat it as an advanced pattern for a fixed toolset, not a way to escape keeping a Mac awake. See [infrastructure.md](infrastructure.md) for the option-by-option notes.

## ChatGPT web, condensed

ChatGPT Developer Mode cannot send custom Bearer headers, so: start HTTP **without** `MCP_API_KEY`, tunnel it, then ChatGPT Settings → Apps & Connectors → Developer Mode → Create → paste `https://<tunnel>/mcp` → No authentication. Full walkthrough with known issues: [chatgpt-setup.md](chatgpt-setup.md).

## Security checklist before exposing anything

- `MCP_API_KEY` set whenever the client supports Bearer (everything except ChatGPT)
- Bind `127.0.0.1` and let the tunnel do the exposure; never `0.0.0.0` on a public interface
- Allowlist mode with only the extensions you actually need remotely; remote callers inherit your Raycast OAuth grants
- `enableDestructiveSystemActions`, `enableAppleScript`, `enableCommandLaunch` stay off for remotely reachable servers
- Stable URLs get Cloudflare Access on top
- Watch stderr: every call logs `[CALL]/[OK]/[ERR]` with secrets redacted
