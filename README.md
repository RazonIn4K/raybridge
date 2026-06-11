# RayBridge

Expose Raycast extension tools to Claude Desktop, Claude Code, Codex, ChatGPT web, or any other MCP client.

This fork keeps the upstream RayBridge code and the local setup assets in one repository: launcher scripts, config examples, docs, and security defaults. For personal use, this is the only repo you need.

![RayBridge TUI](screenshot.png)

## What this repo is

- `origin` is your fork: `https://github.com/RazonIn4K/raybridge`
- `upstream` is the original project: `https://github.com/jlokos/raybridge`
- This checkout is the canonical working tree for your local setup

That means you do not need a separate starter-kit repository or a second clone just to run the server. Pull upstream changes into this fork when you want them, and keep your local setup docs and scripts here.

## What RayBridge can and cannot expose

RayBridge discovers Raycast Store extensions that define AI tools in their `package.json` `tools` array. That includes extensions for services like GitHub, Linear, Jira, Notion, Slack, and other API-backed workflows.

RayBridge does not enumerate Raycast's built-in native features like clipboard history, calculator, app launcher, or file search, because those are not packaged as extensions with MCP-style tool definitions. Some Raycast extension APIs such as clipboard access, `open`, and Finder reveal are available through optional shims for extension tools that need them.

To discover which installed extensions are compatible, see [docs/finding-extensions.md](docs/finding-extensions.md).

## How it works

1. Scan `~/.config/raycast/extensions/` for installed extensions with `tools` definitions
2. Load OAuth tokens from Raycast's encrypted SQLite database
3. Add compact Raycast eval examples from extension manifests to help MCP clients pick the right tool
4. Register each extension as an MCP tool available over stdio or HTTP
5. Execute Raycast extension tools in a short-lived Bun worker process by default

Extensions that use Raycast UI APIs (`List`, `Detail`, `Form`, and similar) are supported through shims. Extensions whose tools perform background work like API calls, lookups, and transformations work best.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — component map, startup sequence, tool invocation flow, transports
- [docs/DECISIONS.md](docs/DECISIONS.md) — living ADR list (20 accepted decisions)
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) — tools.json, shim gates, preferences.json, all environment variables
- [docs/MODEL_COMPATIBILITY.md](docs/MODEL_COMPATIBILITY.md) — why any MCP client/model works; RayBridge = tools, client = models
- [docs/TESTING.md](docs/TESTING.md) — the six suites, execute-mode caveats, hermetic CI candidates
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — symptom-first fixes for startup, tool-call, and HTTP issues
- [docs/HTTP_DEPLOYMENT.md](docs/HTTP_DEPLOYMENT.md) — HTTP session model, tunnels, remote exposure security checklist
- [docs/EXTENSION_COMPAT.md](docs/EXTENSION_COMPAT.md) — which extension patterns work vs degrade, shim coverage table
- [docs/SHODAN_APIFY.md](docs/SHODAN_APIFY.md) — Shodan/Apify normalizer + Zen analysis workflow
- [docs/ARCHITECTURE_AND_DECISIONS.md](docs/ARCHITECTURE_AND_DECISIONS.md) — consolidated reference (primer, decision matrix, operational walkthrough, cleanup plan)
- [docs/finding-extensions.md](docs/finding-extensions.md), [docs/security.md](docs/security.md), [docs/chatgpt-setup.md](docs/chatgpt-setup.md), [docs/infrastructure.md](docs/infrastructure.md)

## Prerequisites

