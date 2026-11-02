#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lsp_install_common.sh"
lsp_require_linux
lsp_require_commands curl jq tar erl

case "$(uname -m)" in
  x86_64) elp_arch="x86_64" ;;
  aarch64) elp_arch="aarch64" ;;
  *)
    printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

otp_major="$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' 2>/dev/null)"
install_dir="$(lsp_server_dir)/elp"
temp_dir="$(lsp_temp_dir)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$install_dir" "$temp_dir/archive"

printf 'Finding latest ELP release for Linux %s and OTP %s...\n' "$elp_arch" "$otp_major"
release="$(curl -fsSL https://api.github.com/repos/WhatsApp/erlang-language-platform/releases/latest)"
release_url="$(jq -er --arg arch "$elp_arch" --arg otp "$otp_major" '
  [.assets[]
    | select(.name | startswith("elp-linux-" + $arch + "-unknown-linux-gnu-otp-" + $otp + "."))
    | select(.name | endswith(".tar.gz"))]
  | sort_by(.name)
  | last
  | .browser_download_url
' <<<"$release")"
curl -fsSL "$release_url" -o "$temp_dir/elp.tar.gz"
tar -xzf "$temp_dir/elp.tar.gz" -C "$temp_dir/archive"

elp_binary="$(find "$temp_dir/archive" -type f -name elp -print -quit)"
if [[ -z "$elp_binary" ]]; then
  printf 'ELP archive is missing the elp executable.\n' >&2
  exit 1
fi
install -m 755 "$elp_binary" "$install_dir/elp"
printf 'ELP is ready: %s\n' "$install_dir/elp"