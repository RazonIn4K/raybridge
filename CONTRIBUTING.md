# Contributing to RayBridge

Thank you for your interest in contributing to RayBridge!

## Development Setup

1. Install [Bun](https://bun.sh)
2. Clone the repository
3. Install dependencies:
   ```bash
   bun install
   ```
4. Run in development mode:
   ```bash
   bun run dev
   ```
5. Run repo checks before submitting:
   ```bash
   bun run verify:repo
   ```

`bun run test:shims` is a safe loadability check by default. Use
`bun run test:shims:execute` only when you intentionally want to execute live
Raycast extension tools.

`bun run test:worker` checks the default isolated worker execution path with a
side-effect-free tool call plus worker error and timeout paths.

## Code Style

- TypeScript with strict mode enabled
- Follow existing patterns in the codebase
- Keep changes focused and minimal

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`feat/your-feature`)
3. Make your changes
4. Test locally with `bun run start`
5. Submit a pull request

## Reporting Issues

Open an issue on GitHub with:
- A clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (macOS version, Bun version, Raycast version)
