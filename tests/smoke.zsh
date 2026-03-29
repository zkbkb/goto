#!/usr/bin/env zsh

set -eu

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"
TARGET="${REPO_DIR}/goto.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  [[ "$actual" == "$expected" ]] || fail "${message}: expected '${expected}', got '${actual}'"
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  local message="$3"
  grep -qF -- "$expected" "$file" || fail "${message}: missing '${expected}' in ${file}"
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"
  local message="$3"
  if grep -qF -- "$unexpected" "$file"; then
    fail "${message}: found unexpected '${unexpected}' in ${file}"
  fi
}

physical_path() {
  builtin cd "$1" 2>/dev/null && pwd -P
}

make_stub_fzf() {
  local bin_dir="$1"
  cat > "${bin_dir}/fzf" <<'EOF'
#!/bin/sh
cat
EOF
  chmod +x "${bin_dir}/fzf"
}

test_source_without_compdef() {
  zsh -df -c "source '$TARGET'"
}

test_exact_name_match() {
  local tmpdir
  local physical_tmp
  tmpdir="$(mktemp -d /tmp/goto-test-regex.XXXXXX)"
  physical_tmp="$(physical_path "$tmpdir")"
  mkdir -p "${tmpdir}/home/.config/goto" "${tmpdir}/axb" "${tmpdir}/a.b"
  cat > "${tmpdir}/home/.config/goto/config" <<EOF
axb|${tmpdir}/axb
a.b|${tmpdir}/a.b
EOF

  local result
  result="$(env HOME="${tmpdir}/home" GOTO_CONFIG="${tmpdir}/home/.config/goto/config" zsh -lc "source '$TARGET'; goto 'a.b'; pwd")"
  assert_eq "$result" "${physical_tmp}/a.b" "exact name matching should not treat names as regex"
}

test_rename_conflict_is_rejected() {
  local tmpdir
  tmpdir="$(mktemp -d /tmp/goto-test-rename.XXXXXX)"
  mkdir -p "${tmpdir}/home/.config/goto" "${tmpdir}/a" "${tmpdir}/b"
  cat > "${tmpdir}/home/.config/goto/config" <<EOF
old|${tmpdir}/a
keep|${tmpdir}/b
EOF

  env HOME="${tmpdir}/home" GOTO_CONFIG="${tmpdir}/home/.config/goto/config" TEST_DIR="${tmpdir}/a" TEST_CONFIG="${tmpdir}/home/.config/goto/config" zsh -lc "source '$TARGET'; goto add \"\$TEST_DIR\" keep >/dev/null 2>&1 || true"
  assert_file_contains "${tmpdir}/home/.config/goto/config" "old|${tmpdir}/a" "rename conflict should keep original entry"
  assert_file_contains "${tmpdir}/home/.config/goto/config" "keep|${tmpdir}/b" "rename conflict should preserve conflicting entry"
}

test_custom_config_uses_local_logfile() {
  local tmpdir
  local physical_tmp
  tmpdir="$(mktemp -d /tmp/goto-test-log.XXXXXX)"
  physical_tmp="$(physical_path "$tmpdir")"
  mkdir -p "${tmpdir}/custom"
  cat > "${tmpdir}/custom/config" <<EOF
here|${tmpdir}
EOF

  env HOME="${tmpdir}/home" GOTO_CONFIG="${tmpdir}/custom/config" TEST_LOG="${tmpdir}/custom/log" zsh -lc "source '$TARGET'; goto here >/dev/null; test -f \"\$TEST_LOG\""
  assert_file_contains "${tmpdir}/custom/log" "[jump]  ${physical_tmp}" "custom config should write jump logs beside the config"
}

test_scan_generates_unique_names() {
  local tmpdir
  local physical_tmp
  tmpdir="$(mktemp -d /tmp/goto-test-scan.XXXXXX)"
  physical_tmp="$(physical_path "$tmpdir")"
  mkdir -p "${tmpdir}/home/.config/goto" "${tmpdir}/bin" "${tmpdir}/one/foo" "${tmpdir}/two/foo"
  cat > "${tmpdir}/home/.config/goto/config" <<'EOF'
# empty config
EOF
  cat > "${tmpdir}/home/.zsh_history" <<EOF
: 1:0;cd ${tmpdir}/one/foo
: 2:0;cd ${tmpdir}/two/foo
EOF
  make_stub_fzf "${tmpdir}/bin"

  env HOME="${tmpdir}/home" PATH="${tmpdir}/bin:${PATH}" GOTO_CONFIG="${tmpdir}/home/.config/goto/config" zsh -lc "source '$TARGET'; goto scan >/dev/null"
  assert_file_contains "${tmpdir}/home/.config/goto/config" "foo|${physical_tmp}/" "scan should keep the first basename"
  assert_file_contains "${tmpdir}/home/.config/goto/config" "foo-2|${physical_tmp}/" "scan should suffix duplicate basenames"
}

test_interactive_remove_supports_spaces() {
  local tmpdir
  tmpdir="$(mktemp -d /tmp/goto-test-space.XXXXXX)"
  mkdir -p "${tmpdir}/home/.config/goto" "${tmpdir}/dir with space" "${tmpdir}/bin"
  cat > "${tmpdir}/home/.config/goto/config" <<EOF
name with space|${tmpdir}/dir with space
EOF
  make_stub_fzf "${tmpdir}/bin"

  env HOME="${tmpdir}/home" PATH="${tmpdir}/bin:${PATH}" GOTO_CONFIG="${tmpdir}/home/.config/goto/config" zsh -lc "source '$TARGET'; goto rm >/dev/null"
  assert_file_not_contains "${tmpdir}/home/.config/goto/config" "name with space|" "interactive removal should handle names with spaces"
}

test_source_without_compdef
test_exact_name_match
test_rename_conflict_is_rejected
test_custom_config_uses_local_logfile
test_scan_generates_unique_names
test_interactive_remove_supports_spaces

print -- "smoke tests passed"
