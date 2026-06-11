# Troubleshooting

Organized by symptom. Line refs point at the code that produces each behavior; the full failure-mode walkthrough is in [ARCHITECTURE_AND_DECISIONS.md](ARCHITECTURE_AND_DECISIONS.md) §4.

## Where to look first

- stdio mode logs to **stderr**: `raybridge: [CALL]/[OK]/[ERR] <ext>/<tool> (Nms)`, always secret-redacted
- Claude Desktop surfaces those logs in `~/Library/Logs/Claude/mcp*.log`
- HTTP mode adds `GET /health` → `{status, sessions, extensions, tools}`
- `python3 scripts/call-raybridge.py catalog --action doctor` finds stale config entries, missing tool files, and risky enables

## Server won't start (or client never shows raybridge)

**"Operation not permitted" in the client's MCP log.** macOS Sequoia applies `com.apple.provenance` to scripts that ever lived in `~/Downloads` (it survives copies and clones), and sandboxed GUI apps refuse to execute them. Fix: launch `/opt/homebrew/bin/bun` directly with an absolute path to `src/index.ts`; no wrapper scripts in the chain.

**"bun: command not found" or instant exit.** GUI apps launch MCP servers with a minimal PATH that excludes Homebrew. Fix: absolute `command` path and a `PATH` entry in the config `env` block (see README step 3).

**`error: Module not found "src/index.ts"`.** The client launched bun from the wrong working directory. Fix: absolute entrypoint path in `args`; never rely on `cwd`.

**Startup hangs on first run.** macOS is waiting on Keychain approval for Raycast's `database_key` item. Approve with Always Allow for your terminal; if dismissed, grant it via Keychain Access.app. Until granted, token loading fails with a logged warning and OAuth-backed extensions won't authenticate (`src/auth.ts:33-46`).

## Server runs but registers 0 tools (or fewer than expected)

- No config file means fail-closed: allowlist mode with nothing enabled (`src/config.ts:127-134`). Copy `config/examples/tools-allowlist.json` to `~/.config/raybridge/tools.json` and enable extensions deliberately
- The extension may not define AI tools at all; only extensions with a `tools` array in `package.json` qualify (`src/discovery.ts:49-50`). See [finding-extensions.md](finding-extensions.md)
- A per-extension `tools` filter that matches nothing drops the whole extension (`src/config.ts:189`)
- Startup stderr says how many were disabled by config; `raybridge list` shows the filtered view

## A specific tool call fails

**`Missing required parameter "tool_name"` / `Unknown tool ... Available: ...`.** The calling model picked a bad inner tool. Available names are in the error text; the per-tool parameters are in the extension tool's description (`src/index.ts:185-213`).

**`Raycast API <name> is disabled in RayBridge. Enable raycastApi.<flag>...`.** Working as designed: the tool touched a gated API (`src/shims.ts:217-223`). Enable that flag in `tools.json` only if you trust the tool with it; see [CONFIGURATION.md](CONFIGURATION.md) for what each gate unlocks.

**OAuth error (401/403/invalid_grant/token...).** RayBridge reads tokens, it never refreshes them (decision BD-2). Fix: open Raycast and run any command of that extension so Raycast refreshes the token, then retry (the watcher re-reads the DB automatically). Alternative: a personal access token in `~/.config/raybridge/preferences.json`. The error text includes this guidance (`src/index.ts:250-254`).

**`Tool worker timed out after 120000ms`.** Slow API or hung tool. Raise `RAYBRIDGE_TOOL_TIMEOUT_MS`, or investigate the tool in isolation with `RAYBRIDGE_IN_PROCESS=true` (debug only).

**`Tool worker exited without a result (code N)`.** The extension crashed before emitting the result line; the error includes stdout/stderr previews (`src/worker-executor.ts:131-138`). Usually a missing preference/API key or an unshimmed API; check `doctor` and the previews.

**Spawn ENOENT.** The server couldn't find bun to spawn the worker. Set `BUN_EXECUTABLE` or fix PATH (`src/worker-executor.ts:32-34`).

## Tools list seems stale

Edits to `tools.json`, new extensions, and Raycast re-auth are picked up by watchers with a 1s debounce (`src/watcher.ts`). Clients receive `tools/list_changed` only when tool NAMES change; description/config-only changes apply silently on the next call (`src/index.ts:392-405`). If a client caches aggressively, toggle its MCP connection rather than restarting RayBridge.

## HTTP-specific

| Symptom | Cause / fix |
|---------|-------------|
| 401 `Invalid or missing Bearer token` | `MCP_API_KEY` set but client isn't sending `Authorization: Bearer <key>`; ChatGPT cannot send it, so run the no-auth flow for ChatGPT (`src/http-server.ts:91-101`) |
| 400 `Invalid request. Expected initialize request or valid session ID` | Session expired (30-min idle) or wrong/missing `Mcp-Session-Id`; re-initialize (`src/http-server.ts:120-170`) |
| 413 `MCP request body is too large` | Raise `MCP_MAX_BODY_SIZE` (default 1mb) |
| Tunnel "stream-canceled" log spam | Known cloudflared + ChatGPT SSE noise; calls generally succeed ([chatgpt-setup.md](chatgpt-setup.md)) |
| Remote client lost the server after a restart | Ephemeral tunnel URL rotated; use a named tunnel ([HTTP_DEPLOYMENT.md](HTTP_DEPLOYMENT.md)) |

## Diagnosing an extension that loads but does nothing useful

UI-centric extensions render against auto-stubs (`List`, `Detail`, `Form` return null), so a tool whose value is its UI returns nothing meaningful. Background-work tools (API calls, lookups, transformations) are the supported pattern. `bun run test:shims` verifies loadability across everything enabled; see [TESTING.md](TESTING.md).
