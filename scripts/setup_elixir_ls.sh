#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lsp_install_common.sh"
lsp_require_linux
lsp_require_commands curl jq unzip erl elixir

install_dir="$(lsp_server_dir)/elixir-ls"
temp_dir="$(lsp_temp_dir)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$install_dir"

printf 'Finding latest ElixirLS release...\n'
release_url="$(curl -fsSL https://api.github.com/repos/elixir-lsp/elixir-ls/releases/latest \
  | jq -er '[.assets[] | select(.name | test("^elixir-ls-.*\\.zip$"))][0].browser_download_url')"
curl -fsSL "$release_url" -o "$temp_dir/elixir-ls.zip"
unzip -oq "$temp_dir/elixir-ls.zip" -d "$install_dir"

server="$install_dir/language_server.sh"
if [[ ! -f "$server" ]]; then
  printf 'ElixirLS archive is missing language_server.sh.\n' >&2
  exit 1
fi
chmod +x "$server"
printf 'ElixirLS is ready: %s\n' "$server"