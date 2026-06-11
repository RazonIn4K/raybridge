# RayBridge Architecture & Decision Documentation

Consolidated reference for what RayBridge is, how it executes tools, the reasoned resolution of 20 architectural/behavioral/historical/environmental unknowns, and the cleanup plan for the current working tree.

Core value proposition, stated up front: **RayBridge converts locally installed Raycast extensions into MCP tools so that ANY MCP-capable AI client, running any model, can invoke them from non-Raycast apps.**

```text
Non-Raycast MCP client (any model) → RayBridge (stdio/HTTP) → Raycast extension tool → result
```

Key principle: RayBridge is MODEL-AGNOSTIC. It serves tools over MCP; it does not run, select, or route models. Model choice happens entirely on the client side.

All line references are against the current working tree (post schema-flattening, see §6).

---

## 1. RayBridge Primer

RayBridge is an MCP (Model Context Protocol) server, written in TypeScript and run with Bun, that bridges locally installed Raycast Store extensions to MCP clients. Extensions you already installed and authenticated inside Raycast become callable tools in Claude Desktop, Claude Code, Codex, ChatGPT web, or any other MCP-speaking app.

**Input.** Raycast extensions on disk at `~/.config/raycast/extensions/`. An extension qualifies when its `package.json` declares a `tools` array (`src/discovery.ts:49-50`). Raycast's built-in native features (clipboard history, calculator, app launcher) are not extensions and are not exposed.

**Output.** MCP `ListTools` and `CallTool` responses over stdio (primary, default) or Streamable HTTP (secondary, behind `--http`/`MCP_HTTP`). Each enabled extension is registered as one MCP tool whose `{tool_name, input}` arguments select the inner Raycast tool (`src/index.ts:41-69`). A built-in `raybridge` catalog tool (`src/catalog.ts:7,48`) provides summary/search/detail/config/doctor/recommend introspection.

**Execution.** Tool calls run the extension's compiled `tools/<name>.js` in a fresh, short-lived Bun worker process (`src/worker-executor.ts`), with a shimmed `@raycast/api` module injected via the module cache (`src/shims.ts:714-771`). Extensions are loaded and shimmed, never rewritten. OAuth tokens and preferences are read directly from Raycast's encrypted SQLite database using the macOS Keychain key plus Raycast's salt (`src/auth.ts:33-46`), so existing Raycast logins work without re-authentication.

**Safety model.** A config at `~/.config/raybridge/tools.json` gates everything: allowlist mode by default, nothing exposed unless enabled, and risky Raycast API surfaces (clipboard, system actions, trash, AppleScript, command launch) individually disabled by default (`src/config.ts:39-51`). If the config file is missing, RayBridge falls back to an empty allowlist rather than exposing everything (`src/config.ts:127-134`).

**Constraint.** macOS-only in practice: Keychain, sqlcipher, `pbcopy`/`pbpaste`, `osascript`, and Raycast's own file layout are all assumed. Extensions whose tools do background work (API calls, lookups, transformations) work best; UI-centric extensions run against auto-stubs and may return nothing useful.

*(~330 words)*

---

## 2. Model Compatibility

**RayBridge works with ANY MCP-capable client and any model**, because it only implements the MCP server protocol: a `ListTools` handler and a `CallTool` handler (`src/index.ts:166-260`). It makes no assumptions about which model is on the other end. There is no LLM call anywhere in the codebase; the Raycast `AI.ask` API is a compatibility shim that resolves to an empty string while preserving Raycast's Promise + EventEmitter shape (`src/shims.ts`).

Compatible clients include:

- Claude Desktop, Claude Code (stdio)
- Codex CLI / IDE (stdio)
- ChatGPT web and other remote clients (Streamable HTTP + Bearer auth)
- Continue, Cline, opencode, n8n's MCP Client Tool node
- Custom Python/Node MCP clients (see `scripts/call-raybridge.py`)
- Any future MCP-speaking app

"Using any available model" is a CLIENT-side capability:

- If your client supports a model picker (multi-model routers, OpenRouter-backed clients, etc.), you can switch models freely while still calling RayBridge tools.
- RayBridge does not need changes to support new models. They connect through the same MCP interface.
- One real compatibility constraint exists at the schema level, not the model level: extension input schemas are intentionally flat (no top-level `oneOf`/`anyOf`/`allOf`), because OpenAI-compatible function-calling providers reject those and refuse to load the tool (`src/index.ts:44-49`). This widens client compatibility rather than narrowing it.

