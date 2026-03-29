# goto

A tiny zsh tool for jumping to your frequent directories.

## Why goto?

When working in the terminal, finding and copying paths to deeply nested project directories is constantly annoying. You lose your context opening a file manager or blindly searching shell history just to `cd` into a directory.

I built `goto` to solve this: bookmarked shortcuts for the directories you visit most.

`cd ~/deeply/nested/path/to/workplace` → `goto workplace`

## What it does

Save your current directory with `goto add`, jump directly by name with `goto <name>`, or open the interactive picker with a bare `goto`.

The `fzf` picker previews directory contents and automatically sorts your bookmarks by jump frequency. Don't want to add them manually? Run `goto scan` to discover your most-visited folders directly from your shell history. Everything is governed by a single config file and features full tab-completion.

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

`install.sh` copies the default config to `~/.config/goto/config` and appends a `source` line to `~/.zshrc`.

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
goto --edit / -e         Open config in $EDITOR
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

Everything lives in a single file at `~/.config/goto/config` (override with `GOTO_CONFIG` env var).

The file has two types of lines:

- **Settings** -- `GOTO_*=value` lines that control tool behaviour.
- **Directories** -- `name|path` lines that define jump targets.
- **Comments** -- Lines starting with `#` are ignored.

### Example config

```bash
# ── Settings ──────────────────────────────────────────────

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

# ── Directories ───────────────────────────────────────────
# Format: name|path

Desktop|~/Desktop
Downloads|~/Downloads
Projects|~/Projects
```

### Settings reference

| Variable          | Default                 | Description                                    |
| ----------------- | ----------------------- | ---------------------------------------------- |
| `GOTO_FZF_HEIGHT` | `~50%`                  | fzf window height                              |
| `GOTO_PREVIEW`    | `true`                  | Show directory contents preview in fzf         |
| `GOTO_LOG_MAX`    | `1000`                  | Max log entries to keep (0 = unlimited)        |
| `GOTO_COLOR`      | `true`                  | Coloured terminal output                       |
| `GOTO_FZF_OPTS`   | *(empty)*               | Extra options appended to all fzf calls        |
| `GOTO_CONFIG`     | `~/.config/goto/config` | Config file path (set as env var, not in file) |

## Licence

[MIT](LICENCE)
