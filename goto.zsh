GOTO_VERSION="0.4.0"

goto() {
  local config="${GOTO_CONFIG:-$HOME/.config/goto/dirs}"
  local logfile="$HOME/.config/goto/log"

  if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "goto $GOTO_VERSION"
    return
  fi

  if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "goto $GOTO_VERSION - quick directory jumper"
    echo ""
    echo "Usage:"
    echo "  goto                     pick a directory to jump to"
    echo "  goto add <path> [name]   add a directory (default name: dirname)"
    echo "  goto rm [name]           remove a directory (fzf picker if no name)"
    echo "  goto list                list all saved directories"
    echo "  goto scan                scan shell history for frequent dirs"
    echo "  goto scan --all/-a       include missing directories (strikethrough)"
    echo "  goto scan --dry/-d       print scan results without interactive picker"
    echo "  goto log [n]             show last n jumps (default: 20)"
    echo "  goto --edit/-e           open config in editor"
    echo "  goto --version/-v        show version"
    echo "  goto help                show this help"
    echo ""
    echo "Config: $config"
    return
  fi

  if [[ ! -f "$config" ]]; then
    echo "goto: config not found: $config" >&2
    return 1
  fi

  if [[ "$1" == "--edit" || "$1" == "-e" ]]; then
    ${EDITOR:-open -t} "$config"
    return
  fi

  if [[ "$1" == "log" ]]; then
    if [[ ! -f "$logfile" ]]; then
      echo "goto: no log yet"
      return
    fi
    local n="${2:-20}"
    tail -n "$n" "$logfile"
    return
  fi

  if [[ "$1" == "list" ]]; then
    grep -v '^#' "$config" | grep -v '^$' \
      | sed "s|$HOME|~|g" \
      | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}'
    return
  fi

  if [[ "$1" == "add" ]]; then
    local target="${2:-.}"
    local dir=$(builtin cd "$target" 2>/dev/null && pwd -P)
    if [[ -z "$dir" ]]; then
      echo "goto: not a valid directory: $target" >&2
      return 1
    fi
    local name="${3:-${dir##*/}}"
    if sed "s|~|$HOME|g" "$config" | grep -qF "|$dir"; then
      echo "goto: already exists: $dir" >&2
      return 1
    fi
    echo "$name|$dir" >> "$config"
    echo "added: $name -> $dir"
    return
  fi

  if [[ "$1" == "rm" || "$1" == "remove" ]]; then
    if [[ -n "$2" ]]; then
      if grep -q "^$2|" "$config"; then
        local entry=$(grep "^$2|" "$config")
        sed -i '' "/^$2|/d" "$config"
        echo "removed: $entry"
      else
        echo "goto: not found: $2" >&2
        return 1
      fi
    else
      if ! command -v fzf >/dev/null 2>&1; then
        echo "goto: fzf is required for interactive selection. Install: brew install fzf" >&2
        return 1
      fi
      local picks
      picks=$(grep -v '^#' "$config" | grep -v '^$' \
        | sed "s|$HOME|~|g" \
        | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}' \
        | fzf --prompt='rm > TAB to multi-select, Enter to remove > ' --multi --height=~50% --reverse --no-info)
      if [[ -z "$picks" ]]; then
        echo "goto: nothing selected"
        return
      fi
      echo "$picks" | while IFS= read -r line; do
        local name="${line%%[[:space:]]*}"
        sed -i '' "/^$name|/d" "$config"
        echo "removed: $name"
      done
    fi
    return
  fi

  if [[ "$1" == "scan" ]]; then
    local show_all=false dry_run=false
    for arg in "${@:2}"; do
      case "$arg" in
        --all|-a) show_all=true ;;
        --dry|-d) dry_run=true ;;
      esac
    done

    local histfile="${HISTFILE:-$HOME/.zsh_history}"
    if [[ ! -f "$histfile" ]]; then
      echo "goto: history file not found: $histfile" >&2
      return 1
    fi

    # extract cd targets, normalise to absolute paths, rank by frequency
    local existing
    existing=$(sed "s|~|$HOME|g" "$config" | grep -v '^#' | grep -v '^$' | awk -F'|' '{print $2}')

    local scan_output
    scan_output=$(export LC_ALL=en_US.UTF-8; { \
      grep '^cd ' "$histfile" 2>/dev/null | sed 's/^cd //;s/[[:space:]]*$//' 2>/dev/null | sed "s|^~|$HOME|" 2>/dev/null; \
      grep ';cd ' "$histfile" 2>/dev/null | sed 's/^.*;\s*cd //;s/[[:space:]]*$//' 2>/dev/null | sed "s|^~|$HOME|" 2>/dev/null; \
      [[ -f "$logfile" ]] && sed 's/^[0-9-]* [0-9:]* *//' "$logfile" 2>/dev/null; \
      } \
      | sort | uniq -c | sort -rn \
      | while read -r count dir; do
          [[ -z "$dir" || "$dir" == "$HOME" ]] && continue
          local short="${dir/#$HOME/~}"
          if ! [[ -d "$dir" ]]; then
            $show_all && printf "\033[9m\033[2m%3sx  %s\033[0m\n" "$count" "$short"
          elif echo "$existing" | grep -qxF "$dir"; then
            printf "\033[32m%3sx  %s [added]\033[0m\n" "$count" "$short"
          else
            printf "%3sx  %s\n" "$count" "$short"
          fi
        done)

    if $dry_run; then
      echo "$scan_output"
      return
    fi

    if ! command -v fzf >/dev/null 2>&1; then
      echo "goto: fzf is required for interactive selection. Install: brew install fzf" >&2
      return 1
    fi

    local picks
    picks=$(echo "$scan_output" \
      | fzf --prompt='scan > TAB to multi-select, Enter to add > ' --multi --ansi --height=~50% --reverse --no-info)

    if [[ -z "$picks" ]]; then
      echo "goto: nothing selected"
      return
    fi

    echo "$picks" | while IFS= read -r line; do
      echo "$line" | grep -q '\[added\]' && continue
      local dir="${line#*x  }"
      local full="${dir/#\~/$HOME}"
      [[ -d "$full" ]] || continue
      local name="${full##*/}"
      echo "$name|$dir" >> "$config"
      echo "added: $name -> $dir"
    done
    return
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    echo "goto: fzf is required. Install: brew install fzf" >&2
    return 1
  fi

  local selected
  selected=$(grep -v '^#' "$config" | grep -v '^$' \
    | sed "s|$HOME|~|g" \
    | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}' \
    | fzf --prompt='goto > ' --no-multi --height=~50% --reverse --no-info)

  if [[ -n "$selected" ]]; then
    local dir="${selected#*>  }"
    dir="${dir/#\~/$HOME}"
    echo "$(date '+%Y-%m-%d %H:%M:%S')  $dir" >> "$logfile"
    cd "$dir" || return 1
  fi
}
