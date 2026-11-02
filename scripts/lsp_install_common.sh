#!/usr/bin/env bash

lsp_require_commands() {
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'Missing required command: %s\n' "$tool" >&2
      return 1
    fi
  done
}

lsp_require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    printf 'These setup scripts currently support Linux only.\n' >&2
    return 1
  fi
}

lsp_server_dir() {
  printf '%s/nvim/servers' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

lsp_temp_dir() {
  mktemp -d
}