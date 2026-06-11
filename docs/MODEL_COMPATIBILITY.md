# Model Compatibility

**RayBridge works with ANY MCP-capable client and any model**, because it only implements the MCP server protocol: a `ListTools` handler and a `CallTool` handler (`src/index.ts:166-260`). It makes no assumptions about which model is on the other end. There is no LLM call anywhere in the codebase; the Raycast `AI.ask` API is a compatibility shim that resolves to an empty string while preserving Raycast's Promise + EventEmitter shape (`src/shims.ts`).

```text
Non-Raycast MCP client (any model) → RayBridge (stdio/HTTP) → Raycast extension tool → result
```

## Compatible clients

- Claude Desktop, Claude Code (stdio)
- Codex CLI / IDE (stdio)
- ChatGPT web and other remote clients (Streamable HTTP + Bearer auth)
- Continue, Cline, opencode, n8n's MCP Client Tool node
- Custom Python/Node MCP clients (see `scripts/call-raybridge.py`)
- Any future MCP-speaking app

## "Any model" is a client-side capability

- If your client supports a model picker (multi-model routers, OpenRouter-backed clients, etc.), you can switch models freely while still calling RayBridge tools.
- RayBridge does not need changes to support new models. They connect through the same MCP interface.
- One real compatibility constraint exists at the schema level, not the model level: extension input schemas are intentionally flat (no top-level `oneOf`/`anyOf`/`allOf`), because OpenAI-compatible function-calling providers reject those and refuse to load the tool (`src/index.ts:44-49`). This widens client compatibility rather than narrowing it. Do not reintroduce top-level combinators.

## What RayBridge does NOT do

It does not call an LLM, embed a model, or route between providers. If you want multi-model routing, that belongs in your MCP client or a separate gateway (an MCP-aware router), not in RayBridge.

Boundary to preserve in all docs and code: **RayBridge = tools, client = models.**

## Raycast AI API compatibility

Raycast's `AI.ask(prompt, options)` returns a Promise that is also an EventEmitter for streaming `"data"` events. RayBridge mirrors that runtime shape so installed extensions can load and execute outside Raycast, and exposes `AI.Model`/`AI.Creativity` constants for option-building compatibility. The shim deliberately does not send prompts to Raycast Pro, OpenAI, Anthropic, or any other model provider.
