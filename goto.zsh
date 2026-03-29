GOTO_VERSION="0.2.0"

goto() {
  local config="${GOTO_CONFIG:-$HOME/.config/goto/dirs}"

  if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "goto $GOTO_VERSION"
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

  if [[ "$1" == "add" ]]; then
    local target="${2:-.}"
    local dir=$(builtin cd "$target" 2>/dev/null && pwd -P)
    if [[ -z "$dir" ]]; then
      echo "goto: not a valid directory: $target" >&2
      return 1
    fi
    local name="${dir##*/}"
    if sed "s|~|$HOME|g" "$config" | grep -qF "|$dir"; then
      echo "goto: already exists: $dir" >&2
      return 1
    fi
    echo "$name|$dir" >> "$config"
    echo "added: $name -> $dir"
    return
  fi

  if [[ "$1" == "scan" ]]; then
    local histfile="${HISTFILE:-$HOME/.zsh_history}"
    if [[ ! -f "$histfile" ]]; then
      echo "goto: history file not found: $histfile" >&2
      return 1
    fi

    # extract cd targets, normalize to absolute paths, rank by frequency
    local existing
    existing=$(sed "s|~|$HOME|g" "$config" | grep -v '^#' | grep -v '^$' | awk -F'|' '{print $2}')

    local picks
    picks=$(export LC_ALL=en_US.UTF-8; grep '^cd ' "$histfile" 2>/dev/null \
      | sed 's/^cd //' 2>/dev/null \
      | sed 's/[[:space:]]*$//' 2>/dev/null \
      | sed "s|^~|$HOME|" 2>/dev/null \
      | sort | uniq -c | sort -rn \
      | while read -r count dir; do
          [[ -z "$dir" ]] && continue
          local short="${dir/#$HOME/~}"
          local tag=""
          if ! [[ -d "$dir" ]]; then
            tag=" [missing]"
          elif echo "$existing" | grep -qxF "$dir"; then
            tag=" [added]"
          fi
          printf "%3sx  %s%s\n" "$count" "$short" "$tag"
        done \
      | fzf --prompt='scan > TAB to multi-select, Enter to add > ' --multi --height=~50% --reverse --no-info)

    if [[ -z "$picks" ]]; then
      echo "goto: nothing selected"
      return
    fi

    echo "$picks" | while IFS= read -r line; do
      echo "$line" | grep -qE '\[(added|missing)\]' && continue
      local dir="${line#*x  }"
      local full="${dir/#\~/$HOME}"
      local name="${full##*/}"
      echo "$name|$dir" >> "$config"
      echo "added: $name -> $dir"
    done
    return
  fi

  local selected
  selected=$(grep -v '^#' "$config" | grep -v '^$' \
    | sed "s|$HOME|~|g" \
    | awk -F'|' '{printf "%-12s >  %s\n", $1, $2}' \
    | fzf --prompt='goto > ' --no-multi --height=~50% --reverse --no-info)

  if [[ -n "$selected" ]]; then
    local dir="${selected#*>  }"
    dir="${dir/#\~/$HOME}"
    cd "$dir" || return 1
  fi
}
