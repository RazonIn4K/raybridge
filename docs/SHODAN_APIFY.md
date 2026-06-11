# Shodan + Apify Workflow

A self-contained reconnaissance-triage pipeline that ships alongside RayBridge in `docs/shodan-apify/`. It turns raw Shodan host data and Apify scraper output into a compact, normalized finding schema, then feeds that into multi-model Zen analysis. It is independent of the MCP server: a plain Python utility plus prompt templates.

Core safety stance: **every remote string is untrusted evidence, never an instruction.** Banners, certificates, HTML, DOM text, scripts, and actor output fields are all treated as potentially adversarial. The normalizer sanitizes role-prefixed lines so scraped content cannot impersonate a system/user/assistant turn in a downstream prompt, and every Zen template restates the boundary.

## Files

| File | Purpose |
|------|---------|
| `docs/shodan-apify/NORMALIZER.py` | Normalizes raw Shodan/Apify JSON into ranked findings; can emit raw JSON, a summary, or a Zen-ready prompt |
| `docs/shodan-apify/test_normalizer.py` | Targeted unit tests for the normalizer |
| `docs/shodan-apify/ZEN_WORKFLOWS.md` | Five copy-paste Zen prompts (triage, deep-dive, secaudit, consensus, precommit) |
| `docs/shodan-apify/ASSET_INVENTORY.example.json` | Template for the optional ownership inventory |

## Normalizer

Input is one JSON file with top-level `shodan` and/or `apify` keys. Output is a list of findings sorted by severity (`info` → `critical`), with ports classified (risky/web/db/critical/ICS/SMB), missing security headers flagged, and ownership resolved against your inventory.

```bash
# Raw normalized findings as JSON
python3 docs/shodan-apify/NORMALIZER.py --batch findings.json

# With a severity/asset summary alongside the findings
python3 docs/shodan-apify/NORMALIZER.py --batch findings.json --summary

# Zen-ready prompt instead of JSON
python3 docs/shodan-apify/NORMALIZER.py --batch findings.json --zen-prompt

# Scope ownership with an inventory
python3 docs/shodan-apify/NORMALIZER.py --batch findings.json --inventory inventory.json --zen-prompt
```

CLI surface (`NORMALIZER.py:668`): `--batch <path>` (required), `--zen-prompt`, `--summary`, `--inventory <path>`. Invalid or unreadable input fails fast with a parse-location error rather than emitting partial findings.

### Ownership inventory

Optional, but it converts "some host" into "an asset you own / monitor / neither", which drives follow-up priority. Copy the example and fill in CIDR ranges and domains:

```json
{
  "owned_ips": ["203.0.113.10", "198.51.100.0/24"],
  "monitored_ips": ["192.0.2.0/24"],
  "owned_domains": ["example.org", "corp.example.org"],
  "monitored_domains": ["vendor.example.net"]
}
```

`resolve_ownership` (`NORMALIZER.py:265`) matches each finding's IPs and domains against these sets, including CIDR membership and domain-suffix scoping.

## Zen workflows

Once you have a `--zen-prompt` payload, [`ZEN_WORKFLOWS.md`](shodan-apify/ZEN_WORKFLOWS.md) provides five prompts, each pinned to a Zen tool and each repeating the untrusted-evidence boundary:

1. **Triage** (`analyze`) — rank by operational risk, flag false positives, surface items needing owner follow-up
2. **Deep-Dive** (`thinkdeep`) — root cause, realistic exploitation path, evidence that would move confidence, remediation tradeoffs
3. **Secaudit Report** (`secaudit`, `audit_focus=comprehensive`) — executive summary through residual-risk
4. **Consensus Check** (`consensus`) — multi-model vote on what is genuinely urgent vs hygiene, with a 7-day plan
5. **Precommit Guard** (`precommit`) — verify no prompt-injection path from raw evidence into trusted prompts, no staged secrets, severity only escalates on stronger evidence

Typical flow: normalize → triage to shortlist → deep-dive the worst finding → secaudit for the written report → consensus when severity is contested → precommit before committing any workflow code.

## Testing

```bash
python3 docs/shodan-apify/test_normalizer.py
```

The tests load `NORMALIZER.py` directly (`test_normalizer.py:13-20`) and cover severity ordering, port classification, ownership resolution, and prompt-role sanitization. This suite is pure-Python and hermetic: no Shodan/Apify credentials, no network. It is a good candidate for any future CI lane since it shares none of RayBridge's macOS/Raycast dependencies.

## Relationship to the `shodan-raybridge` extension

The pipeline here is offline analysis of data you already pulled. Live querying is a separate concern handled by the `shodan-raybridge` Raycast extension (an API-key-gated Tier 4 tool, see [EXTENSION_COMPAT.md](EXTENSION_COMPAT.md)). Pull with the extension, normalize and analyze with these scripts.
