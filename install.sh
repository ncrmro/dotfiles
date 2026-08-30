#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
packages_dir="${repo_dir}/packages"

if ! command -v stow >/dev/null 2>&1; then
  printf 'GNU stow is required but was not found on PATH.\n' >&2
  exit 1
fi

select_gnu_coreutil() {
  local command_name="$1"
  local candidate
  local version

  for candidate in "g${command_name}" "${command_name}"; do
    command -v "${candidate}" >/dev/null 2>&1 || continue
    version="$("${candidate}" --version 2>/dev/null || true)"
    if [[ "${version}" == *"GNU coreutils"* ]]; then
      command -v "${candidate}"
      return 0
    fi
  done

  printf 'GNU coreutils %s is required. On macOS, run: brew install coreutils\n' \
    "${command_name}" >&2
  return 1
}

if ! realpath_bin="$(select_gnu_coreutil realpath)"; then
  exit 1
fi
if ! mv_bin="$(select_gnu_coreutil mv)"; then
  exit 1
fi
home_dir="$("${realpath_bin}" -m -- "${HOME}")"

check=false
if [[ "${1:-}" == "--check" ]]; then
  check=true
  shift
fi

git_common_dir="$(
  git -C "${repo_dir}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true
)"
if [[ -n "${git_common_dir}" ]]; then
  git_common_dir="$("${realpath_bin}" -m -- "${git_common_dir}")"
fi

retargetable_link() {
  local target="$1"
  local expected="$2"
  local expected_relative="$3"
  local current
  local current_common_dir
  local current_relative
  local current_repo

  [[ -L "${target}" ]] || return 1
  current="$("${realpath_bin}" -m -- "${target}")"
  [[ "${current}" != "${expected}" ]] || return 1
  [[ -e "${current}" ]] || return 1

  current_repo="$(
    git -C "$(dirname "${current}")" rev-parse --show-toplevel 2>/dev/null || true
  )"
  [[ -n "${current_repo}" ]] || return 1
  current_repo="$("${realpath_bin}" -m -- "${current_repo}")"
  current_common_dir="$(
    git -C "${current_repo}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true
  )"
  [[ -n "${current_common_dir}" ]] || return 1
  current_common_dir="$("${realpath_bin}" -m -- "${current_common_dir}")"
  [[ -n "${git_common_dir}" && "${current_common_dir}" == "${git_common_dir}" ]] || return 1

  current_relative="${current#"${current_repo}/"}"
  if [[ "${current_relative}" == "${current}" ]]; then
    return 1
  fi
  if [[ "${current_relative}" != "${expected_relative}" ]]; then
    return 1
  fi
  return 0
}

retarget_link() {
  local target="$1"
  local expected="$2"
  local relative
  local temporary

  relative="$(
    "${realpath_bin}" -m --relative-to="$(dirname "${target}")" "${expected}"
  )"
  temporary="${target}.dotfiles-retarget.$$"
  ln -s "${relative}" "${temporary}"
  "${mv_bin}" -Tf -- "${temporary}" "${target}"
}

planned_leaf_target() {
  local candidate="$1"
  local planned

  for planned in "${targets[@]}"; do
    if [[ "${planned}" == "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

validate_parent_chain() {
  local target="$1"
  local component
  local current="${home_dir}"
  local parent_relative
  local relative="${target#"${home_dir}/"}"
  local -a components=()

  [[ "${relative}" != "${target}" ]] || {
    printf 'Target is outside HOME: %s\n' "${target}" >&2
    return 1
  }
  parent_relative="${relative%/*}"
  [[ "${parent_relative}" != "${relative}" ]] || return 0
  IFS='/' read -r -a components <<<"${parent_relative}"

  for component in "${components[@]}"; do
    current="${current}/${component}"
    if planned_leaf_target "${current}"; then
      printf 'Target is also required as a parent directory: %s\n' "${current}" >&2
      return 1
    fi
    if [[ -L "${current}" ]]; then
      if [[ -e "${current}" ]]; then
        printf 'Parent directory is a symlink: %s -> %s\n' \
          "${current}" "$("${realpath_bin}" -m -- "${current}")" >&2
      else
        printf 'Parent directory is a broken symlink: %s\n' "${current}" >&2
      fi
      return 1
    fi
    if [[ -e "${current}" && ! -d "${current}" ]]; then
      printf 'Parent path is not a directory: %s\n' "${current}" >&2
      return 1
    fi
  done
}

if (( $# > 0 )); then
  selected=("$@")
else
  selected=(git ssh zsh)
fi

selected_packages=()
for package in "${selected[@]}"; do
  for selected_package in "${selected_packages[@]}"; do
    if [[ "${selected_package}" == "${package}" ]]; then
      printf 'Duplicate dotfiles package: %s\n' "${package}" >&2
      exit 1
    fi
  done
  selected_packages+=("${package}")
  if [[ ! -d "${packages_dir}/${package}" ]]; then
    printf 'Unknown dotfiles package: %s\n' "${package}" >&2
    exit 1
  fi
done

stow_args=(
  --dir "${packages_dir}"
  --target "${home_dir}"
  --no-folding
  --restow
)

sources=()
targets=()
expected_relatives=()
for package in "${selected[@]}"; do
  package_dir="${packages_dir}/${package}"
  while IFS= read -r -d '' source; do
    relative="${source#"${package_dir}/"}"
    target="${home_dir}/${relative}"
    expected_relative="packages/${package}/${relative}"
    for ((i = 0; i < ${#targets[@]}; i++)); do
      if [[ "${targets[i]}" == "${target}" ]]; then
        printf 'Duplicate target: %s (%s and %s)\n' \
          "${target}" "${sources[i]}" "${source}" >&2
        exit 1
      fi
    done
    sources+=("${source}")
    targets+=("${target}")
    expected_relatives+=("${expected_relative}")
  done < <(find "${package_dir}" \( -type f -o -type l \) -print0)
done

broken=0
retargets=()
for ((i = 0; i < ${#sources[@]}; i++)); do
  source="${sources[i]}"
  target="${targets[i]}"
  expected_relative="${expected_relatives[i]}"
  expected="$("${realpath_bin}" -m -- "${source}")"

  if ! validate_parent_chain "${target}"; then
    broken=1
    continue
  fi
  if [[ -L "${target}" ]]; then
    resolved="$("${realpath_bin}" -m -- "${target}")"
    if [[ "${resolved}" != "${expected}" ]]; then
      if retargetable_link "${target}" "${expected}" "${expected_relative}"; then
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
done

if [[ "${broken}" -ne 0 ]]; then
  exit "${broken}"
fi

if [[ "${check}" == true ]]; then
  # This explicit walk is the authoritative collision check. GNU Stow's
  # simulation rejects a safe sibling-worktree transition based on the link's
  # lexical spelling even when both sources have identical repository paths.
  exit 0
fi

# No link is changed until every selected package, target, and parent passes.
for ((i = 0; i < ${#retargets[@]}; i += 2)); do
  retarget_link "${retargets[i]}" "${retargets[i + 1]}"
done

stow "${stow_args[@]}" "${selected[@]}"
