#!/usr/bin/env bash
# Checks the rules that `claude plugin validate` doesn't cover but claude.ai organization sync enforces.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$root/.claude-plugin/marketplace.json"
status=0

fail() { echo "✘ $*"; status=1; }

# The marketplace name must not be one of Anthropic's reserved names.
mname=$(jq -r '.name' "$manifest")
case "$mname" in
  claude-plugins-official|anthropic-*|claude-*) fail "marketplace name '$mname' looks reserved" ;;
esac

count=$(jq '.plugins | length' "$manifest")
for i in $(seq 0 $((count - 1))); do
  name=$(jq -r ".plugins[$i].name" "$manifest")
  source=$(jq -r ".plugins[$i].source | if type == \"string\" then . else \"\" end" "$manifest")

  if [[ -z "$source" ]]; then
    echo "• $name: non-path source, skipping local checks"
    continue
  fi
  if [[ "$source" != ./* ]]; then
    fail "$name: relative source must start with ./ (got '$source')"
    continue
  fi

  dir="$root/${source#./}"
  pjson="$dir/.claude-plugin/plugin.json"
  [[ -f "$pjson" ]] || { fail "$name: missing $source/.claude-plugin/plugin.json"; continue; }

  pname=$(jq -r '.name' "$pjson")
  [[ "$pname" == "$name" ]] || fail "$name: plugin.json name is '$pname'; it must match the marketplace entry name"

  jq -e '.version' "$pjson" >/dev/null || fail "$name: plugin.json needs a version (bump it on every release)"

  [[ -d "$dir/bin" ]] && fail "$name: has a top-level bin/ directory, which claude.ai rejects; move executables to scripts/"

  if [[ -f "$dir/.mcp.json" ]]; then
    stdio=$(jq -r '.mcpServers | to_entries[] | select((.value.type // "stdio") == "stdio") | .key' "$dir/.mcp.json")
    [[ -z "$stdio" ]] || echo "! $name: local (stdio) MCP server(s) [$stdio] won't run in claude.ai chat"
  fi

  for skill in "$dir"/skills/*/SKILL.md; do
    [[ -f "$skill" ]] || continue
    head -1 "$skill" | grep -q '^---$' || fail "$name: $skill is missing YAML frontmatter"
    grep -q '^description:' "$skill" || fail "$name: $skill frontmatter has no description"
  done

  echo "✔ $name"
done

exit $status
