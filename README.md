# goto

A minimal, zero-dependency directory jumper for zsh. Define shortcuts, pick them with [fzf](https://github.com/junegunn/fzf), and land there instantly.

## Features

- **Fuzzy directory picker** -- Type `goto` to open an fzf-powered list of your saved directories.
- **Quick add & remove** -- Register any directory with `goto add`, remove with `goto rm`.
- **History scan** -- Import frequently visited directories from your shell history with `goto scan`. Supports both plain and `EXTENDED_HISTORY` formats.
- **Jump log** -- Every jump is timestamped and logged; review with `goto log`.
- **Plain-text list** -- `goto list` prints all saved directories without launching fzf.
- **Portable config** -- A simple `name|path` plain-text file, easy to version-control or sync.

## Requirements

- **zsh** (tested on macOS default shell)
- **[fzf](https://github.com/junegunn/fzf)** for the interactive picker (goto will tell you if it is missing)

## Installation

```bash
git clone <repo-url> ~/goto   # or wherever you prefer
cd ~/goto
bash install.sh
source ~/.zshrc
```

`install.sh` does two things:

1. Copies the default `dirs` config to `~/.config/goto/dirs` (skipped if it already exists).
2. Appends a `source` line to `~/.zshrc` so `goto` is available in every new shell.

## Uninstallation

```bash
bash uninstall.sh
```

This removes the `source` line from `~/.zshrc` and optionally deletes `~/.config/goto/`.

## Usage

```text
goto                     Pick a directory to jump to (fzf)
goto add <path> [name]   Add a directory (default name: basename of path)
goto rm [name]           Remove a directory (fzf multi-select if no name)
goto list                List all saved directories (no fzf)
goto scan                Scan shell history for frequent dirs and add via fzf
goto scan --all / -a     Include missing directories (shown with strikethrough)
goto scan --dry / -d     Print scan results without interactive picker
goto log [n]             Show last n jumps (default: 20)
goto --edit / -e         Open config in $EDITOR
goto --version / -v      Show version
goto help                Show help
```

### Examples

```bash
# add the current directory
goto add .

# add a specific directory with a custom name
goto add ~/Projects/my-app app

# remove a directory by name
goto rm app

# remove interactively (fzf multi-select)
goto rm

# list everything without fzf
goto list

# scan history, pick the dirs you visit most
goto scan

# jump to a saved directory
goto
```

## Configuration

The directory list lives at `~/.config/goto/dirs` by default (override with `GOTO_CONFIG`).

Format: one entry per line, `name|path`. Lines starting with `#` are comments.

```text
# goto directory config
Desktop|~/Desktop
Downloads|~/Downloads
Projects|~/Projects
```

## Licence

[MIT](LICENCE)