What RayBridge does NOT do: it does not call an LLM, embed a model, or route between providers. If you want multi-model routing, that belongs in your MCP client or a separate gateway (an MCP-aware router), not in RayBridge.

Boundary to preserve in all future docs and code: **RayBridge = tools, client = models.**

Raycast AI API compatibility note: `AI.ask(prompt, options)` keeps the documented Promise + EventEmitter surface, and `AI.Model`/`AI.Creativity` exist for option-building compatibility. The shim never sends prompts to Raycast Pro or to a third-party model provider.

---

## 3. Architecture Decision Matrix

Twenty unknowns resolved with reasoned decisions. Defaults applied: stdio MCP prioritized; worker isolation required; allowlist + safe config; auto-stubbing acceptable except for safety-critical APIs; tests local-OK while CI aspires to hermetic.

### Architectural (6)

| # | Unknown | Recommended answer | Reasoning | Implications | Code ref |
|---|---------|--------------------|-----------|--------------|----------|
| A1 | Primary transport: stdio or HTTP? | stdio is the supported default; HTTP is secondary | stdio is what local clients (Claude Desktop/Code, Codex) launch; HTTP exists for remote clients and is lazily imported only when requested | Docs, examples, and testing prioritize stdio; HTTP changes must not regress stdio startup | `src/index.ts:450-463` (stdio branch), `src/index.ts:431` (lazy HTTP import) |
| A2 | One MCP tool per extension or per Raycast tool? | One MCP tool per extension, inner dispatch via `tool_name` enum + free-form `input` | Keeps the ListTools surface small (N extensions + 1 catalog tool), and the flat schema loads on OpenAI-compatible providers that reject top-level `oneOf`/`anyOf` | Per-tool parameter docs live in the tool description text; clients must read descriptions to populate `input` correctly | `src/index.ts:41-69`, NOTE at `src/index.ts:44-49`, lookup at `src/index.ts:148-153` |
| A3 | Worker isolation or in-process execution? | Worker isolation is required by default; in-process is debug-only | Fresh Bun process per call keeps extension module state, shim mutations, crashes, and leaks out of the long-lived server | Per-call process spawn cost accepted as the price of isolation; `RAYBRIDGE_IN_PROCESS=true` documented as debug-only, never for production | `src/index.ts:222-242`, `src/worker-executor.ts:70-76` |
| A4 | How to provide `@raycast/api`: rewrite extensions or shim the module? | Shim via `require.cache` injection plus `Module._resolveFilename` patch; never rewrite extension code | Extensions stay byte-identical to what Raycast installed, so updates keep working; shim owns the compatibility surface | Shim must track Raycast API evolution; React/JSX is also shimmed so UI imports don't crash | `src/shims.ts:714-771` (install), `src/shims.ts:720-732` (react shim), `src/loader.ts:11` |
| A5 | Auto-stub unknown API exports or fail hard? | Auto-stub by heuristic, except safety-critical APIs which are explicit and config-gated | Heuristics (PascalCase → UI/enum stub, lowercase → no-op fn) keep unknown imports from crashing tools; anything that touches the system (clipboard, open, trash, AppleScript, launch) is explicitly implemented behind `assertShimEnabled` | New Raycast APIs degrade gracefully instead of breaking; gated APIs throw actionable errors naming the config flag | `src/shims.ts:111-129` (auto-stub), `src/shims.ts:217-223` (gate), `src/shims.ts:610-648` (explicit exports) |
| A6 | HTTP session model: shared server or per-session? | Per-session `Server` instance sharing one mutable `ServerContext`; 30-min idle expiry | StreamableHTTP requires a transport per session; sharing `ctx` means a reload updates every session at once | Sessions die after 30 idle minutes (clients must re-initialize); watcher notifications reach all live sessions via `getServers()` | `src/http-server.ts:132-154` (create), `src/http-server.ts:172-183` (expiry), `src/index.ts:434-448` |

### Behavioral (8)

