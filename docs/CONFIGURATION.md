# Configuration

All user configuration lives under `~/.config/raybridge/`. RayBridge fails closed: with no config present, nothing is exposed except the built-in `raybridge` catalog tool.

## Files

| Path | Purpose |
|------|---------|
| `~/.config/raybridge/tools.json` | Which extensions/tools are exposed; shim gates |
| `~/.config/raybridge/preferences.json` | Manual API keys/tokens per extension (overrides Raycast DB prefs) |
| `~/.config/raybridge/local-storage/<ext>.json` | Persisted `LocalStorage` per extension (only when enabled) |

Edit `tools.json` by hand or with the TUI: `raybridge config` (or `bun run config`).

## tools.json

```json
{
  "mode": "allowlist",
  "raycastApi": {
    "enableLocalStorage": true,
    "enableClipboard": false,
    "enableSystemActions": false,
    "enableDestructiveSystemActions": false,
    "enableAppleScript": false,
    "enableCommandLaunch": false
  },
  "extensions": {
    "github": { "enabled": true },
    "slack": { "enabled": true, "tools": ["send-message", "search-messages"] }
  }
}
```

- `mode: "allowlist"` (recommended): everything disabled unless `enabled: true`
- `mode: "blocklist"`: everything enabled unless `enabled: false`
- Per-extension `tools` array further restricts to specific tool names; extensions left with zero tools are dropped
- Missing or malformed file → safe defaults (allowlist, empty, all gates off except LocalStorage) (`src/config.ts:39-51,127-134`)

## raycastApi shim gates

Risky Raycast APIs are individually gated (`src/shims.ts:207-213`). A disabled gate throws an actionable error naming the flag.

| Flag | Default | Enables |
|------|---------|---------|
| `enableLocalStorage` | `true` | `LocalStorage` persistence under `~/.config/raybridge/local-storage/` |
| `enableClipboard` | `false` | `Clipboard.readText/copy/clear` via `pbpaste`/`pbcopy` |
| `enableSystemActions` | `false` | `open`, `showInFinder` |
| `enableDestructiveSystemActions` | `false` | `trash` (Finder delete). Keep off unless a tool explicitly needs it |
| `enableAppleScript` | `false` | `runAppleScript`, `getSelectedText`*, `getSelectedFinderItems`, `getFrontmostApplication`, `Clipboard.paste` |
| `enableCommandLaunch` | `false` | `launchCommand` via `raycast://` deep links |

\* `getSelectedText` additionally requires `enableClipboard` (`src/shims.ts:470-486`).

Each gate has an environment override that beats the config file (`src/shims.ts:25-59`): `RAYBRIDGE_ENABLE_LOCAL_STORAGE`, `RAYBRIDGE_ENABLE_CLIPBOARD`, `RAYBRIDGE_ENABLE_SYSTEM_ACTIONS`, `RAYBRIDGE_ENABLE_DESTRUCTIVE_SYSTEM_ACTIONS`, `RAYBRIDGE_ENABLE_APPLESCRIPT`, `RAYBRIDGE_ENABLE_COMMAND_LAUNCH` (values: `1/true/yes/on`).

## preferences.json

For extensions that need API keys or personal tokens outside Raycast's OAuth:

```json
{
  "extension-name": {
    "personalAccessToken": "your-token",
    "apiKey": "your-key"
  }
}
```

Keys match the extension's `package.json` `name`. Manual values override preferences read from Raycast's DB (`src/index.ts:300-315`).

## Environment variables

| Variable | Default | Effect |
|----------|---------|--------|
| `MCP_HTTP` | unset | `true` starts HTTP mode (same as `--http`) |
| `MCP_HOST` / `MCP_PORT` | `127.0.0.1` / `3000` | HTTP bind address (also `--host`/`--port`) |
| `MCP_API_KEY` | unset | Bearer token for `/mcp`; unset logs a WARNING and serves unauthenticated |
| `MCP_MAX_BODY_SIZE` | `1mb` | Max JSON body for `/mcp` |
| `RAYBRIDGE_TOOL_TIMEOUT_MS` | `120000` | Worker timeout per tool call |
| `RAYBRIDGE_IN_PROCESS` | unset | `true` disables worker isolation (debug only) |
| `RAYBRIDGE_ENABLE_*` | unset | Shim gate overrides (see table above) |
| `SQLCIPHER_BIN` | auto-detect | Path to sqlcipher if not in standard Homebrew locations |
| `BUN_EXECUTABLE` | auto | Bun binary used to spawn workers when the server isn't running under Bun |

## Live reload

`tools.json` and `preferences.json` edits, extension installs/updates, and Raycast re-auth are picked up automatically (fs watchers, 1s debounce) without restarting the server. See [ARCHITECTURE.md](ARCHITECTURE.md) "Reload model".
