# goto

A tiny zsh tool for jumping to your frequent directories.

## Why goto?

When working in the terminal, finding and copying paths to deeply nested project directories is constantly annoying. You lose your context opening a file manager or blindly searching shell history just to `cd` into a directory.

I built `goto` to solve this: bookmarked shortcuts for the directories you visit most.

`cd ~/deeply/nested/path/to/workplace` → `goto workplace`

## What it does

Save directories with `goto add`, jump by name with `goto <name>`, or open the interactive picker with a bare `goto`. The `fzf` picker previews directory contents and sorts your bookmarks by jump frequency. `goto scan` can bootstrap your list by importing frequent directories from your shell history.

Settings and directory list live in a single, human-readable config file (`~/.config/goto/config`) that you can version control, edit by hand, or sync across machines. Full zsh tab-completion included.

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
goto add .                        # bookmark current directory
goto add ~/Projects/my-app app    # bookmark with a custom name
goto app                          # jump directly by name
goto                              # open fuzzy picker (sorted by frequency)
goto scan                         # import frequent dirs from shell history
```

## Configuration

Everything lives in `~/.config/goto/config` (override with `GOTO_CONFIG` env var). The file has three kinds of lines:

- **Settings** -- `GOTO_*=value` lines that control tool behaviour.
- **Directories** -- `name|path` lines that define jump targets.
- **Comments** -- lines starting with `#` are ignored.

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

## See also

Shortly after publishing this I discovered [zoxide](https://github.com/ajeetdsouza/zoxide), which does the same job but learns your habits automatically. So yes, I reinvented the wheel. That said, if you still prefer the explicit, curated approach, well, here we are.

## Licence

[MIT](LICENCE)