| # | Unknown | Recommended answer | Reasoning | Implications | Code ref |
|---|---------|--------------------|-----------|--------------|----------|
| B1 | What happens when `tools.json` is missing or malformed? | Fall back to `SAFE_DEFAULT_CONFIG`: allowlist mode, empty extension list, all risky shims off | Fail-closed beats fail-open for a server that can reach OAuth'd services and the filesystem | A fresh install exposes only the `raybridge` catalog tool until the user enables extensions intentionally | `src/config.ts:39-51`, `src/config.ts:127-134` |
| B2 | Are OAuth tokens refreshed by RayBridge? | No. Read-only access to Raycast's DB; expiry is computed but refresh is delegated to Raycast | Implementing refresh would require client secrets and would race Raycast's own refresh logic | On `isExpired()`, tools fail with an auth error; the documented fix is to trigger the extension in Raycast to refresh, or use a PAT in `preferences.json` | `src/shims.ts:320-339` (getTokens/isExpired), `src/shims.ts:340-342` (setTokens no-op), `src/index.ts:250-254` (auth error guidance) |
| B3 | How is Raycast's live, encrypted DB read safely? | Copy DB + WAL/SHM to a unique temp dir per query, decrypt the copy with sqlcipher, retry transient errors 3x with backoff | Raycast writes to the DB while running; querying a snapshot avoids lock contention and corruption reads | Tokens are point-in-time snapshots; the watcher re-reads on DB change events | `src/auth.ts:80-151` (temp copy + retry), `src/auth.ts:125-128` (transient detection) |
| B4 | What bounds a runaway tool call? | 120s default timeout, SIGTERM then SIGKILL 500ms later; tunable via `RAYBRIDGE_TOOL_TIMEOUT_MS` | Workers are disposable, so killing is safe; 120s accommodates slow API-bound tools | Long-running tools need an env override; the orphaned-process window is at most 500ms | `src/worker-executor.ts:26` (default), `src/worker-executor.ts:85-96` (kill sequence) |
| B5 | How do runtime changes (new extension, config edit, re-auth) propagate? | fs watchers on 4 dirs with 1s debounce; context reloaded in place; clients notified via `tools/list_changed` only when the tool-name set changes | In-place `ctx` mutation updates all live sessions without reconnect; name-set comparison avoids notification spam when only descriptions/config change | No server restart needed for allowlist edits or Raycast re-auth; clients that ignore notifications still get fresh behavior on next call | `src/watcher.ts:12-123`, `src/index.ts:350-414` (reload, in-place update at 397-402) |
| B6 | Can secrets leak into logs? | No, by policy: all call logs pass through key-pattern and text-pattern redaction | Inputs and errors routinely contain Bearer tokens, API keys, cookies | `[CALL]`/`[ERR]` lines and error texts are redacted; new log sites must use `safeJsonPreview`/`redactText` | `src/logging.ts:1-46`, used at `src/index.ts:216,219,248` |
| B7 | Duplicate extension directories (re-installs)? | Keep the newest directory per extension name by mtime | Raycast leaves multiple versioned dirs; newest is the one Raycast actually runs | Stale dirs are ignored silently; `raybridge doctor` can surface config entries pointing at missing tools | `src/discovery.ts:73-91` |
| B8 | Invalid `tool_name` or unknown extension in a call? | Return `isError: true` text listing available tools, not a protocol error | Models recover better from descriptive tool results than from JSON-RPC failures | Clients see actionable "Available: …" text; no exceptions cross the MCP boundary | `src/index.ts:185-213` |

### Historical (3)

