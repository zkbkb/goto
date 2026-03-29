# goto

A minimal, zero-dependency directory jumper for zsh. Define shortcuts, pick them with [fzf](https://github.com/junegunn/fzf), and land there instantly.

## Features

- **Direct jump** -- `goto Desktop` jumps immediately if the name matches; no fzf needed.
- **Fuzzy picker** -- Plain `goto` opens an fzf list sorted by how often you visit each directory.
- **Directory preview** -- The fzf picker shows `ls` output so you can verify before jumping.
- **Quick add & remove** -- `goto add` / `goto rm` with duplicate-name detection.
- **History scan** -- Import frequently visited directories from shell history (supports both plain and `EXTENDED_HISTORY` formats).
- **Stale entry handling** -- `goto clean` removes entries pointing to missing directories; the picker also offers to remove stale entries on the spot.
- **Jump log** -- Every jump is timestamped; review with `goto log`.
- **Tab completion** -- zsh completions for all subcommands and saved directory names.
- **Fully configurable** -- fzf height, preview toggle, log limit, colours, and extra fzf options via a simple config file.

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

`install.sh` creates `~/.config/goto/` with default `dirs` and `config` files, and appends a `source` line to `~/.zshrc`.

## Uninstallation

```bash
bash uninstall.sh
```

Removes the `source` line from `~/.zshrc` and optionally deletes `~/.config/goto/`.

## Usage

```text
goto [name]              Jump directly (or open picker if no match)
goto add <path> [name]   Add a directory (default name: basename of path)
goto rm [name]           Remove a directory (fzf multi-select if no name)
goto list                List all saved directories (no fzf)
goto clean               Remove stale entries pointing to missing dirs
goto scan                Scan shell history for frequent dirs and add via fzf
goto scan --all / -a     Include missing directories (shown with strikethrough)
goto scan --dry / -d     Print scan results without interactive picker
goto log [n]             Show last n jumps (default: 20)
goto --edit / -e         Open directory list in $EDITOR
goto --version / -v      Show version
goto help                Show help
```

### Examples

```bash
# jump directly by name
goto Desktop

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

# clean up entries where directories have been deleted
goto clean

# scan history, pick the dirs you visit most
goto scan

# open the fuzzy picker (sorted by jump frequency)
goto
```

## Configuration

goto uses two files under `~/.config/goto/`:

### Directory list (`dirs`)

One entry per line, `name|path`. Lines starting with `#` are comments.

```text
# goto directory config
Desktop|~/Desktop
Downloads|~/Downloads
Projects|~/Projects
```

Override the path with the `GOTO_CONFIG` environment variable.

### Settings (`config`)

A shell file that is sourced on every invocation. All options have sensible defaults; uncomment to override.

```bash
# fzf window height (default: ~50%)
# GOTO_FZF_HEIGHT="~50%"

# Show directory preview in fzf picker (true/false, default: true)
# GOTO_PREVIEW=true

# Maximum log entries to keep; 0 = unlimited (default: 1000)
# GOTO_LOG_MAX=1000

# Coloured terminal output (true/false, default: true)
# GOTO_COLOR=true

# Additional fzf options appended to every fzf invocation
# GOTO_FZF_OPTS="--border --margin=1"
```

## Licence

[MIT](LICENCE)
