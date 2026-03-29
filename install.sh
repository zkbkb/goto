#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/goto"
ZSHRC="$HOME/.zshrc"

# create config directory and copy default config
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/dirs" ]]; then
  cp "$SCRIPT_DIR/dirs" "$CONFIG_DIR/dirs"
  echo "Created config: $CONFIG_DIR/dirs"
else
  echo "Config already exists, skipped: $CONFIG_DIR/dirs"
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
echo "  goto        # pick a directory to jump to"
echo "  goto --edit # edit the directory list"
