#!/usr/bin/env bash
# Install script for Multiagent Code
echo "Installing Multiagent Code..."
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_DIR="$SCRIPT_DIR"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_CMD_DIR="$CLAUDE_DIR/commands"

mkdir -p "$CLAUDE_CMD_DIR"

prompt_overwrite() {
  local target_file="$1"
  if [[ -f "$target_file" ]]; then
    read -r -p "File $(basename "$target_file") already exists. Overwrite? [y/N]: " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]]
  else
    return 0
  fi
}

SRC_ORCH="$REPO_DIR/.claude/commands/orchestrator.md"
DST_ORCH="$CLAUDE_CMD_DIR/orchestrator.md"
if prompt_overwrite "$DST_ORCH"; then
  cp "$SRC_ORCH" "$DST_ORCH"
else
  echo "Skipped copying orchestrator.md"
fi

SRC_SETTINGS="$REPO_DIR/.claude/settings.json"
DST_SETTINGS="$CLAUDE_DIR/settings.json"
if prompt_overwrite "$DST_SETTINGS"; then
  cp "$SRC_SETTINGS" "$DST_SETTINGS"
else
  echo "Skipped copying settings.json"
fi

add_line_if_missing() {
  local line="$1"
  local file="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Add environment variable & alias to common shell rc files
CODE_DIR="$(cd "$REPO_DIR/multiagent-code" && pwd)"
ENV_LINE="export MULTIAGENT_CODE_DIR=\"$CODE_DIR\""
ALIAS_LINE="alias mac=\"cd \$MULTIAGENT_CODE_DIR\""
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  touch "$rc"
  add_line_if_missing "$ENV_LINE" "$rc"
  add_line_if_missing "$ALIAS_LINE" "$rc"
done

echo "Installation completed. Final step: reload your shell or source your rc file."
