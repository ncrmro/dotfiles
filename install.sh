#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packages_dir="${repo_dir}/packages"

if ! command -v stow >/dev/null 2>&1; then
  printf 'GNU stow is required but was not found on PATH.\n' >&2
  exit 1
fi

check=false
if [[ "${1:-}" == "--check" ]]; then
  check=true
  shift
fi

if (( $# > 0 )); then
  selected=("$@")
else
  selected=(git ssh zsh)
fi

for package in "${selected[@]}"; do
  if [[ ! -d "${packages_dir}/${package}" ]]; then
    printf 'Unknown dotfiles package: %s\n' "${package}" >&2
    exit 1
  fi
done

stow_args=(
  --dir "${packages_dir}"
  --target "${HOME}"
  --no-folding
  --restow
)

if [[ "${check}" == true ]]; then
  stow "${stow_args[@]}" --simulate "${selected[@]}"

  broken=0
  for package in "${selected[@]}"; do
    while IFS= read -r source; do
      relative="${source#"${packages_dir}/${package}/"}"
      target="${HOME}/${relative}"
      if [[ -L "${target}" ]]; then
        resolved="$(realpath -m "${target}")"
        expected="$(realpath -m "${source}")"
        if [[ "${resolved}" != "${expected}" ]]; then
          printf 'Unexpected link target: %s -> %s (expected %s)\n' \
            "${target}" "${resolved}" "${expected}" >&2
          broken=1
        fi
      elif [[ -e "${target}" ]]; then
        printf 'Target is not a symlink: %s\n' "${target}" >&2
        broken=1
      fi
    done < <(find "${packages_dir}/${package}" \( -type f -o -type l \) -print)
  done
  exit "${broken}"
fi

stow "${stow_args[@]}" "${selected[@]}"