| # | Unknown | Recommended answer | Reasoning | Implications | Code ref |
|---|---------|--------------------|-----------|--------------|----------|
| H1 | Why were React/OpenTUI in dependencies, and can they be removed? | They power the interactive config TUI (`raybridge config`). The pending removal in the dirty `package.json` is NOT safe as-is | `src/tui.tsx` statically imports `react`, `@opentui/react`, `@opentui/core`; removing the deps breaks the TUI and `bun run typecheck` on a fresh install (it only appears to work now because node_modules still contains them) | Either keep the deps, or remove/replace the TUI in the same commit. Decision deferred; conservative default is to revert the package.json change (§6 option A) | `src/tui.tsx:3-6`, `src/cli.ts:113-119`, dirty `package.json` |
| H2 | Why was the input schema flattened (the dirty `src/index.ts`)? | Top-level `oneOf` variants were replaced with one flat object because OpenAI-compatible function-calling providers reject `oneOf`/`anyOf`/`allOf`/`enum`/`not` at the top level and refuse to load the tool | Verified against opencode routing to Copilot/OpenAI models; per-tool parameters remain documented in the description text | Commit this change (§6); never reintroduce top-level combinators; real diff is 8+/43- once CRLF noise is stripped | `src/index.ts:44-49` (NOTE), `git diff --ignore-all-space` |
| H3 | Why does this fork carry installer scripts/docs/config that also exist in raycast-mcp-starter-kit? | Deliberate consolidation: the fork is the canonical working tree; the starter kit remains only as a public installer pointing at upstream | One repo to maintain for personal use; kit assets were adapted (paths point at the repo instead of cloning to `~/raybridge`) | The local starter-kit checkout is deletable once its unique files (AGENTS.md, issue templates — now copied) are committed here | `README.md` ("What this repo is"), `git remote -v` (origin=RazonIn4K, upstream=jlokos) |

### Environmental (3)

| # | Unknown | Recommended answer | Reasoning | Implications | Code ref |
|---|---------|--------------------|-----------|--------------|----------|
| E1 | Is RayBridge portable off macOS? | No. Treat as macOS-only; Windows exists only as an experimental upstream branch | Keychain (`security`), sqlcipher'd Raycast DB path, `pbcopy`/`pbpaste`, `osascript`, and `~/Library` layout are hard dependencies | Don't accept Linux/Windows bug reports against main; portability work tracks `experimental/windows-support` | `src/auth.ts:33-46,70-78`, `src/shims.ts:232-240,468-477` |
| E2 | Why shell out to the sqlcipher CLI instead of a native module? | CLI keeps the Bun runtime free of native bindings and matches Homebrew distribution | Native sqlcipher bindings are fragile across Bun versions; the CLI is resolved from candidates or `SQLCIPHER_BIN` | sqlcipher is a hard install prerequisite (Brewfile); errors are actionable ("install it or set SQLCIPHER_BIN") | `src/auth.ts:8-14,52-68` |
| E3 | Why do client configs require absolute `/opt/homebrew/bin/bun` and an absolute entrypoint? | GUI apps launch MCP servers with a minimal PATH, and macOS Sequoia's `com.apple.provenance` xattr (inherited from ~/Downloads, surviving copies and clones) makes sandboxed apps refuse to execute wrapper scripts | Direct binary + absolute `src/index.ts` path sidesteps both failure classes | Never put a shell-script wrapper in the launch chain; keep `PATH` in the config `env` block | `README.md` (Why direct Bun is the default; Troubleshooting), `config/examples/claude-desktop.json` |

---

## 4. Operational Reference

### Startup modes

| Mode | How | Notes |
|------|-----|-------|
| stdio (default, primary) | `bun run src/index.ts` | What Claude Desktop/Code and Codex launch. Watcher starts; server connects over stdio (`src/index.ts:450-463`) |
| HTTP (secondary) | `--http` flag or `MCP_HTTP=true`; `MCP_HOST`/`MCP_PORT` or `--host`/`--port` | Logs a WARNING if `MCP_API_KEY` is unset (`src/index.ts:420-424`). Endpoints: `GET /health`, `POST /mcp`, `DELETE /mcp`. Body cap `MCP_MAX_BODY_SIZE` (default 1mb) |
| In-process (debug only) | `RAYBRIDGE_IN_PROCESS=true` | Skips worker isolation (`src/index.ts:222-229`). Never use for normal operation |

Startup sequence (`loadServerContext`, `src/index.ts:290-344`): discover extensions + load manual prefs + load tools.json in parallel → apply shim gates → merge Raycast DB prefs (manual prefs win, `src/index.ts:300-315`) → load OAuth tokens → filter by allowlist → build tool defs → log `Registered N extensions (M tools total)`.

### Tool invocation flow (stdio CallTool), with failure modes

1. **Client sends CallTool** with `name=<extension>`, `arguments={tool_name, input}`.
   *Failure:* client schema rejection — only possible if a top-level combinator schema regresses (see H2). *Detect:* tool never appears or client refuses to load it.
2. **Catalog branch.** `name == "raybridge"` routes to the built-in catalog tool (`src/index.ts:177-183`).
   *Failure:* none destructive; bad action returns usage text.
