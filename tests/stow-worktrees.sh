#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-stow-worktrees.XXXXXXXXXX")"
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
  printf 'GNU coreutils %s is required for worktree tests. On macOS, run: brew install coreutils\n' \
    "${command_name}" >&2
  return 1
}

if ! test_realpath="$(select_test_gnu_coreutil realpath)"; then
  exit 1
fi
if ! test_mv="$(select_test_gnu_coreutil mv)"; then
  exit 1
fi
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
  '  if [ "${COREUTILS_SHIM_FAIL_MV:-0}" = 1 ]; then exit 42; fi' \
  '  if [ -n "${COREUTILS_SHIM_FAIL_MV_AT:-}" ]; then' \
  '    move_count="$(grep -c "^gmv" "${COREUTILS_SHIM_LOG}")"' \
  '    if [ "${move_count}" = "${COREUTILS_SHIM_FAIL_MV_AT}" ]; then exit 42; fi' \
  '  fi' \
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

snapshot_fixture="${test_root}/snapshot-fixture"
mkdir -p "${snapshot_fixture}"
printf 'first content\n' >"${snapshot_fixture}/content"
ln -s first-target "${snapshot_fixture}/link"
snapshot_before="$(snapshot_home "${snapshot_fixture}")"
printf 'other content\n' >"${snapshot_fixture}/content"
snapshot_content_after="$(snapshot_home "${snapshot_fixture}")"
if [[ "${snapshot_content_after}" == "${snapshot_before}" ]]; then
  printf 'snapshot_home did not detect same-path content mutation\n' >&2
  exit 1
fi
printf 'first content\n' >"${snapshot_fixture}/content"
rm "${snapshot_fixture}/link"
ln -s second-target "${snapshot_fixture}/link"
snapshot_link_after="$(snapshot_home "${snapshot_fixture}")"
if [[ "${snapshot_link_after}" == "${snapshot_before}" ]]; then
  printf 'snapshot_home did not detect link-target mutation\n' >&2
  exit 1
fi
rm -rf "${snapshot_fixture}"
printf 'ok: HOME snapshot detects content and link-target mutations\n'

assert_check_rejected() {
  local home="$1"
  local installer="$2"
  local why="$3"
  local expected_diagnostic="$4"
  local after
  local before
  local output
  shift 4

  before="$(snapshot_home "${home}")"
  if output="$(HOME="${home}" "${installer}" --check "$@" 2>&1)"; then
    printf '%s was accepted\n' "${why}" >&2
    exit 1
  fi
  if ! grep -Fxq "${expected_diagnostic}" <<<"${output}"; then
    printf '%s did not report the expected diagnostic:\n%s\nActual output:\n%s\n' \
      "${why}" "${expected_diagnostic}" "${output}" >&2
    exit 1
  fi
  after="$(snapshot_home "${home}")"
  if [[ "${after}" != "${before}" ]]; then
    printf '%s mutated HOME during --check\n' "${why}" >&2
    diff -u <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&2 || true
    exit 1
  fi
}

assert_check_clean() {
  local home="$1"
  local installer="$2"
  local output
  shift 2

  output="$(HOME="${home}" "${installer}" --check "$@")"
  if [[ -n "${output}" ]]; then
    printf 'Clean preflight reported unexpected retarget drift:\n%s\n' \
      "${output}" >&2
    exit 1
  fi
}

new_home() {
  local name="$1"
  local home="${test_root}/homes/${name}"

  mkdir -p "${home}"
  printf '%s\n' "${home}"
}

nested_installer_dir="${test_root}/canonical/nested-installer"
mkdir -p "${nested_installer_dir}"
cp "${repo_dir}/install.sh" "${nested_installer_dir}/install.sh"
home="$(new_home nested-installer)"
if nested_output="$(
  HOME="${home}" "${nested_installer_dir}/install.sh" --check git 2>&1
)"; then
  printf 'nested installer layout was accepted\n' >&2
  exit 1
fi
grep -Fxq \
  "The dotfiles installer must be at the repository root: ${nested_installer_dir} (found ${test_root}/canonical)" \
  <<<"${nested_output}"

missing_packages_root="${test_root}/missing-packages-root"
mkdir -p "${missing_packages_root}"
cp "${repo_dir}/install.sh" "${missing_packages_root}/install.sh"
git init -q "${missing_packages_root}"
home="$(new_home missing-packages-root)"
if missing_packages_output="$(
  HOME="${home}" "${missing_packages_root}/install.sh" --check git 2>&1
)"; then
  printf 'repository root without packages was accepted\n' >&2
  exit 1
fi
grep -Fxq \
  "The repository root must contain the dotfiles packages directory: ${missing_packages_root}/packages" \
  <<<"${missing_packages_output}"

