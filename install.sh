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
retarget_temporary=""
retarget_batch_active=false
retarget_committed=0
retarget_in_flight=-1
stow_active=false
stow_packages=""
stow_control_dir=""

cleanup_retarget_temporary() {
  if [[ -n "${retarget_temporary}" && -L "${retarget_temporary}" ]]; then
    rm -f "${retarget_temporary}"
  fi
  retarget_temporary=""
}

cleanup_installer() {
  cleanup_retarget_temporary
  if [[ -n "${stow_control_dir}" && -d "${stow_control_dir}" ]]; then
    rm -rf "${stow_control_dir}"
  fi
  stow_control_dir=""
}

exit_for_signal() {
  local status="$1"
  local signal_name="$2"
  local rollback_last

  trap - HUP INT TERM
  cleanup_retarget_temporary
  if [[ "${stow_active}" == true ]]; then
    stow_active=false
    printf 'Interrupted by %s while Stow was restowing packages: %s. Stow changes are not transactional; rerun: %s/install.sh %s\n' \
      "${signal_name}" "${stow_packages}" "${repo_dir}" "${stow_packages}" >&2
    exit "${status}"
  fi
  if [[ "${retarget_batch_active}" == true \
    && ( "${retarget_committed}" -gt 0 || "${retarget_in_flight}" -ge 0 ) ]]; then
    retarget_batch_active=false
    rollback_last=$((retarget_committed - 1))
    if [[ "${retarget_in_flight}" -gt "${rollback_last}" ]]; then
      rollback_last="${retarget_in_flight}"
    fi
    printf 'Interrupted by %s; rolling back %d retarget(s), including any in-flight move.\n' \
      "${signal_name}" "$((rollback_last + 1))" >&2
    if ! rollback_retargets "${rollback_last}"; then
      printf 'Interrupt rollback was incomplete; inspect the reported links.\n' >&2
    fi
  fi

  exit "${status}"
}

trap cleanup_installer EXIT
trap 'exit_for_signal 129 HUP' HUP
trap 'exit_for_signal 130 INT' INT
trap 'exit_for_signal 143 TERM' TERM

check=false
if [[ "${1:-}" == "--check" ]]; then
  check=true
  shift
fi

if ! repo_top="$(git -C "${repo_dir}" rev-parse --show-toplevel 2>/dev/null)"; then
  printf 'The dotfiles installer must be inside a Git worktree: %s\n' \
    "${repo_dir}" >&2
  exit 1
fi
repo_top="$("${realpath_bin}" -m -- "${repo_top}")"
if [[ "${repo_top}" != "${repo_dir}" ]]; then
  printf 'The dotfiles installer must be at the repository root: %s (found %s)\n' \
    "${repo_dir}" "${repo_top}" >&2
  exit 1
fi
if [[ ! -d "${repo_top}/packages" || "${packages_dir}" != "${repo_top}/packages" ]]; then
  printf 'The repository root must contain the dotfiles packages directory: %s\n' \
    "${repo_top}/packages" >&2
  exit 1
fi
if ! git_common_dir="$(
  git -C "${repo_top}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
)"; then
  printf 'Git 2.31 or newer is required to resolve dotfiles worktree ownership: %s\n' \
    "${repo_top}" >&2
  exit 1
fi
git_common_dir="$("${realpath_bin}" -m -- "${git_common_dir}")"

retargetable_link() {
  local target="$1"
  local expected_relative="$2"
  local current
  local current_common_dir
  local current_relative
  local current_repo

  [[ -L "${target}" ]] || return 1
  current="$("${realpath_bin}" -m -- "${target}")"
  [[ -e "${current}" ]] || return 1

  if ! current_repo="$(
    git -C "$(dirname "${current}")" rev-parse --show-toplevel 2>/dev/null
  )"; then
    printf 'Linked source is not inside a Git worktree: %s\n' "${current}" >&2
    return 1
  fi
  current_repo="$("${realpath_bin}" -m -- "${current_repo}")"
  if ! current_common_dir="$(
    git -C "${current_repo}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
  )"; then
    printf 'Git 2.31 or newer is required to inspect linked worktree ownership: %s\n' \
      "${current_repo}" >&2
    return 1
  fi
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

replace_link() {
  local target="$1"
  local link_value="$2"
  local temporary

  temporary="${target}.dotfiles-retarget.$$"
  if [[ -e "${temporary}" || -L "${temporary}" ]]; then
    printf 'Temporary retarget path already exists: %s\n' "${temporary}" >&2
    return 1
  fi
  retarget_temporary="${temporary}"
  ln -s "${link_value}" "${temporary}"
  if ! "${mv_bin}" -Tf -- "${temporary}" "${target}"; then
    cleanup_retarget_temporary
    return 1
  fi
  retarget_temporary=""
  return 0
}

retarget_link() {
  local target="$1"
  local expected="$2"
  local relative

  relative="$(
    "${realpath_bin}" -m --relative-to="$(dirname "${target}")" "${expected}"
  )"
  replace_link "${target}" "${relative}"
}

