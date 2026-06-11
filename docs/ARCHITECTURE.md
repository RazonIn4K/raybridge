# Architecture

RayBridge is an MCP server (TypeScript, run with Bun) that bridges locally installed Raycast Store extensions to MCP clients. Extensions you installed and authenticated inside Raycast become callable tools in any MCP-speaking app. Design rationale for everything here lives in [DECISIONS.md](DECISIONS.md).

```text
Non-Raycast MCP client (any model) → RayBridge (stdio/HTTP) → Raycast extension tool → result
```

## Component map

| File | Responsibility |
|------|----------------|
| `src/index.ts` | Entry point. Builds the server context, registers `ListTools`/`CallTool` handlers, dispatches calls, parses CLI args, selects stdio vs HTTP |
| `src/discovery.ts` | Scans `~/.config/raycast/extensions/` for `package.json` files with a `tools` array; dedupes to the newest copy per extension |
| `src/config.ts` | Loads/normalizes `~/.config/raybridge/tools.json`; allowlist/blocklist filtering; safe fail-closed defaults |
| `src/auth.ts` | Reads OAuth tokens and extension preferences from Raycast's encrypted SQLite DB (Keychain key + salt → sqlcipher over a temp copy) |
| `src/shims.ts` | Fake `@raycast/api` (and React) injected into the module cache: explicit implementations for critical APIs, config gates for risky ones, auto-stubs for the rest |
| `src/loader.ts` | Installs shims, cache-busts, and `require()`s the extension's compiled tool file |
| `src/worker-executor.ts` | Spawns a fresh Bun worker per tool call; stdin payload, base64 result line, 120s timeout with SIGTERM/SIGKILL |
| `src/tool-worker.ts` | Worker entry: hydrates prefs/tokens/gates, executes the tool, emits `__RAYBRIDGE_TOOL_RESULT__:<base64>` |
| `src/http-server.ts` | Express + StreamableHTTP transport: `/health`, `/mcp`, Bearer auth, per-session servers, 30-min idle reaping |
| `src/watcher.ts` | fs watchers (extensions dir, Raycast DB dir, raybridge config, legacy config) with 1s debounce → context reload → `tools/list_changed` |
| `src/catalog.ts` | Built-in `raybridge` MCP tool: summary/search/detail/config/doctor/recommend |
| `src/evals.ts` | Formats extension `ai.evals` into usage examples appended to tool descriptions |
| `src/logging.ts` | Secret redaction (`redactText`, `safeJsonPreview`) for all call logging |
| `src/cli.ts` / `src/tui.tsx` | `raybridge` CLI (`config`, `list`, `help`) and the OpenTUI-based allowlist editor |

## Startup sequence

`loadServerContext()` (`src/index.ts:290-344`):

1. In parallel: discover extensions, load manual `preferences.json`, load `tools.json`
2. Apply shim gates from config (env vars can override, see [CONFIGURATION.md](CONFIGURATION.md))
3. Merge preferences from Raycast's DB (manual prefs win)
4. Load OAuth tokens from Raycast's DB
5. Filter extensions through allowlist/blocklist
6. Build tool defs: one MCP tool per extension + the `raybridge` catalog tool
7. Log `Registered N extensions (M tools total)`; start watchers; connect transport

## Tool invocation flow

```mermaid
sequenceDiagram
    participant C as MCP client
    participant S as RayBridge server
    participant W as Bun worker
    participant E as Extension tool.js
    participant X as External service

    C->>S: CallTool(extension, {tool_name, input})
    S->>S: catalog? validate tool_name; lookup
    S->>W: spawn bun tool-worker.ts, payload on stdin
    W->>W: install @raycast/api shims, hydrate tokens/prefs/gates
    W->>E: require(tools/<name>.js), fn(input)
    E->>X: API call (OAuth token from Raycast DB)
    X-->>E: response
    E-->>W: result
    W-->>S: __RAYBRIDGE_TOOL_RESULT__:<base64 JSON>
    S-->>C: text content (redacted on error)
```

Numbered failure modes for every step are in [ARCHITECTURE_AND_DECISIONS.md](ARCHITECTURE_AND_DECISIONS.md) §4; symptom-first guidance will live in `docs/TROUBLESHOOTING.md`.

Key properties:

- **Isolation:** each call runs in a disposable process; crashes and module state never touch the server (`src/worker-executor.ts`)
- **Timeout:** 120s default, then SIGTERM → SIGKILL(+500ms); `RAYBRIDGE_TOOL_TIMEOUT_MS` overrides
- **Auth:** tokens are read-only snapshots of Raycast's DB; expired tokens mean re-trigger the extension in Raycast or use a PAT
- **Errors:** invalid `tool_name`/extension return descriptive `isError` text; auth-pattern errors append OAuth guidance (`src/index.ts:246-259`)
- **Logging:** stderr lines `raybridge: [CALL]/[OK]/[ERR] ext/tool (Nms)`, always redacted

## Transports

| | stdio (primary) | HTTP (secondary) |
|---|---|---|
| Start | `bun run src/index.ts` | `--http` or `MCP_HTTP=true` (+ `MCP_API_KEY`) |
| Session | single server over stdin/stdout | per-session `Server` via StreamableHTTP, `Mcp-Session-Id` header |
| Auth | OS process boundary | Bearer token (timing-safe compare) |
| Lifecycle | client owns process | 30-min idle expiry, `DELETE /mcp` to terminate |
| Health | stderr logs | `GET /health` → `{status, sessions, extensions, tools}` |

Both share the same `ServerContext`; the watcher reloads it in place and notifies every connected server when the tool set changes.

## Reload model

Watched: `~/.config/raycast/extensions/` (package.json + tools files), Raycast's Application Support dir (DB changes, i.e. re-auth), `~/.config/raybridge/` and legacy `~/.config/ray-ai-tools/` (config edits). Debounce 1s. Reload rebuilds extensions/tools/prefs/tokens in the existing context object so live sessions pick it up immediately; `notifications/tools/list_changed` is sent only when tool names actually change (`src/index.ts:392-405`).