git_shim_dir="${test_root}/git-shim"
test_git="$(command -v git)"
mkdir -p "${git_shim_dir}"
printf '%s\n' \
  '#!/bin/sh' \
  'for argument do' \
  '  if [ "${argument}" = --path-format=absolute ]; then exit 129; fi' \
  'done' \
  "exec \"${test_git}\" \"\$@\"" \
  >"${git_shim_dir}/git"
chmod +x "${git_shim_dir}/git"
home="$(new_home old-git)"
if old_git_output="$(
  PATH="${git_shim_dir}:${PATH}" HOME="${home}" \
    "${test_root}/canonical/install.sh" --check git 2>&1
)"; then
  printf 'Git without absolute path-format support was accepted\n' >&2
  exit 1
fi
grep -Fxq \
  "Git 2.31 or newer is required to resolve dotfiles worktree ownership: ${test_root}/canonical" \
  <<<"${old_git_output}"
printf 'ok: repository root and minimum Git diagnostics are actionable\n'

transitions_home="$(new_home transitions)"
home="${transitions_home}"
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/canonical/packages/git/.config/git/config"
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git

# A link that resolves correctly but has absolute spelling still needs an
# explicit transition before Stow can accept it.
home="$(new_home absolute-link)"
mkdir -p "${home}/.config/git"
absolute_source="${test_root}/canonical/packages/git/.config/git/config"
ln -s "${absolute_source}" "${home}/.config/git/config"
absolute_expected_link="$(
  "${test_realpath}" -m --relative-to="${home}/.config/git" "${absolute_source}"
)"
absolute_check_output="$(
  HOME="${home}" "${test_root}/canonical/install.sh" --check git
)"
grep -Fxq \
  "Would retarget: ${home}/.config/git/config -> ${absolute_expected_link}" \
  <<<"${absolute_check_output}"
test "$(readlink "${home}/.config/git/config")" = "${absolute_source}"
HOME="${home}" "${test_root}/canonical/install.sh" git
test "$(readlink "${home}/.config/git/config")" = "${absolute_expected_link}"
assert_target "${home}/.config/git/config" "${absolute_source}"
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git

# A late collision must prevent that lexical repair from happening at all.
home="$(new_home absolute-link-late-collision)"
mkdir -p "${home}/.config/git" "${home}/.ssh"
ln -s "${absolute_source}" "${home}/.config/git/config"
printf 'collision\n' >"${home}/.ssh/config"
absolute_before="$(readlink "${home}/.config/git/config")"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" \
  "late collision after absolute owned link" \
  "Target is not a symlink: ${home}/.ssh/config" git ssh
if HOME="${home}" "${test_root}/canonical/install.sh" git ssh >/dev/null 2>&1; then
  printf 'installation with absolute link and late collision succeeded\n' >&2
  exit 1
fi
test "$(readlink "${home}/.config/git/config")" = "${absolute_before}"
printf 'ok: absolute owned links are planned without partial mutation\n'

# canonical -> worktree: check is non-mutating, install atomically retargets.
home="${transitions_home}"
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
assert_check_clean "${home}" "${test_root}/sibling/install.sh" git

# An injected atomic-move failure preserves the link and removes its temp link.
failed_target_before="$(readlink "${home}/.config/git/config")"
if COREUTILS_SHIM_FAIL_MV=1 \
  COREUTILS_SHIM_LOG="${coreutils_shim_log}" \
  PATH="${coreutils_shim}:${PATH}" \
  HOME="${home}" \
  "${test_root}/canonical/install.sh" git >/dev/null 2>&1; then
  printf 'injected GNU mv failure was accepted\n' >&2
  exit 1
fi
test "$(readlink "${home}/.config/git/config")" = "${failed_target_before}"
if find "${home}/.config/git" -name 'config.dotfiles-retarget.*' -print | grep -q .; then
  printf 'failed retarget left a temporary symlink\n' >&2
  exit 1
fi
printf 'ok: injected GNU mv failure preserves target without temp litter\n'

# A later atomic-move failure rolls back every earlier move in the same batch.
home="$(new_home multi-retarget-rollback)"
HOME="${home}" "${test_root}/canonical/install.sh" git ssh
git_before="$(readlink "${home}/.config/git/config")"
ssh_before="$(readlink "${home}/.ssh/config")"
: >"${coreutils_shim_log}"
if multi_failure_output="$(
  COREUTILS_SHIM_FAIL_MV_AT=2 \
  COREUTILS_SHIM_LOG="${coreutils_shim_log}" \
  PATH="${coreutils_shim}:${PATH}" \
  HOME="${home}" \
  "${test_root}/sibling/install.sh" git ssh 2>&1
)"; then
  printf 'injected second GNU mv failure was accepted\n' >&2
  exit 1
