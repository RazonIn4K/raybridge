# Extension Compatibility

RayBridge runs Raycast extension tools outside Raycast by injecting a fake `@raycast/api` (decision AD-4). How well a given tool works depends entirely on which parts of that API it touches. This doc explains what runs cleanly, what degrades, and how to check a specific extension.

## The one hard requirement

An extension is only discoverable if its `package.json` declares a `tools` array (`src/discovery.ts:49-50`). Extensions that only define `commands` (the classic user-facing kind) never appear. Discovery and authoring are covered in [finding-extensions.md](finding-extensions.md); this doc is about runtime behavior once a tool is discovered.

## Compatibility tiers

**Tier 1 — works fully (the supported case).** Tools that do background work: call an HTTP API, query a service, transform inputs, read files. They return data, not UI. These are exactly what the MCP tool model wants. GitHub, Linear, Slack, Notion, Jira-style extensions live here.

**Tier 2 — works with a config gate.** Tools that touch the local system through an explicitly implemented, gated API: clipboard, `open`/`showInFinder`, `trash`, AppleScript helpers, `launchCommand`. These run only when you enable the matching `raycastApi` flag in `tools.json`; otherwise they throw a descriptive error (`src/shims.ts:217-223`). Enable per [CONFIGURATION.md](CONFIGURATION.md) only when you trust the tool.

**Tier 3 — loads but returns nothing useful.** Tools whose product is a rendered Raycast UI (`List`, `Detail`, `Form`, `Grid`, `MenuBarExtra`). The shim auto-stubs these to return `null` (`src/shims.ts`), so the tool imports and runs but produces no meaningful result. A tool that builds a list for the user to pick from has no equivalent in a headless MCP call.

**Tier 4 — needs credentials first.** Tools backed by an API key or OAuth. OAuth flows reuse Raycast's stored tokens automatically (decision BD-2); key-based tools need an entry in `preferences.json` or they fail at call time. Not a compatibility defect, just setup.

## Shim coverage

What the fake `@raycast/api` provides (`src/shims.ts`):

| Surface | Behavior |
|---------|----------|
| `getPreferenceValues` | Merged Raycast-DB + manual `preferences.json` for the current extension |
| `OAuth.PKCEClient` | `getTokens()` returns Raycast's stored token; `setTokens`/`removeTokens` are no-ops (read-only) |
| `LocalStorage` | Persisted to `~/.config/raybridge/local-storage/<ext>.json` when `enableLocalStorage` is on |
| `Cache` | In-memory Map, per worker process (does not survive across calls) |
| `environment` | Synthetic values: `launchType: "background"`, assets/support paths, `canAccess: () => true` |
| `Clipboard`, `open`, `showInFinder`, `trash`, AppleScript helpers, `launchCommand` | Real implementations behind config gates |
| `AI.ask` | Promise + EventEmitter compatibility shim resolving to `""`; `AI.Model`/`AI.Creativity` constants (upstream PR #8). Never calls a model |
| UI components (`List`, `Detail`, `Form`, ...) | Auto-stubbed to render nothing |
| Any other export | Auto-stubbed: PascalCase → enum/UI proxy, lowercase → no-op function (`src/shims.ts:111-129`) |
| `react`, `react/jsx-runtime` | Stubbed so UI imports don't crash at load |

Because unknown exports auto-stub instead of throwing, a tool that merely *imports* an unsupported API still loads; it only fails if it depends on that API's real behavior.

## Checking a specific extension

```bash
# Loadability across everything currently enabled
bun run test:shims

# One extension's enabled tools, command-only entries, eval coverage
python3 scripts/call-raybridge.py catalog --action detail --query <extension-name>

# Whole-install health: stale config, missing tool files, risky enables
python3 scripts/call-raybridge.py catalog --action doctor
```

`test:shims` default mode reports import success per tool; execute mode actually runs them and can have side effects (see [TESTING.md](TESTING.md)). If a tool shows up green in load mode but returns nothing in use, it is almost certainly Tier 3 (UI-bound).

## Rules of thumb

- Prefer extensions described as "AI Extensions" or that advertise tools for an API-backed service
- Treat any tool whose description is about showing/picking/previewing as Tier 3
- When a tool errors with `Raycast API <x> is disabled`, that is a gate decision, not a bug; decide whether to enable it
- When in doubt, run `doctor` then `test:shims` before adding a tool to a remotely exposed allowlist