rollback_retargets() {
  local last_index="$1"
  local rollback_failed=0
  local rollback_i

  for ((rollback_i = last_index; rollback_i >= 0; rollback_i--)); do
    if ! replace_link \
      "${retarget_targets[rollback_i]}" "${retarget_originals[rollback_i]}"; then
      printf 'Rollback failed for retargeted link: %s\n' \
        "${retarget_targets[rollback_i]}" >&2
      rollback_failed=1
    fi
  done
  return "${rollback_failed}"
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
  for ((selected_i = 0; selected_i < ${#selected_packages[@]}; selected_i++)); do
    if [[ "${selected_packages[selected_i]}" == "${package}" ]]; then
      printf 'Duplicate dotfiles package: %s\n' "${package}" >&2
      exit 1
    fi
  done
  selected_packages+=("${package}")
  if [[ ! -d "${packages_dir}/${package}" ]]; then
    printf 'Unknown dotfiles package: %s\n' "${package}" >&2
    exit 1
  fi
  if [[ -e "${packages_dir}/${package}/.stow-local-ignore" \
    || -L "${packages_dir}/${package}/.stow-local-ignore" ]]; then
    printf 'Selected package must not contain .stow-local-ignore: %s\n' \
      "${packages_dir}/${package}/.stow-local-ignore" >&2
    exit 1
  fi
done

# Stow can create empty directories and handle special entries in ways this
# leaf-oriented preflight cannot certify. Reject them before planning retargets.
for package in "${selected[@]}"; do
  package_dir="${packages_dir}/${package}"
  while IFS= read -r -d '' entry; do
    if [[ -L "${entry}" ]]; then
      continue
    fi
    if [[ -d "${entry}" ]]; then
      if [[ -z "$(find "${entry}" -mindepth 1 -maxdepth 1 -print)" ]]; then
        printf 'Package tree contains an empty directory: %s\n' "${entry}" >&2
        exit 1
      fi
      continue
    fi
    if [[ -f "${entry}" ]]; then
      continue
    fi
    printf 'Package tree contains an unsupported entry type: %s\n' "${entry}" >&2
    exit 1
  done < <(find "${package_dir}" -print0)
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
    if [[ -L "${source}" ]]; then
      printf 'Package source symlinks are unsupported: %s\n' "${source}" >&2
      exit 1
    fi
    relative="${source#"${package_dir}/"}"
    target="${home_dir}/${relative}"
    expected_relative="${source#"${repo_top}/"}"
    if [[ "${expected_relative}" == "${source}" ]]; then
      printf 'Package source is outside the repository root: %s\n' "${source}" >&2
      exit 1
    fi
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
retarget_targets=()
retarget_expecteds=()
retarget_originals=()
for ((i = 0; i < ${#sources[@]}; i++)); do
  source="${sources[i]}"
  target="${targets[i]}"
  expected_relative="${expected_relatives[i]}"
  expected="$("${realpath_bin}" -m -- "${source}")"
  expected_link="$(
    "${realpath_bin}" -m --relative-to="$(dirname "${target}")" "${expected}"
  )"

  if ! validate_parent_chain "${target}"; then
    broken=1
    continue
  fi
  if [[ -L "${target}" ]]; then
    resolved="$("${realpath_bin}" -m -- "${target}")"
    current_link="$(readlink "${target}")"
    if [[ "${current_link}" != "${expected_link}" ]]; then
      if retargetable_link "${target}" "${expected_relative}"; then
        retarget_targets+=("${target}")
        retarget_expecteds+=("${expected}")
        retarget_originals+=("${current_link}")
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
  # This walk certifies enumerated leaf/parent collisions and owned retargets.
  # It deliberately does not predict obsolete-link removals made by --restow.
  for ((i = 0; i < ${#retarget_targets[@]}; i++)); do
    relative="$(
      "${realpath_bin}" -m \
        --relative-to="$(dirname "${retarget_targets[i]}")" "${retarget_expecteds[i]}"
    )"
    printf 'Would retarget: %s -> %s\n' "${retarget_targets[i]}" "${relative}"
  done
  exit 0
fi

# No retarget is changed until every selected leaf, parent, and owner passes.
# If an atomic move fails, restore every link moved earlier in this batch.
retarget_batch_active=true
for ((i = 0; i < ${#retarget_targets[@]}; i++)); do
  retarget_in_flight="${i}"
  if ! retarget_link "${retarget_targets[i]}" "${retarget_expecteds[i]}"; then
    retarget_in_flight=-1
    retarget_batch_active=false
    printf 'Failed to retarget link: %s; rolling back %d earlier link(s).\n' \
      "${retarget_targets[i]}" "${i}" >&2
    if ! rollback_retargets "$((i - 1))"; then
      printf 'Retarget rollback was incomplete; inspect the reported links.\n' >&2
    fi
    exit 1
  fi
  retarget_committed=$((i + 1))
  retarget_in_flight=-1
done
retarget_batch_active=false

# Stow reads both $PWD/.stowrc and $HOME/.stowrc. Run it from an empty,
# disposable directory with a controlled HOME so only the validated arguments
# can affect the certified plan.
stow_control_dir="$(
  mktemp -d "${TMPDIR:-/tmp}/dotfiles-stow-control.XXXXXXXXXX"
)"
: >"${stow_control_dir}/.stow-global-ignore"
stow_packages="${selected[*]}"
stow_working_dir="$(pwd -P)"
cd "${stow_control_dir}"
stow_active=true
HOME="${stow_control_dir}" stow "${stow_args[@]}" "${selected[@]}"
stow_active=false
cd "${stow_working_dir}"
