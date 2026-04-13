# Finding Extensions with AI Tools

RayBridge can only expose Raycast extensions that define a `tools` array in their `package.json`. This is the newer "AI Extensions" feature — most Store extensions still only define `commands` (user-facing) and won't appear in RayBridge.

## How to check what you have

Run this from your terminal:

```bash
find ~/.config/raycast/extensions -name "package.json" \
  -exec grep -l '"tools"' {} \; 2>/dev/null
```

Each file listed is an extension RayBridge can discover. To see the actual tool names:

```bash
find ~/.config/raycast/extensions -name "package.json" \
  -exec grep -l '"tools"' {} \; 2>/dev/null | while read f; do
  echo "=== $(dirname "$f" | xargs basename) ==="
  python3 -c "
import json, sys
with open('$f') as fh:
    pkg = json.load(fh)
for t in pkg.get('tools', []):
    print(f\"  {t['name']}: {t.get('description', '(no description)')}\")
"
done
```

Use the output to populate your `~/.config/raybridge/tools.json` allowlist with real extension and tool names.

## Known extensions with AI tools (as of April 2026)

The AI Extensions feature is relatively new. Extensions maintained by Raycast and major vendors are adopting it first. Some confirmed examples from the Raycast Store and GitHub issues:

**Built-in (Raycast-provided, may appear as `builtin_package_*`):**
- `browser` — `browser-get-focused-browser-tab`, `browser-get-open-tabs`
- `location` — `location-get-current-location`

**Note:** Built-in tools may use a different discovery path than Store extensions. RayBridge discovers Store extensions from `~/.config/raycast/extensions/`. Whether built-in tools appear there depends on how Raycast packages them locally.

**Store extensions (community/vendor):**
- `github-copilot` (by GitHub) — `create-task`, `search-repositories`
- Check the [Raycast Store](https://www.raycast.com/store) filtered by "AI" category for the latest

## How Raycast tool definitions work

Each tool maps to a TypeScript file at `src/tools/{name}.ts` that exports a default function:

```typescript
type Input = {
  /** Search query for repositories */
  query: string;
  /** Maximum number of results */
  limit?: number;
};

export default async function tool(input: Input) {
  // ... fetch from API, return data
  return results;
}
```

The JSDoc comments on `Input` properties teach the AI how to supply arguments. The tool name in `package.json` must match the filename.

## Writing your own tools for RayBridge

If an extension you use doesn't have AI tools yet, you can add them yourself:

1. Find the extension source in `~/.config/raycast/extensions/your-extension/`
2. Add a `tools` entry to its `package.json`
3. Create `src/tools/your-tool.ts` with the typed Input and export
4. Run `npm run build` in the extension directory
5. RayBridge will discover it on next startup

See [Raycast's AI Extension docs](https://developers.raycast.com/ai/create-an-ai-extension) for the full guide.