3. **Validate `tool_name`** (`src/index.ts:185-195`).
   *Failure:* missing → `isError` text listing available extensions. *Detect:* response text starts with `Missing required parameter "tool_name"`.
4. **Lookup `<extension>:<tool_name>`** (`src/index.ts:197-213`).
   *Failure:* unknown tool/extension → `isError` text with available tools. *Detect:* `Unknown tool ... Available: ...`.
5. **Spawn worker**: fresh Bun process running `tool-worker.ts`; payload (jsPath, input, prefs, tokens, shim gates) written to stdin (`src/worker-executor.ts:70-76,149`).
   *Failure:* bun executable missing → spawn `error` event. *Detect:* stderr `[ERR]` with ENOENT; check `BUN_EXECUTABLE`.
6. **Worker hydrates state and loads the tool**: `setShimConfig/setPreferences/setRaycastTokens` (`src/tool-worker.ts:42-44`), `installShims()` then `require(jsPath)` with cache-bust (`src/loader.ts:11-32`).
   *Failure:* module load error → `Failed to load tool at <path>`; non-function export → `does not export a function`. *Detect:* error text names the jsPath; run `raybridge` catalog `doctor` for missing tool files.
7. **Tool executes** against the shimmed `@raycast/api`.
   *Failure (gated API):* `Raycast API <name> is disabled in RayBridge. Enable raycastApi.<flag> ...` (`src/shims.ts:217-223`). *Failure (auth):* expired/missing token → error matching the auth regex.
8. **Worker replies** on stdout as one line: `__RAYBRIDGE_TOOL_RESULT__:<base64 JSON>` (`src/tool-worker.ts:24,34-37`); parent parses the last matching line (`src/worker-executor.ts:41-53`).
   *Failure:* no result line → `Tool worker exited without a result (code N)` with stdout/stderr previews; garbage → `invalid result`. *Detect:* previews in the error text.
9. **Timeout guard**: 120s default → SIGTERM, then SIGKILL after 500ms (`src/worker-executor.ts:85-96`).
   *Failure:* `Tool worker timed out after Nms`. *Detect/fix:* raise `RAYBRIDGE_TOOL_TIMEOUT_MS`.
10. **Server formats the response** (`src/index.ts:243-259`): success → text content + `[OK]` log with duration; error → redacted message; auth-pattern errors get the OAuth guidance block (re-auth in Raycast, or PAT in `~/.config/raybridge/preferences.json`).
    *Detect:* stderr lines `raybridge: [CALL]/[OK]/[ERR] ext/tool (Nms)`.

Cross-cutting detection: stdio logs go to stderr (visible in Claude Desktop MCP logs); HTTP mode adds `GET /health` returning `{status, sessions, extensions, tools}`.

### Connecting common MCP clients over stdio

