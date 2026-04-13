# Infrastructure Options

RayBridge runs locally on macOS by default. For remote access (ChatGPT web, n8n on a VPS), you need to expose the HTTP endpoint.

## Option 1: Cloudflare Tunnel (recommended, free)

Ephemeral tunnel — generates a random `trycloudflare.com` URL each time:

```bash
bash scripts/start-tunnel.sh
```

Persistent tunnel — uses a subdomain on your own domain:

```bash
# One-time setup
cloudflared tunnel create raybridge
cloudflared tunnel route dns raybridge mcp.yourdomain.com

# Then run
cloudflared tunnel run --url http://127.0.0.1:3000 raybridge
```

Pair with Cloudflare Access for identity-based auth on top of the bearer token.

## Option 2: DigitalOcean Droplet + n8n

If you already run n8n on a DigitalOcean droplet, the n8n MCP Client node can reach RayBridge's HTTP endpoint directly over the tunnel — no additional infra needed.

For the n8n deployment itself, a 2 vCPU / 4 GB droplet ($24/mo, covered by the $200 new-account credit) running the Docker Compose stack (n8n + PostgreSQL + Caddy) is sufficient.

## Option 3: GCP Cloud Run (containerized)

If you have GCP credits and want a fully managed remote RayBridge:

1. Fork RayBridge and add a `Dockerfile`
2. Build and push to Artifact Registry
3. Deploy to Cloud Run with `--port 3000` and `MCP_API_KEY` as a secret

Note: RayBridge needs access to `~/.config/raycast/extensions/` and the encrypted SQLite database, which only exist on macOS. A remote Cloud Run deployment would need the extension code and tool definitions copied into the container — it cannot access your local Raycast installation. This is an advanced pattern for serving a fixed set of tools without a Mac running.

## Option 4: Vultr (burst compute)

If you have Vultr credits and need temporary remote access, spin up a small instance, rsync the RayBridge code and extension definitions, and tear it down when done. Use the n8n burst-compute workflow pattern with auto-shutdown.

## Option 5: RunPod (not recommended for this)

RunPod is GPU compute for ML inference. It's not a good fit for RayBridge, which is CPU-bound and IO-light. Save RunPod credits for local LLM serving or other GPU workloads.
