GOTO_VERSION="0.1.0"

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
    local dir=$(cd "$target" 2>/dev/null && pwd)
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
