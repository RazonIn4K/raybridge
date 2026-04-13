# Connecting RayBridge to ChatGPT Web

ChatGPT cannot connect to localhost. You need a public HTTPS endpoint.

## Prerequisites

- ChatGPT Plus ($20/mo), Pro ($200/mo), Business, Enterprise, or Education plan
- Developer Mode enabled (not available in EEA, Switzerland, or UK)
- RayBridge installed locally via `scripts/install.sh`
- `cloudflared` installed (`brew install cloudflared`)

## Step 1: Start RayBridge HTTP

Generate a strong API key and start the server:

```bash
export MCP_API_KEY=$(openssl rand -hex 32)
echo "Save this key: $MCP_API_KEY"
bash scripts/start-http.sh
```

Leave this terminal running.

## Step 2: Start Cloudflare Tunnel

In a second terminal:

```bash
bash scripts/start-tunnel.sh
```

You'll see output like:

```
Your quick Tunnel has been created! Visit it at:
https://abc-xyz-123.trycloudflare.com
```

Copy the full URL and append `/mcp`:

```
https://abc-xyz-123.trycloudflare.com/mcp
```

## Step 3: Enable Developer Mode in ChatGPT

1. Open ChatGPT web → Settings (gear icon)
2. Go to **Apps & Connectors**
3. Scroll to **Advanced Settings**
4. Toggle on **Developer Mode**

## Step 4: Add the MCP App

1. Still in Apps & Connectors, click **Create**
2. Paste the tunnel URL: `https://abc-xyz-123.trycloudflare.com/mcp`
3. Select **No authentication** (the MCP_API_KEY is handled at the transport level, not OAuth — ChatGPT's "no auth" means no OAuth flow)
4. ChatGPT will discover the available tools and list them
5. Click **Save**

## Step 5: Use it

In any ChatGPT conversation, your RayBridge tools will appear as available connectors. ChatGPT will ask for confirmation before executing write actions.

## Persistent tunnel (optional)

Ephemeral tunnels get a new URL each time. For a stable URL:

```bash
# One-time setup
cloudflared tunnel create raybridge
cloudflared tunnel route dns raybridge mcp.yourdomain.com

# Add to Cloudflare DNS:
# CNAME  mcp  →  <tunnel-id>.cfargotunnel.com

# Run with named tunnel
cloudflared tunnel run --url http://127.0.0.1:3000 raybridge
```

Then use `https://mcp.yourdomain.com/mcp` as the ChatGPT app URL. This survives restarts.

## Known issues

- Cloudflare Tunnel logs intermittent "stream-canceled" errors with ChatGPT's SSE polling. Tool calls generally succeed despite these logs.
- If the tunnel URL changes (ephemeral mode), you must update the ChatGPT app configuration.
- Developer Mode MCP is in beta — the UI may change.

## Adding Cloudflare Access (recommended)

For an extra security layer beyond the bearer token:

1. In Cloudflare Zero Trust dashboard, create an Access Application
2. Set the domain to `mcp.yourdomain.com`
3. Add a policy (e.g., email OTP, or IP allowlist)
4. ChatGPT will need to authenticate through the Access flow

This prevents anyone who discovers your tunnel URL from reaching the MCP endpoint.