fi
grep -Fxq \
  "Failed to retarget link: ${home}/.ssh/config; rolling back 1 earlier link(s)." \
  <<<"${multi_failure_output}"
test "$(readlink "${home}/.config/git/config")" = "${git_before}"
test "$(readlink "${home}/.ssh/config")" = "${ssh_before}"
test "$(grep -c '^gmv' "${coreutils_shim_log}")" -eq 3
if find "${home}" -name '*.dotfiles-retarget.*' -print | grep -q .; then
  printf 'multi-link rollback left a temporary symlink\n' >&2
  exit 1
fi
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git ssh
printf 'ok: second-move failure rolls back the earlier retarget\n'

# Unchanged links are accepted, then worktree -> canonical is symmetric.
home="${transitions_home}"
HOME="${home}" "${test_root}/sibling/install.sh" --check git
HOME="${home}" "${test_root}/canonical/install.sh" --check git
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/canonical/packages/git/.config/git/config"
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git

home="$(new_home leaf-collisions)"
mkdir -p "${home}/.config/git"
printf 'foreign source\n' >"${test_root}/foreign-source"
ln -s "${test_root}/foreign-source" "${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "non-repository symlink" \
  "Linked source is not inside a Git worktree: ${test_root}/foreign-source" \
  git
rm "${home}/.config/git/config"
ln -s /tmp/missing-dotfiles-source "${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "broken leaf symlink" \
  "Unexpected link target: ${home}/.config/git/config -> /tmp/missing-dotfiles-source (expected ${test_root}/canonical/packages/git/.config/git/config)" \
  git
rm "${home}/.config/git/config"
printf 'collision\n' >"${home}/.config/git/config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "regular-file collision" \
  "Target is not a symlink: ${home}/.config/git/config" git

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
  "${home}" "${test_root}/canonical/install.sh" "suffix-only ownership" \
  "Unexpected link target: ${home}/.config/git/config -> ${test_root}/canonical/unrelated/packages/git/.config/git/config (expected ${test_root}/canonical/packages/git/.config/git/config)" \
  git

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
  "${home}" "${test_root}/canonical/install.sh" "unrelated worktree" \
  "Unexpected link target: ${home}/.config/git/config -> ${test_root}/unrelated-worktree/packages/git/.config/git/config (expected ${test_root}/canonical/packages/git/.config/git/config)" \
  git

home="$(new_home parent-collisions)"
printf 'not a directory\n' >"${home}/.config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "regular parent" \
  "Parent path is not a directory: ${home}/.config" git
rm "${home}/.config"
mkdir -p "${test_root}/foreign-config"
ln -s "${test_root}/foreign-config" "${home}/.config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "foreign directory symlink" \
  "Parent directory is a symlink: ${home}/.config -> ${test_root}/foreign-config" \
  git
rm "${home}/.config"
ln -s "${test_root}/missing-config" "${home}/.config"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "broken parent symlink" \
  "Parent directory is a broken symlink: ${home}/.config" git

home="$(new_home package-errors)"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "missing package" \
  "Unknown dotfiles package: missing" missing
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "duplicate package" \
  "Duplicate dotfiles package: git" git git
cp -a "${test_root}/canonical/packages/git" \
  "${test_root}/canonical/packages/duplicate-git"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "duplicate target" \
  "Duplicate target: ${home}/.config/git/config (${test_root}/canonical/packages/git/.config/git/config and ${test_root}/canonical/packages/duplicate-git/.config/git/config)" \
  git duplicate-git

# Cross-package leaf/parent overlap reaches the installer's dedicated branch.
mkdir -p \
  "${test_root}/canonical/packages/overlap-leaf/.config" \
  "${test_root}/canonical/packages/overlap-child/.config/overlap"
printf 'leaf\n' \
  >"${test_root}/canonical/packages/overlap-leaf/.config/overlap"
printf 'child\n' \
  >"${test_root}/canonical/packages/overlap-child/.config/overlap/child"
home="$(new_home planned-leaf-parent-overlap)"
if overlap_output="$(
  HOME="${home}" "${test_root}/canonical/install.sh" --check \
    overlap-leaf overlap-child 2>&1
)"; then
  printf 'planned leaf/parent overlap was accepted\n' >&2
  exit 1
fi
grep -Fq \
  "Target is also required as a parent directory: ${home}/.config/overlap" \
  <<<"${overlap_output}"
test -z "$(snapshot_home "${home}")"
printf 'ok: planned leaf/parent overlap reaches dedicated rejection\n'
printf 'ok: collision matrix reports exact rejection diagnostics\n'

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
