#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
check=false
if [[ "${1:-}" == "--check" ]]; then
  check=true
  shift
fi
for argument in "$@"; do
  if [[ "${argument}" == -* ]]; then
    printf 'Unsupported option: %s. Usage: install.sh [--check] [PACKAGE ...]
' "${argument}" >&2
    exit 2
  fi
done
if (( $# == 0 )); then
  set -- git ssh zsh
fi

if [[ "${check}" == true ]]; then
  set -- --check "$@"
fi

if ! command -v ks-stow-dotfiles >/dev/null 2>&1; then
  printf 'ks-stow-dotfiles is required. Install the shared dotfiles tool from ks.systems/terminal (included with Keystone Terminal).
' >&2
  exit 1
fi
exec ks-stow-dotfiles --repo "${repo_dir}" --target "${HOME}" "$@"
