GOTO_VERSION="0.5.0"

goto() {
  local config="${GOTO_CONFIG:-$HOME/.config/goto/config}"
  local logfile="$HOME/.config/goto/log"

  # load settings from config (only GOTO_* variable assignments)
  if [[ -f "$config" ]]; then
    source <(grep '^GOTO_[A-Z_]*=' "$config" 2>/dev/null)
  fi

  # configurable defaults
  local fzf_height="${GOTO_FZF_HEIGHT:-~50%}"
  local show_preview="${GOTO_PREVIEW:-true}"
  local log_max="${GOTO_LOG_MAX:-1000}"
  local use_color="${GOTO_COLOR:-true}"
  local extra_fzf="${GOTO_FZF_OPTS:-}"

  # colour helpers (respect GOTO_COLOR)
  local _green _red _yellow _dim _reset
  if [[ "$use_color" == "true" ]]; then
    _green=$'\033[32m' _red=$'\033[31m' _yellow=$'\033[33m' _dim=$'\033[2m' _reset=$'\033[0m'
  else
    _green="" _red="" _yellow="" _dim="" _reset=""
  fi

  # helper: read directory entries from config (lines containing |, excluding comments)
  _goto_dirs() {
    grep -v '^#' "$config" | grep -v '^$' | grep '|'
  }

  # helper: write a jump to the log and trim if needed
  _goto_log_jump() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')  $1" >> "$logfile"
    if [[ "$log_max" -gt 0 && -f "$logfile" ]]; then
      local lines=$(wc -l < "$logfile" | tr -d ' ')
      if (( lines > log_max )); then
        local tmpfile=$(mktemp)
        tail -n "$log_max" "$logfile" > "$tmpfile"
        mv "$tmpfile" "$logfile"
      fi
    fi
  }

  # helper: build preview args for fzf
  local -a _preview_args=()
  if [[ "$show_preview" == "true" ]]; then
    _preview_args=(--preview 'dir="$(echo {} | sed "s/.*>  //" | sed "s|~|'"$HOME"'|")"; ls -1pF "$dir" 2>/dev/null || echo "Directory does not exist"')
  fi

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
    _goto_dirs \
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
    if _goto_dirs | sed "s|~|$HOME|g" | grep -qF "|$dir"; then
      # path exists — check if the user is renaming it
      local old_name=$(_goto_dirs | sed "s|~|$HOME|g" | grep -F "|$dir" | head -1 | awk -F'|' '{print $1}')
      if [[ -n "$3" && "$3" != "$old_name" ]]; then
        # rename: remove old entry and add with new name
        awk -v name="$old_name" -F'|' '!(NF>1 && $1==name)' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
        local short="${dir/#$HOME/~}"
        echo "$name|$short" >> "$config"
        echo "${_green}renamed:${_reset} $old_name -> $name ($dir)"
      else
        echo "${_yellow}goto: already exists: $dir (as '$old_name')${_reset}" >&2
      fi
      return
    fi
    if _goto_dirs | grep -q "^${name}|"; then
      echo "${_yellow}goto: name '$name' is already in use. Choose a different name.${_reset}" >&2
      return 1
    fi
    local short="${dir/#$HOME/~}"
    echo "$name|$short" >> "$config"
    echo "${_green}added:${_reset} $name -> $dir"
    return
  fi

  if [[ "$1" == "rm" || "$1" == "remove" ]]; then
    if [[ -n "$2" ]]; then
      if grep -q "^${2}|" "$config"; then
        local entry=$(grep "^${2}|" "$config")
        awk -v name="$2" -F'|' '!(NF>1 && $1==name)' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
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
      picks=$(_goto_dirs \
        | sed "s|$HOME|~|g" \
        | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}' \
        | fzf --prompt='rm > TAB to multi-select, Enter to remove > ' --multi \
              --height="$fzf_height" --reverse --no-info \
              "${_preview_args[@]}" ${=extra_fzf})
      if [[ -z "$picks" ]]; then
        echo "goto: nothing selected"
        return
      fi
      echo "$picks" | while IFS= read -r line; do
        local name="${line%%[[:space:]]*}"
        awk -v name="$name" -F'|' '!(NF>1 && $1==name)' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
        echo "${_red}removed:${_reset} $name"
      done
    fi
    return
  fi

  if [[ "$1" == "clean" ]]; then
    local cleaned=0
    local tmpfile=$(mktemp)
    while IFS= read -r line; do
      # preserve comments, empty lines, and settings
      if [[ "$line" == \#* || -z "$line" || "$line" == GOTO_* ]]; then
        echo "$line" >> "$tmpfile"
        continue
      fi
      # skip lines that are not directory entries
      if [[ "$line" != *"|"* ]]; then
        echo "$line" >> "$tmpfile"
        continue
      fi
      local path="${line#*|}"
      local full="${path/#~/$HOME}"
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
      local word; (( cleaned == 1 )) && word="entry" || word="entries"
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
    existing=$(_goto_dirs | sed "s|~|$HOME|g" | awk -F'|' '{print $2}')

    local scan_output
    scan_output=$(export LC_ALL=en_US.UTF-8; { \
      grep -a '^cd ' "$histfile" 2>/dev/null | sed 's/^cd //;s/[[:space:]]*$//' | sed "s|^~|$HOME|"; \
      grep -a ';cd ' "$histfile" 2>/dev/null | sed 's/^.*;//;s/^[[:space:]]*cd[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed "s|^~|$HOME|"; \
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
      | fzf --prompt='scan > TAB to multi-select, Enter to add > ' --multi --ansi \
            --height="$fzf_height" --reverse --no-info ${=extra_fzf})

    if [[ -z "$picks" ]]; then
      echo "goto: nothing selected"
      return
    fi

    echo "$picks" | while IFS= read -r line; do
      echo "$line" | grep -q '\[added\]' && continue
      local dir="${line#*x  }"
      local full="${dir/#~/$HOME}"
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
    match=$(_goto_dirs | grep "^$1|" | head -1)
    if [[ -n "$match" ]]; then
      local dir="${match#*|}"
      dir="${dir/#~/$HOME}"
      if [[ -d "$dir" ]]; then
        _goto_log_jump "$dir"
        cd "$dir" || return 1
      else
        echo "${_red}goto: directory no longer exists: $dir${_reset}" >&2
        read -r "answer?Remove '$1' from config? [y/N] "
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          awk -v name="$1" -F'|' '!(NF>1 && $1==name)' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
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
    display=$(_goto_dirs \
      | sed "s|~|$HOME|g" \
      | while IFS='|' read -r name path; do
          local count=0
          count=$(grep -c "  ${path}$" "$logfile" 2>/dev/null)
          count=${count:-0}
          local short="${path/#$HOME/~}"
          printf "%06d\t%-12s >  %s\n" "$count" "$name" "$short"
        done \
      | sort -t$'\t' -k1 -rn \
      | cut -f2-)
  else
    display=$(_goto_dirs \
      | sed "s|$HOME|~|g" \
      | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}')
  fi

  local query="${1:-}"
  local selected
  selected=$(echo "$display" \
    | fzf --prompt='goto > ' --no-multi \
          --height="$fzf_height" --reverse --no-info \
          --query="$query" \
          "${_preview_args[@]}" ${=extra_fzf})

  if [[ -n "$selected" ]]; then
    local dir="${selected#*>  }"
    dir="${dir/#~/$HOME}"
    if [[ -d "$dir" ]]; then
      _goto_log_jump "$dir"
      cd "$dir" || return 1
    else
      echo "${_red}goto: directory no longer exists: $dir${_reset}" >&2
      local name="${selected%%[[:space:]]*}"
      read -r "answer?Remove '$name' from config? [y/N] "
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        awk -v name="$name" -F'|' '!(NF>1 && $1==name)' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
        echo "${_red}removed:${_reset} $name"
      fi
      return 1
    fi
  fi
}

# --- zsh tab completion ---
_goto() {
  local config="${GOTO_CONFIG:-$HOME/.config/goto/config}"

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
      names=(${(f)"$(grep -v '^#' "$config" | grep -v '^$' | grep '|' | awk -F'|' '{print $1}')"})
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
          names=(${(f)"$(grep -v '^#' "$config" | grep -v '^$' | grep '|' | awk -F'|' '{print $1}')"})
        fi
        compadd -a names ;;
    esac
  fi
}

compdef _goto goto