- macOS with [Raycast](https://raycast.com) installed
- Raycast Store extensions with AI tools installed
- [Homebrew](https://brew.sh)

The installer handles `bun`, `sqlcipher`, and `cloudflared`.

## Quick Start

### 1. Clone your fork and install

```bash
git clone https://github.com/RazonIn4K/raybridge.git
cd raybridge
bash scripts/install.sh
```

On first launch, macOS may ask your terminal app for access to Raycast's Keychain item named `database_key`. Choose **Always Allow**.

### 2. Configure your tool allowlist

```bash
cp config/examples/tools-allowlist.json ~/.config/raybridge/tools.json
```

Edit `~/.config/raybridge/tools.json` to enable only the extensions you want exposed. If this file is missing, RayBridge now falls back to an empty allowlist rather than exposing every installed AI extension.

To discover your installed extension and tool names:

```bash
find ~/.config/raycast/extensions -name "package.json" \
  -exec grep -l '"tools"' {} \; 2>/dev/null
```

### 3. Connect Claude Desktop

Merge the following into `~/Library/Application Support/Claude/claude_desktop_config.json`
or copy from `config/examples/claude-desktop.json`:

```json
{
  "mcpServers": {
    "raybridge": {
      "command": "/opt/homebrew/bin/bun",
      "args": ["run", "/ABSOLUTE/PATH/TO/raybridge/src/index.ts"],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }
  }
}
```

Replace `/ABSOLUTE/PATH/TO/raybridge/src/index.ts` with the full path to this repo's `src/index.ts`, then restart Claude Desktop.

### 4. Connect Claude Code

```bash
claude mcp add --transport stdio raybridge -- \
  /opt/homebrew/bin/bun run "$HOME/Git-Projects/raybridge/src/index.ts"
```

Or copy `config/examples/mcp-project.json` into your project's `.mcp.json` and replace the placeholder path with the absolute path to this repo.

### 5. Connect Codex

Merge `config/examples/codex-config.toml` into `~/.codex/config.toml`, or run:

```bash
codex mcp add raybridge -- \
  /opt/homebrew/bin/bun run "$HOME/Git-Projects/raybridge/src/index.ts"
```

### 6. Connect ChatGPT web or other HTTP clients

```bash
# Terminal 1
MCP_API_KEY=$(openssl rand -hex 32) bash scripts/start-http.sh

# Terminal 2
bash scripts/start-tunnel.sh
```

Then use the `https://...trycloudflare.com/mcp` URL in the remote MCP client.

For a persistent tunnel and more detailed remote setup, see [docs/chatgpt-setup.md](docs/chatgpt-setup.md).

## Why direct Bun is the default

Use `/opt/homebrew/bin/bun` directly in MCP client configs and pass the absolute path to `src/index.ts`.

This avoids two common macOS failures:

- GUI apps launch with a minimal `PATH`, so plain `bun` often is not found
- macOS Sequoia can mark shell scripts copied from `~/Downloads` with `com.apple.provenance`, which causes `Operation not permitted` when sandboxed apps try to execute them

Direct Bun plus an absolute entrypoint avoids both problems.

## HTTP Transport

You can run RayBridge over HTTP for remote clients.

```bash
# Default: http://127.0.0.1:3000
bash scripts/start-http.sh

# Custom host and port
MCP_HOST=0.0.0.0 MCP_PORT=8080 bash scripts/start-http.sh

# With API key auth
MCP_API_KEY=your-secret-key bash scripts/start-http.sh

# Direct Bun also works from the repo root
MCP_API_KEY=your-secret-key bun run src/index.ts --http --host 127.0.0.1 --port 3000
```

Endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/mcp` | POST | MCP requests |
| `/mcp` | DELETE | Terminate session |

When `MCP_API_KEY` is set, send:

```text
Authorization: Bearer your-secret-key
```

Sessions expire after 30 minutes of inactivity.

## Tool Execution Isolation

Raycast extension code runs in a fresh Bun worker process for each tool call. This keeps extension module state, shim mutations, uncaught crashes, and most memory leaks out of the long-running MCP server process.

Controls:

- `RAYBRIDGE_TOOL_TIMEOUT_MS=120000` sets the worker timeout in milliseconds
- `RAYBRIDGE_IN_PROCESS=true` disables worker isolation for local debugging
- `MCP_MAX_BODY_SIZE=1mb` sets the maximum JSON request body accepted by `/mcp`

## CLI

RayBridge includes a CLI and TUI for controlling which extensions and tools are exposed:

```bash
bun link

raybridge
raybridge config
raybridge list
raybridge help
```

The TUI lets you toggle extensions and individual tools, switch between allowlist and blocklist mode, and save to `~/.config/raybridge/tools.json`.

## Built-In Catalog Tool

RayBridge registers a built-in MCP tool named `raybridge` alongside your Raycast extension tools. Use it when an MCP client needs to inspect what Raycast can do before choosing a tool:

- `action: "summary"` reports installed AI-tool extensions, command-only extensions, enabled tools, and eval coverage
- `action: "search"` searches extension, tool, and command names/descriptions
- `action: "detail"` shows one extension's enabled tools, command-only entries, and eval count
- `action: "config"` shows the active allowlist mode, configured extensions, and `raycastApi` shim gates
- `action: "doctor"` checks stale config entries, missing tool files, risky enabled tools, and active shim gates
- `action: "recommend"` suggests low-risk disabled tools to consider and high-risk tools to leave disabled unless needed

Command-only entries are informational. They are not directly callable as structured MCP tools unless the Raycast extension adds AI tools.

## Configuration

Everything lives under `~/.config/raybridge/`: `tools.json` controls which extensions/tools are exposed (allowlist mode recommended) and gates risky Raycast APIs (clipboard, system actions, trash, AppleScript, command launch — all off by default); `preferences.json` supplies manual API keys/tokens per extension. Missing config fails closed: nothing is exposed.

Full reference, including every shim gate and environment variable: [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## n8n Integration

n8n supports MCP directly. Use an MCP client node pointed at `http://localhost:3000/mcp` with a Bearer token credential if `MCP_API_KEY` is set.

The included helper script is useful for local testing:

```bash
python3 scripts/call-raybridge.py list

python3 scripts/call-raybridge.py catalog --action search --query calendar

python3 scripts/call-raybridge.py catalog --action doctor

python3 scripts/call-raybridge.py catalog --action recommend --limit 10

python3 scripts/call-raybridge.py call \
  --mcp-tool your-extension \
  --raycast-tool your-tool \
  --input-json '{"query":"hello"}'
```

## Repo Layout

```text
raybridge/
├── src/
│   ├── index.ts
│   ├── http-server.ts
│   ├── cli.ts
│   ├── tui.tsx
│   ├── config.ts
│   ├── discovery.ts
│   ├── catalog.ts
│   ├── evals.ts
│   ├── loader.ts
│   ├── logging.ts
│   ├── shims.ts
│   ├── tool-worker.ts
│   ├── worker-executor.ts
│   ├── auth.ts
│   └── watcher.ts
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   ├── run-stdio.sh
│   ├── start-http.sh
│   ├── start-tunnel.sh
│   ├── check-keychain.sh
│   ├── call-raybridge.py
│   └── verify.sh
├── config/
│   └── examples/
├── docs/
├── Brewfile
├── CLAUDE.md
├── AGENTS.md
└── README.md
```

## Keeping the Fork Current

```bash
git fetch upstream
git merge upstream/main
git push origin main
```

That keeps your local setup assets in your fork while still letting you pull changes from the upstream RayBridge project.

## Troubleshooting

**`Operation not permitted` in Claude Desktop or another GUI MCP client**

macOS Sequoia can apply `com.apple.provenance` to shell scripts originating from `~/Downloads`, and that metadata can survive copies and clones. Sandboxed GUI apps may refuse to execute those scripts. Fix: use `/opt/homebrew/bin/bun` directly and pass the absolute path to `src/index.ts`. Do not put a wrapper script in the launch chain.

**`bun: command not found` or the server exits immediately**

GUI apps usually do not inherit your shell's full `PATH`. Use the absolute command `/opt/homebrew/bin/bun` and include a `PATH` value in the MCP config `env` block.

**`error: Module not found "src/index.ts"`**

Your MCP client launched Bun from a directory that is not the repo root. Fix: pass an absolute path to `src/index.ts` in `args` instead of relying on `cwd` or relative paths.

**RayBridge registers 0 tools**

Your installed Raycast extensions may not define AI tools yet. Run the discovery command above or follow [docs/finding-extensions.md](docs/finding-extensions.md).

**Startup hangs on first run**

macOS may be waiting on Keychain access to Raycast's `database_key`. Approve the prompt for your terminal app, then re-run the server.

## Credits

- [RayBridge](https://github.com/jlokos/raybridge) by Justin Lokos
- [Model Context Protocol](https://modelcontextprotocol.io/)

## License

MIT