Claude Desktop (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "raybridge": {
      "command": "/opt/homebrew/bin/bun",
      "args": ["run", "/Users/you/Git-Projects/raybridge/src/index.ts"],
      "env": { "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" }
    }
  }
}
```

Claude Code: `claude mcp add --transport stdio raybridge -- /opt/homebrew/bin/bun run "$HOME/Git-Projects/raybridge/src/index.ts"`
Codex: `codex mcp add raybridge -- /opt/homebrew/bin/bun run "$HOME/Git-Projects/raybridge/src/index.ts"`

Rules that prevent 90% of setup failures: absolute bun path, absolute entrypoint path, `PATH` in env, no wrapper scripts (see E3).

---

## 5. Documentation Checklist

Priority 1 (done 2026-06):

- [x] `README.md` — documentation index added; configuration section trimmed to a pointer
- [x] `docs/ARCHITECTURE.md` — execution flow + component map (§1, §4 here; diagrams from `docs/internal/RAYBRIDGE_VISUAL.md`)
- [x] `docs/DECISIONS.md` — the decision matrix as a living ADR list (§3 here)
- [x] `docs/CONFIGURATION.md` — tools.json modes, all six `raycastApi` gates, env vars, preferences.json
- [x] `docs/MODEL_COMPATIBILITY.md` — §2, plus the Raycast AI shim compatibility note (upstream PR #8)

Priority 2 (done 2026-06):

- [x] `docs/TESTING.md` — six bun suites + typecheck via `verify:repo`, fixtures, execute-mode caveats, hermetic-CI candidates
- [x] `docs/TROUBLESHOOTING.md` — README troubleshooting + §4 failure modes, organized by symptom
- [x] `docs/HTTP_DEPLOYMENT.md` — session/auth model (A6) + tunnels + security checklist; `chatgpt-setup.md` and `infrastructure.md` kept as deep-dive references

Priority 3 (done 2026-06):

- [x] `docs/EXTENSION_COMPAT.md` — four compatibility tiers, full shim coverage table, per-extension checking commands
- [x] `docs/SHODAN_APIFY.md` — normalizer CLI, ownership inventory, five Zen workflows, hermetic test note

---

## 6. Completed Code Cleanup Record

This section is a historical record of the cleanup sequence that was completed in the commits after `3136d4c`; it is not the current working-tree state. Current status should always be checked with `git status --short --branch` and `git log --oneline --decorate -n 8`.

Original verified state: `main` = `origin/main` @ 3136d4c, ahead of `upstream/main` (429ad9e). Modified: `package.json`, `src/index.ts`. Untracked: `.github/`, `.vscode/`, `AGENTS.md`, `OPTIMIZATION_PLAN.md`, `RAYBRIDGE_ANALYSIS.md`, `RAYBRIDGE_VISUAL.md`, `README_OPTIMIZED.md`, `doppler.yaml`. Already ignored: `shim-test-results.json`, `test-audit/`, `*.log`, `*.pid`, `.DS_Store`, `node_modules/`.

At that point, `src/index.ts` had CRLF line endings, so its 367-line diff was mostly line-ending noise. The real change was the schema flattening: 8 insertions, 43 deletions under `git diff --ignore-all-space`.

```bash
cd ~/Git-Projects/raybridge

# 0. Baseline: confirmed tests pass before touching anything
bun run verify:repo

# 1. Strip CRLF noise from index.ts so the commit shows only the real change
perl -pi -e 's/\r\n/\n/g' src/index.ts
git diff --stat src/index.ts        # expect ~8 insertions, 43 deletions

# 2. Commit the schema flattening on its own
git add src/index.ts
git commit -m "Flatten extension input schema for OpenAI-compatible clients"

# 3. package.json (React/OpenTUI removal) — pick ONE:
# Option A (recommended until a TUI decision is made): revert the removal.
#   src/tui.tsx imports react/@opentui/*; removing them breaks `raybridge config`
#   and `bun run typecheck` on any fresh `bun install`.
git checkout -- package.json
# Option B: keep the removal AND retire the TUI in the same commit:
#   git rm src/tui.tsx && <replace cli.ts "config" case with a non-TUI editor>
#   git add package.json src/cli.ts && bun install && git add bun.lockb
#   git commit -m "Remove OpenTUI config interface and its dependencies"

# 4. Commit the carried-over agent/docs assets
mkdir -p docs/internal
mv RAYBRIDGE_ANALYSIS.md OPTIMIZATION_PLAN.md RAYBRIDGE_VISUAL.md README_OPTIMIZED.md docs/internal/
git add docs/internal docs/ARCHITECTURE_AND_DECISIONS.md AGENTS.md .github
git commit -m "Add agent guidance, issue templates, and internal analysis docs"

# 5. Keep machine-local files out of git
printf '\n# Machine-local\n.vscode/\ndoppler.yaml\n' >> .gitignore
git add .gitignore
git commit -m "Ignore machine-local editor and Doppler config"

# 6. Prevent CRLF recurrence (optional but recommended)
printf '*.ts text eol=lf\n*.tsx text eol=lf\n' >> .gitattributes
git add .gitattributes && git commit -m "Normalize line endings for TypeScript sources"

# 7. Re-verify, then push
bun run verify:repo
git push origin main
```

Notes:

- Per repo conventions (`CLAUDE.md`), these are small logical commits and can land on `main`; anything larger (e.g., the Option B TUI replacement) belongs on a `feat/` branch.
- `doppler.yaml` stays untracked because secrets-manager wiring is machine-specific; if the team standardizes on Doppler later, commit it deliberately.
- Old working branches (`feat/worker-catalog-logging`, `review/pr4-feedback-*`, `integrate/all-raybridge-prs-*`) are merged or stale; prune with `git branch -d <name>` and `git push origin --delete <name>` after confirming with `git branch --merged main`.
