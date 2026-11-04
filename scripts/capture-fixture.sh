#!/bin/bash
# Runs the real `claude -p /usage` and saves its output as a test fixture,
# with private details removed.
#
# Usage: scripts/capture-fixture.sh [normal|logged-out|api-key|no-home]
# Writes BenchedTests/Fixtures/<claude version>-<variant>.jsonl
# Set CLAUDE=/path/to/claude to use a specific binary.
set -eo pipefail

variant="${1:-normal}"
claude="${CLAUDE:-$(command -v claude)}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
# Same working directory as the app, so captures don't add Claude Code project entries
cwd="$HOME/Library/Application Support/com.jdamcd.benched"
mkdir -p "$cwd"

flags=(-p /usage --output-format stream-json --verbose --no-session-persistence --safe-mode)
version="$("$claude" --version | awk '{print $1}')"
out="$repo/BenchedTests/Fixtures/$version-$variant.jsonl"
raw="$(mktemp)"
trap 'rm -f "$raw"' EXIT

case "$variant" in
    normal) (cd "$cwd" && "$claude" "${flags[@]}" < /dev/null > "$raw") ;;
    logged-out)
        config="$(mktemp -d)"
        (cd "$cwd" && CLAUDE_CONFIG_DIR="$config" "$claude" "${flags[@]}" < /dev/null > "$raw")
        rm -rf "$config"
        ;;
    api-key) (cd "$cwd" && ANTHROPIC_API_KEY=dummy "$claude" "${flags[@]}" < /dev/null > "$raw") ;;
    no-home) (cd "$cwd" && env -i PATH=/usr/bin:/bin "$claude" "${flags[@]}" < /dev/null > "$raw") ;;
    *) echo "Unknown variant: $variant" >&2; exit 1 ;;
esac

# The init line lists the cwd, MCP servers and plugins, so keep only what the app reads.
# "What's contributing" describes how the account owner works, and extra usage shows their
# billing setup. The app reads neither.
jq -c '
  def trim_contributing: sub("\n\nWhat.s contributing to your usage\\?[\\s\\S]*?(?=</local-command-stdout>|\\z)"; "");
  if .type == "system" and .subtype == "init" then {type, subtype, claude_code_version, apiKeySource}
  elif .type == "assistant" then
    del(.usage_report.rate_limits.extra_usage)
    | (if .local_command_source then .local_command_source |= trim_contributing else . end)
    | (if .message.content then .message.content |= map(if .text then .text |= trim_contributing else . end) else . end)
  elif .type == "result" and (.result | type) == "string" then .result |= trim_contributing
  else . end
' "$raw" > "$out"

echo "Saved $out"
