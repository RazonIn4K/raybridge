# Changelog

## Unreleased

### Fixed
- `AI.ask()` now returns a Promise that also exposes EventEmitter methods, matching Raycast's documented streaming shape, so extensions that call `AI.ask(...).on("data", ...)` load and run instead of crashing. It still resolves to an empty string and never calls a model (upstream PR jlokos/raybridge#8).
- Extension input schema is now a single flat top-level object, so OpenAI-compatible function-calling clients accept the tool instead of rejecting it for top-level `oneOf`/`anyOf`.

### Added
- `AI.Model` and `AI.Creativity` constants in the API shim for extension option-building compatibility.
- Documentation suite under `docs/`: `ARCHITECTURE`, `DECISIONS`, `CONFIGURATION`, `MODEL_COMPATIBILITY`, `TESTING`, `TROUBLESHOOTING`, `HTTP_DEPLOYMENT`, `EXTENSION_COMPAT`, `SHODAN_APIFY`, and the consolidated `ARCHITECTURE_AND_DECISIONS` reference.
- `AGENTS.md` agent guidance and GitHub issue templates.

### Changed
- Normalized TypeScript, Markdown, and JSON sources to LF line endings; added `.gitattributes` to keep them that way.
- Expanded shim test coverage (`test:shim-gates`) to assert the AI shim's Promise + EventEmitter shape and the model/creativity constants.

## v1.0.0

Initial release.

- MCP server with stdio and HTTP transport
- Local extension discovery from `~/.config/raycast/extensions/`
- Interactive TUI for extension configuration
- OAuth token integration from Raycast's encrypted database
- Raycast API shims for headless tool execution
- Blocklist/allowlist mode for tool management
