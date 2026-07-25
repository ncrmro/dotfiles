#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packages_dir="${repo_dir}/packages"

if ! command -v stow >/dev/null 2>&1; then
  printf 'GNU stow is required but was not found on PATH.\n' >&2
  exit 1
fi

if (( $# > 0 )); then
  selected=("$@")
else
  selected=(git ssh hyprland)
fi

stow \
  --dir "${packages_dir}" \
  --target "${HOME}" \
  --no-folding \
  --restow \
  "${selected[@]}"
