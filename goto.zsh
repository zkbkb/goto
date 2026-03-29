GOTO_VERSION="0.5.0"

goto() {
  local config="${GOTO_CONFIG:-$HOME/.config/goto/dirs}"
  local logfile="$HOME/.config/goto/log"

  # colour helpers
  local _green=$'\033[32m' _red=$'\033[31m' _yellow=$'\033[33m' _dim=$'\033[2m' _reset=$'\033[0m'

  if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "goto $GOTO_VERSION"
    return
  fi

  if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "goto $GOTO_VERSION - quick directory jumper"
    echo ""
    echo "Usage:"
    echo "  goto [name]              jump directly (or open picker if no match)"
    echo "  goto add <path> [name]   add a directory (default name: dirname)"
    echo "  goto rm [name]           remove a directory (fzf picker if no name)"
    echo "  goto list                list all saved directories"
    echo "  goto clean               remove stale entries pointing to missing dirs"
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
    echo "${_red}goto: config not found: $config${_reset}" >&2
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
      echo "${_red}goto: not a valid directory: $target${_reset}" >&2
      return 1
    fi
    local name="${3:-${dir##*/}}"
    if sed "s|~|$HOME|g" "$config" | grep -qF "|$dir"; then
      echo "${_yellow}goto: already exists: $dir${_reset}" >&2
      return 1
    fi
    if grep -q "^${name}|" "$config"; then
      echo "${_yellow}goto: name '$name' is already in use. Choose a different name.${_reset}" >&2
      return 1
    fi
    echo "$name|$dir" >> "$config"
    echo "${_green}added:${_reset} $name -> $dir"
    return
  fi

  if [[ "$1" == "rm" || "$1" == "remove" ]]; then
    if [[ -n "$2" ]]; then
      if grep -q "^$2|" "$config"; then
        local entry=$(grep "^$2|" "$config")
        sed -i '' "/^$2|/d" "$config"
        echo "${_red}removed:${_reset} $entry"
      else
        echo "${_red}goto: not found: $2${_reset}" >&2
        return 1
      fi
    else
      if ! command -v fzf >/dev/null 2>&1; then
        echo "${_red}goto: fzf is required for interactive selection. Install: brew install fzf${_reset}" >&2
        return 1
      fi
      local picks
      picks=$(grep -v '^#' "$config" | grep -v '^$' \
        | sed "s|$HOME|~|g" \
        | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}' \
        | fzf --prompt='rm > TAB to multi-select, Enter to remove > ' --multi --height=~50% --reverse --no-info \
              --preview 'dir="$(echo {} | sed "s/.*>  //" | sed "s|~|'"$HOME"'|")"; ls -1pF "$dir" 2>/dev/null || echo "Directory does not exist"')
      if [[ -z "$picks" ]]; then
        echo "goto: nothing selected"
        return
      fi
      echo "$picks" | while IFS= read -r line; do
        local name="${line%%[[:space:]]*}"
        sed -i '' "/^${name}|/d" "$config"
        echo "${_red}removed:${_reset} $name"
      done
    fi
    return
  fi

  if [[ "$1" == "clean" ]]; then
    local cleaned=0
    local tmpfile=$(mktemp)
    while IFS= read -r line; do
      if [[ "$line" == \#* || -z "$line" ]]; then
        echo "$line" >> "$tmpfile"
        continue
      fi
      local path="${line#*|}"
      local full="${path/#\~/$HOME}"
      if [[ -d "$full" ]]; then
        echo "$line" >> "$tmpfile"
      else
        echo "${_red}removed:${_reset} $line ${_dim}(directory missing)${_reset}"
        ((cleaned++))
      fi
    done < "$config"
    mv "$tmpfile" "$config"
    if (( cleaned == 0 )); then
      echo "${_green}goto: all entries are valid${_reset}"
    else
      local word=$(( cleaned == 1 )) && word="entry" || word="entries"
      echo "${_green}cleaned $cleaned stale $word${_reset}"
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
      echo "${_red}goto: history file not found: $histfile${_reset}" >&2
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
      echo "${_red}goto: fzf is required for interactive selection. Install: brew install fzf${_reset}" >&2
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
      echo "${_green}added:${_reset} $name -> $dir"
    done
    return
  fi

  # --- direct jump by name ---
  if [[ -n "$1" ]]; then
    local match
    match=$(grep "^$1|" "$config" | head -1)
    if [[ -n "$match" ]]; then
      local dir="${match#*|}"
      dir="${dir/#\~/$HOME}"
      if [[ -d "$dir" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S')  $dir" >> "$logfile"
        cd "$dir" || return 1
      else
        echo "${_red}goto: directory no longer exists: $dir${_reset}" >&2
        read -r "answer?Remove '$1' from config? [y/N] "
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          sed -i '' "/^$1|/d" "$config"
          echo "${_red}removed:${_reset} $1"
        fi
        return 1
      fi
      return
    fi
    # no exact match: fall through to fzf with $1 as initial query
  fi

  # --- interactive picker (sorted by jump frequency) ---
  if ! command -v fzf >/dev/null 2>&1; then
    echo "${_red}goto: fzf is required. Install: brew install fzf${_reset}" >&2
    return 1
  fi

  local display
  if [[ -f "$logfile" ]]; then
    # sort entries by jump frequency (most frequent first)
    display=$(grep -v '^#' "$config" | grep -v '^$' \
      | sed "s|~|$HOME|g" \
      | while IFS='|' read -r name path; do
          local count
          count=$(grep -c "  ${path}$" "$logfile" 2>/dev/null)
          count=${count:-0}
          local short="${path/#$HOME/\~}"
          printf "%06d\t%-12s >  %s\n" "$count" "$name" "$short"
        done \
      | sort -t$'\t' -k1 -rn \
      | cut -f2-)
  else
    display=$(grep -v '^#' "$config" | grep -v '^$' \
      | sed "s|$HOME|~|g" \
      | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}')
  fi

  local query="${1:-}"
  local selected
  selected=$(echo "$display" \
    | fzf --prompt='goto > ' --no-multi --height=~50% --reverse --no-info \
          --query="$query" \
          --preview 'dir="$(echo {} | sed "s/.*>  //" | sed "s|~|'"$HOME"'|")"; ls -1pF "$dir" 2>/dev/null || echo "Directory does not exist"')

  if [[ -n "$selected" ]]; then
    local dir="${selected#*>  }"
    dir="${dir/#\~/$HOME}"
    if [[ -d "$dir" ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S')  $dir" >> "$logfile"
      cd "$dir" || return 1
    else
      echo "${_red}goto: directory no longer exists: $dir${_reset}" >&2
      local name="${selected%%[[:space:]]*}"
      read -r "answer?Remove '$name' from config? [y/N] "
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        sed -i '' "/^${name}|/d" "$config"
        echo "${_red}removed:${_reset} $name"
      fi
      return 1
    fi
  fi
}

# --- zsh tab completion ---
_goto() {
  local config="${GOTO_CONFIG:-$HOME/.config/goto/dirs}"

  if (( CURRENT == 2 )); then
    local -a subcmds=(
      'add:add a directory'
      'rm:remove a directory'
      'list:list all saved directories'
      'clean:remove stale entries'
      'scan:scan shell history for frequent dirs'
      'log:show recent jumps'
      'help:show help'
    )
    local -a names=()
    if [[ -f "$config" ]]; then
      names=(${(f)"$(grep -v '^#' "$config" | grep -v '^$' | awk -F'|' '{print $1}')"})
    fi
    _describe 'command' subcmds
    compadd -a names
  elif (( CURRENT == 3 )); then
    case "${words[2]}" in
      add)
        _directories ;;
      rm|remove)
        local -a names=()
        if [[ -f "$config" ]]; then
          names=(${(f)"$(grep -v '^#' "$config" | grep -v '^$' | awk -F'|' '{print $1}')"})
        fi
        compadd -a names ;;
    esac
  fi
}

compdef _goto goto
