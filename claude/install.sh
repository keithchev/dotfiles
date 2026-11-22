#!/usr/bin/env bash
#
# Install Claude Code status line

set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE_CMD="bash ~/.claude/statusline-command.sh"

mkdir -p "$CLAUDE_DIR"
ln -sf "$DOTFILES_ROOT/claude/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"

# Point settings.json at the script, preserving any other settings
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; add this to $SETTINGS manually:" >&2
  echo "  \"statusLine\": {\"type\": \"command\", \"command\": \"$STATUSLINE_CMD\"}" >&2
  exit 0
fi

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
tmp="$(mktemp)"
jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
