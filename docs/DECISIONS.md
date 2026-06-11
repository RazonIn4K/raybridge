# Decisions

Living ADR list. Each entry: decision, why, consequences, code refs. All entries below are **Accepted** as of 2026-06. Full reasoning tables live in [ARCHITECTURE_AND_DECISIONS.md](ARCHITECTURE_AND_DECISIONS.md) §3.

## Architectural

**AD-1: stdio is the primary transport; HTTP is secondary.**
Local clients launch stdio; HTTP serves remote clients and is lazily imported. HTTP changes must never regress stdio startup. Refs: `src/index.ts:450-463`, `src/index.ts:431`.

**AD-2: One MCP tool per extension, inner dispatch via `tool_name` + `input`.**
Keeps the ListTools surface small and the schema flat enough for OpenAI-compatible providers. Per-tool parameters are documented in the tool description text. Refs: `src/index.ts:41-69`.

**AD-3: Worker isolation is required by default; in-process is debug-only.**
A fresh Bun process per call keeps extension state, shim mutations, crashes, and leaks out of the server. `RAYBRIDGE_IN_PROCESS=true` is never for production. Refs: `src/index.ts:222-242`, `src/worker-executor.ts:70-76`.

**AD-4: Provide `@raycast/api` by shimming the module cache, never by rewriting extensions.**
Extensions stay byte-identical to what Raycast installed. The shim owns the compatibility surface (React/JSX included). Refs: `src/shims.ts:714-771`, `src/loader.ts:11`.

**AD-5: Auto-stub unknown API exports; gate safety-critical APIs explicitly.**
Heuristic stubs keep unknown imports from crashing tools; clipboard/open/trash/AppleScript/launch are explicit implementations behind `assertShimEnabled`. Refs: `src/shims.ts:111-129`, `src/shims.ts:217-223`.

**AD-6: HTTP uses per-session `Server` instances sharing one mutable `ServerContext`, 30-min idle expiry.**
A reload updates every session at once; idle sessions are reaped. Refs: `src/http-server.ts:132-154`, `src/http-server.ts:172-183`.

## Behavioral

**BD-1: Missing/malformed `tools.json` fails closed.**
Allowlist mode with an empty extension list and all risky shims off. Refs: `src/config.ts:39-51`, `src/config.ts:127-134`.

**BD-2: RayBridge never refreshes OAuth tokens.**
Read-only snapshots from Raycast's DB; refresh is Raycast's job. Auth errors point users to re-trigger the extension in Raycast or use a PAT in `preferences.json`. Refs: `src/shims.ts:320-342`, `src/index.ts:250-254`.

**BD-3: Raycast's live DB is read via temp-copy + sqlcipher + retries.**
Copy DB+WAL/SHM per query; retry transient lock/corruption errors 3x. Refs: `src/auth.ts:80-151`.

**BD-4: Tool calls are bounded at 120s (SIGTERM, then SIGKILL after 500ms).**
Tunable via `RAYBRIDGE_TOOL_TIMEOUT_MS`. Refs: `src/worker-executor.ts:26,85-96`.

**BD-5: Runtime changes propagate via fs watchers + in-place context reload.**
Clients get `tools/list_changed` only when the tool-name set changes; description/config changes apply silently on next call. Refs: `src/watcher.ts:12-123`, `src/index.ts:350-414`.

**BD-6: All call logs pass through secret redaction.**
New log sites must use `safeJsonPreview`/`redactText`. Refs: `src/logging.ts:1-46`, `src/index.ts:216,219,248`.

**BD-7: Duplicate extension directories resolve to the newest by mtime.**
Refs: `src/discovery.ts:73-91`.

**BD-8: Invalid `tool_name`/extension returns `isError` text listing alternatives, not a protocol error.**
Models recover better from descriptive tool results. Refs: `src/index.ts:185-213`.

## Historical

**HD-1: React/OpenTUI stay in dependencies while the config TUI exists.**
`src/tui.tsx` statically imports them and `raybridge config` launches it (`src/cli.ts:113-119`). Removing the deps requires retiring the TUI in the same change, on a `feat/` branch.

**HD-2: Extension input schemas are flat (no top-level combinators), permanently.**
OpenAI-compatible providers reject top-level `oneOf`/`anyOf`/`allOf`/`enum`/`not`. Refs: NOTE at `src/index.ts:44-49`.

**HD-3: This fork is the canonical working tree; the starter kit is only a public installer.**
Kit-unique assets (AGENTS.md, issue templates) were absorbed here. Refs: README "What this repo is".

## Environmental

**ED-1: macOS-only on main.**
Keychain, sqlcipher'd DB, `pbcopy`/`pbpaste`, `osascript`, `~/Library` layout are hard dependencies. Portability work tracks `experimental/windows-support`. Refs: `src/auth.ts:33-46`, `src/shims.ts:232-240`.

**ED-2: sqlcipher is consumed as a CLI, not a native module.**
Keeps Bun free of native bindings; resolved from candidates or `SQLCIPHER_BIN`. Refs: `src/auth.ts:8-14,52-68`.

**ED-3: Client configs use absolute `/opt/homebrew/bin/bun` + absolute entrypoint, no wrapper scripts.**
GUI apps have minimal PATH; macOS Sequoia `com.apple.provenance` blocks flagged scripts in sandboxed apps. Refs: README "Why direct Bun is the default".

## Adding a new decision

Append an entry with the next ID in its category, link the motivating issue/PR, and update `ARCHITECTURE_AND_DECISIONS.md` if the decision changes a documented behavior.
