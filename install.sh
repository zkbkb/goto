#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/goto"
ZSHRC="$HOME/.zshrc"

# create config directory
mkdir -p "$CONFIG_DIR"

# copy default config (settings + directories)
if [[ ! -f "$CONFIG_DIR/config" ]]; then
  cp "$SCRIPT_DIR/config" "$CONFIG_DIR/config"
  echo "Created config: $CONFIG_DIR/config"
else
  echo "Config already exists, skipped: $CONFIG_DIR/config"
fi

# add source line to .zshrc if not already present
SOURCE_LINE="source \"$SCRIPT_DIR/goto.zsh\""
if ! grep -qF "goto.zsh" "$ZSHRC" 2>/dev/null; then
  echo "" >> "$ZSHRC"
  echo "# goto - quick directory jumper" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "Added to $ZSHRC"
else
  echo "goto.zsh already in $ZSHRC, skipped"
fi

echo ""
echo "Done! Run this to activate:"
echo "  source ~/.zshrc"
echo ""
echo "Usage:"
echo "  goto           # pick a directory to jump to"
echo "  goto Desktop   # jump directly by name"
echo "  goto add .     # add the current directory"
echo "  goto help      # show all commands"
