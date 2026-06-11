# Testing

Philosophy: tests must pass on a developer Mac with Raycast installed ("local-OK"). The aspiration for CI is a hermetic subset that needs no Raycast database, Keychain, or installed extensions; suites are annotated below by what they require.

## The aggregate gate

```bash
bun run verify:repo
```

runs `typecheck` plus the six suites (`package.json`). Run it before every push.

| Suite | Command | Covers | Needs |
|-------|---------|--------|-------|
| typecheck | `bun run typecheck` | `tsc --noEmit` over the whole repo | nothing |
| config | `bun run test:config` | tools.json normalization, allowlist/blocklist filtering, fail-closed defaults (`src/config.ts`) | nothing |
| logging | `bun run test:logging` | secret redaction patterns, `safeJsonPreview` depth/length limits (`src/logging.ts`) | nothing |
| catalog | `bun run test:catalog` | built-in `raybridge` tool actions, risk classification (`src/catalog.ts`) | nothing |
| worker | `bun run test:worker` | worker spawn, result parsing, error and timeout paths via fixtures (`src/worker-executor.ts`) | bun on PATH |
| shim-gates | `bun run test:shim-gates` | gated APIs throw when disabled; AI shim shape (Promise + EventEmitter, `Model`/`Creativity`, `end` event) (`src/test-shim-gates.ts`) | nothing |
| shims | `bun run test:shims` | loads every enabled extension tool through the shims and verifies it imports cleanly | Raycast + installed extensions |

The first four rows plus shim-gates are the hermetic-CI candidates. `test:worker` uses the fixtures in `src/test-fixtures/` (`worker-error-tool.cjs`, `worker-timeout-tool.cjs`) to force failure paths deterministically.

## test:shims modes

Default mode verifies loadability only: each enabled tool is `require`d through the shim layer and reported ✅/❌. Output goes to `shim-test-results.json` and the append-only `test-audit/shim-test-audit.log` (both gitignored).

```bash
bun run test:shims:execute
```

additionally EXECUTES each tool with inputs synthesized from its schema. This hits real APIs with your real Raycast OAuth tokens and can have side effects (it has failed on Music/timer runtime paths that try to control live apps). Treat execute mode as a manual, supervised diagnostic, never CI. Review the enabled-tool list (`raybridge list`) before running it.

## Manual smoke checks

```bash
raybridge list                                  # extensions/tools as filtered by config
python3 scripts/call-raybridge.py list          # same view over MCP
python3 scripts/call-raybridge.py catalog --action doctor   # stale config, missing tool files, risky enables
python3 scripts/call-raybridge.py call --mcp-tool <ext> --raycast-tool <tool> --input-json '{}'
```

`doctor` is the fastest "is my install sane" check and is clean-state-required before publishing branches.

## Adding tests

- Unit-style assertions belong in a `src/test-<area>.ts` file wired into `verify:repo`; follow `test-shim-gates.ts` for the assert helper pattern
- Anything touching gated shims must test both the enabled and disabled path
- New worker behaviors get a fixture in `src/test-fixtures/` rather than a sleep/race
- Keep suites runnable in isolation; no ordering dependencies between them

## Known environment caveats

- A fresh clone without `bun install` fails typecheck (React/OpenTUI types for the TUI; see decision HD-1)
- `tsc` against a newer `@opentui` than the lockfile pin can surface `src/tui.tsx` API-drift errors that are version skew, not regressions
- Suites that read Raycast's DB degrade gracefully when the Keychain prompt is denied, but token-dependent assertions will skip rather than pass
