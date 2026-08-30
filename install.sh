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

git_common_dir="$(git -C "${repo_dir}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"

same_repository_source() {
  local source="$1"
  local source_repo
  local source_common_dir

  source_repo="$(git -C "$(dirname "${source}")" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "${source_repo}" ]] || return 1
  source_common_dir="$(git -C "${source_repo}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [[ -n "${git_common_dir}" && "${source_common_dir}" == "${git_common_dir}" ]]
}

retargetable_link() {
  local target="$1"
  local expected="$2"
  local current
  local relative

  [[ -L "${target}" ]] || return 1
  current="$(realpath -m "${target}")"
  [[ "${current}" != "${expected}" ]] || return 1
  same_repository_source "${current}" || return 1

  for package in "${selected[@]}"; do
    relative="${expected#"${packages_dir}/${package}/"}"
    if [[ "${relative}" != "${expected}" && "${current}" == */packages/"${package}"/"${relative}" ]]; then
      return 0
    fi
  done
  return 1
}

retarget_link() {
  local target="$1"
  local expected="$2"
  local temporary
  local relative

  relative="$(realpath -m --relative-to="$(dirname "${target}")" "${expected}")"
  temporary="${target}.dotfiles-retarget.$$"
  ln -s "${relative}" "${temporary}"
  mv -Tf "${temporary}" "${target}"
}

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

broken=0
retargets=()
for package in "${selected[@]}"; do
  while IFS= read -r source; do
    relative="${source#"${packages_dir}/${package}/"}"
    target="${HOME}/${relative}"
    expected="$(realpath -m "${source}")"
    if [[ -L "${target}" ]]; then
      resolved="$(realpath -m "${target}")"
      if [[ "${resolved}" != "${expected}" ]]; then
        if retargetable_link "${target}" "${expected}"; then
          retargets+=("${target}" "${expected}")
        else
          printf 'Unexpected link target: %s -> %s (expected %s)\n' \
            "${target}" "${resolved}" "${expected}" >&2
          broken=1
        fi
      fi
    elif [[ -e "${target}" ]]; then
      printf 'Target is not a symlink: %s\n' "${target}" >&2
      broken=1
    fi
  done < <(find "${packages_dir}/${package}" \( -type f -o -type l \) -print)
done

if [[ "${broken}" -ne 0 ]]; then
  exit "${broken}"
fi

if [[ "${check}" == true ]]; then
  # The explicit leaf walk is the authoritative collision check. GNU Stow's
  # simulation compares a link's lexical spelling and rejects a safe sibling
  # worktree transition even when both links resolve to the same repo-relative
  # package file.
  exit 0
fi

for ((i = 0; i < ${#retargets[@]}; i += 2)); do
  retarget_link "${retargets[i]}" "${retargets[i + 1]}"
done

stow "${stow_args[@]}" "${selected[@]}"
