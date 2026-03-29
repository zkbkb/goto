#!/bin/bash
set -e

CONFIG_DIR="$HOME/.config/goto"
ZSHRC="$HOME/.zshrc"

echo "goto uninstaller"
echo ""

# remove source line from .zshrc
if grep -qF "goto.zsh" "$ZSHRC" 2>/dev/null; then
  # remove the source line and the comment above it
  sed -i '' '/# goto - quick directory jumper/d' "$ZSHRC"
  sed -i '' '/goto\.zsh/d' "$ZSHRC"
  echo "Removed goto from $ZSHRC"
else
  echo "No goto entry found in $ZSHRC, skipped"
fi

# remove config directory
if [[ -d "$CONFIG_DIR" ]]; then
  read -r -p "Delete config directory $CONFIG_DIR? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR"
    echo "Deleted $CONFIG_DIR"
  else
    echo "Kept $CONFIG_DIR"
  fi
else
  echo "No config directory found, skipped"
fi

echo ""
echo "Done. Run 'source ~/.zshrc' or open a new terminal to apply."
echo "You can now safely delete this repo directory."
