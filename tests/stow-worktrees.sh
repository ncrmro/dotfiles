#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

git clone -q --no-hardlinks "${repo_dir}" "${test_root}/canonical"
git -C "${test_root}/canonical" worktree add -q -b test/sibling "${test_root}/sibling"
# Tests can run before this change is committed, so use the implementation
# under test in both disposable checkouts.
cp "${repo_dir}/install.sh" "${test_root}/canonical/install.sh"
cp "${repo_dir}/install.sh" "${test_root}/sibling/install.sh"

select_test_gnu_coreutil() {
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
  return 1
}

test_realpath="$(select_test_gnu_coreutil realpath)"
test_mv="$(select_test_gnu_coreutil mv)"
coreutils_shim="${test_root}/coreutils-shim"
coreutils_shim_log="${test_root}/coreutils-shim.log"
mkdir -p "${coreutils_shim}"
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "${1-}" != --version ]; then' \
  '  printf grealpath >>"${COREUTILS_SHIM_LOG}"' \
  '  for argument do printf "\t%s" "${argument}" >>"${COREUTILS_SHIM_LOG}"; done' \
  '  printf "\n" >>"${COREUTILS_SHIM_LOG}"' \
  'fi' \
  "exec \"${test_realpath}\" \"\$@\"" \
  >"${coreutils_shim}/grealpath"
printf '%s\n' \
  '#!/bin/sh' \
  'if [ "${1-}" != --version ]; then' \
  '  printf gmv >>"${COREUTILS_SHIM_LOG}"' \
  '  for argument do printf "\t%s" "${argument}" >>"${COREUTILS_SHIM_LOG}"; done' \
  '  printf "\n" >>"${COREUTILS_SHIM_LOG}"' \
  'fi' \
  "exec \"${test_mv}\" \"\$@\"" \
  >"${coreutils_shim}/gmv"
chmod +x "${coreutils_shim}/grealpath" "${coreutils_shim}/gmv"

assert_target() {
  local target="$1"
  local expected="$2"

  test "$("${test_realpath}" -m -- "${target}")" = \
    "$("${test_realpath}" -m -- "${expected}")"
}

snapshot_home() {
  local home="$1"
  local path

  (
    cd "${home}"
    while IFS= read -r path; do
      [[ "${path}" == . ]] && continue
      if [[ -L "${path}" ]]; then
        printf 'link %s -> %s\n' "${path}" "$(readlink "${path}")"
      elif [[ -f "${path}" ]]; then
        printf 'file %s ' "${path}"
        cksum <"${path}"
      elif [[ -d "${path}" ]]; then
        printf 'directory %s\n' "${path}"
      else
        printf 'other %s\n' "${path}"
      fi
    done < <(find . -print | LC_ALL=C sort)
  )
}

assert_check_rejected() {
  local home="$1"
  local installer="$2"
  local why="$3"
  local after
  local before
  shift 3

  before="$(snapshot_home "${home}")"
  if HOME="${home}" "${installer}" --check "$@" >/dev/null 2>&1; then
    printf '%s was accepted\n' "${why}" >&2
    exit 1
  fi
  after="$(snapshot_home "${home}")"
  if [[ "${after}" != "${before}" ]]; then
    printf '%s mutated HOME during --check\n' "${why}" >&2
    diff -u <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&2 || true
    exit 1
  fi
}

new_home() {
  local name="$1"
  local home="${test_root}/homes/${name}"

  mkdir -p "${home}"
  printf '%s\n' "${home}"
}

home="$(new_home transitions)"
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/canonical/packages/git/.config/git/config"

# canonical -> worktree: check is non-mutating, install atomically retargets.
before="$(readlink "${home}/.config/git/config")"
HOME="${home}" "${test_root}/sibling/install.sh" --check git
test "$(readlink "${home}/.config/git/config")" = "${before}"
: >"${coreutils_shim_log}"
COREUTILS_SHIM_LOG="${coreutils_shim_log}" \
  PATH="${coreutils_shim}:${PATH}" \
  HOME="${home}" \
  "${test_root}/sibling/install.sh" git
grep -Eq $'^grealpath\t-m\t--\t' "${coreutils_shim_log}"
grep -Eq $'^gmv\t-Tf\t--\t.*[.]dotfiles-retarget[.][0-9]+\t.*/[.]config/git/config$' \
  "${coreutils_shim_log}"
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/sibling/packages/git/.config/git/config"

# Unchanged links are accepted, then worktree -> canonical is symmetric.
HOME="${home}" "${test_root}/sibling/install.sh" --check git
HOME="${home}" "${test_root}/canonical/install.sh" --check git
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/canonical/packages/git/.config/git/config"

home="$(new_home leaf-collisions)"
mkdir -p "${home}/.config/git"
ln -s /tmp/unrelated "${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "unrelated symlink" git
rm "${home}/.config/git/config"
ln -s /tmp/missing-dotfiles-source "${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "broken leaf symlink" git
rm "${home}/.config/git/config"
printf 'collision\n' >"${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "regular-file collision" git

# A same-repository path with the old accepted suffix is not package ownership.
home="$(new_home suffix-collision)"
mkdir -p \
  "${home}/.config/git" \
  "${test_root}/canonical/unrelated/packages/git/.config/git"
cp \
  "${test_root}/canonical/packages/git/.config/git/config" \
  "${test_root}/canonical/unrelated/packages/git/.config/git/config"
ln -s \
  "${test_root}/canonical/unrelated/packages/git/.config/git/config" \
  "${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "suffix-only ownership" git

# An exact package-relative path in a worktree from another clone is unrelated.
git clone -q --no-hardlinks "${repo_dir}" "${test_root}/unrelated-canonical"
git -C "${test_root}/unrelated-canonical" worktree add -q -b test/unrelated \
  "${test_root}/unrelated-worktree"
home="$(new_home unrelated-worktree)"
mkdir -p "${home}/.config/git"
ln -s \
  "${test_root}/unrelated-worktree/packages/git/.config/git/config" \
  "${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "unrelated worktree" git

home="$(new_home parent-collisions)"
printf 'not a directory\n' >"${home}/.config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "regular parent" git
rm "${home}/.config"
mkdir -p "${test_root}/foreign-config"
ln -s "${test_root}/foreign-config" "${home}/.config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "foreign directory symlink" git
rm "${home}/.config"
ln -s "${test_root}/missing-config" "${home}/.config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "broken parent symlink" git

home="$(new_home package-errors)"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "missing package" missing
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "duplicate package" git git
cp -a "${test_root}/canonical/packages/git" \
  "${test_root}/canonical/packages/duplicate-git"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "duplicate target" git duplicate-git

# A later collision prevents an earlier valid worktree link from retargeting.
home="$(new_home complete-pass)"
HOME="${home}" "${test_root}/canonical/install.sh" git ssh
mkdir -p "${home}/collision"
mv "${home}/.ssh/config" "${home}/collision/ssh-config-link"
printf 'collision\n' >"${home}/.ssh/config"
git_link_before="$(readlink "${home}/.config/git/config")"
if HOME="${home}" "${test_root}/sibling/install.sh" git ssh >/dev/null 2>&1; then
  printf 'installation with a later collision succeeded\n' >&2
  exit 1
fi
test "$(readlink "${home}/.config/git/config")" = "${git_link_before}"
test -f "${home}/.ssh/config"
test "$(cat "${home}/.ssh/config")" = collision

printf 'ok: collision-complete sibling worktree transitions\n'
