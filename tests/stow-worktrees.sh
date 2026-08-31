#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-stow-worktrees.XXXXXXXXXX")"
test_root="$(cd "${test_root}" && pwd -P)"
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
  '  if [ -n "${COREUTILS_SHIM_FAIL_MV_AT:-}${COREUTILS_SHIM_SIGNAL_MV_AT:-}${COREUTILS_SHIM_SIGNAL_AFTER_MV_AT:-}" ]; then' \
  '    move_count="$(grep -c "^gmv" "${COREUTILS_SHIM_LOG}")"' \
  '    case ",${COREUTILS_SHIM_FAIL_MV_AT:-}," in' \
  '      *,"${move_count}",*) exit 42 ;;' \
  '    esac' \
  '    if [ "${move_count}" = "${COREUTILS_SHIM_SIGNAL_MV_AT:-}" ]; then' \
  '      kill -"${COREUTILS_SHIM_SIGNAL_NAME:-TERM}" "${PPID}"' \
  '      exit 143' \
  '    fi' \
  '    if [ "${move_count}" = "${COREUTILS_SHIM_SIGNAL_AFTER_MV_AT:-}" ]; then' \
  "      \"${test_mv}\" \"\$@\"" \
  '      move_status="$?"' \
  '      if [ "${move_status}" -eq 0 ]; then' \
  '        kill -"${COREUTILS_SHIM_SIGNAL_NAME:-TERM}" "${PPID}"' \
  '      fi' \
  '      exit "${move_status}"' \
  '    fi' \
  '  fi' \
  'fi' \
  "exec \"${test_mv}\" \"\$@\"" \
  >"${coreutils_shim}/gmv"
chmod +x "${coreutils_shim}/grealpath" "${coreutils_shim}/gmv"

test_stow="$(command -v stow)"
stow_shim="${test_root}/stow-shim"
mkdir -p "${stow_shim}"
printf '%s\n' \
  '#!/bin/sh' \
  "\"${test_stow}\" \"\$@\"" \
  'stow_status="$?"' \
  'if [ "${stow_status}" -eq 0 ] && [ "${STOW_SHIM_SIGNAL_AFTER:-0}" = 1 ]; then' \
  '  kill -"${STOW_SHIM_SIGNAL_NAME:-TERM}" "${PPID}"' \
  'fi' \
  'exit "${stow_status}"' \
  >"${stow_shim}/stow"
chmod +x "${stow_shim}/stow"

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
  local after
  local before
  local output
  shift 2

  before="$(snapshot_home "${home}")"
  output="$(HOME="${home}" "${installer}" --check "$@")"
  if [[ -n "${output}" ]]; then
    printf 'Clean preflight reported unexpected retarget drift:\n%s\n' \
      "${output}" >&2
    exit 1
  fi
  after="$(snapshot_home "${home}")"
  if [[ "${after}" != "${before}" ]]; then
    printf 'Clean preflight mutated HOME.\n' >&2
    diff -u <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&2 || true
    exit 1
  fi
  if find "${home}" -name '*.dotfiles-retarget.*' -print | grep -q .; then
    printf 'Clean preflight left a temporary retarget artifact.\n' >&2
    exit 1
  fi
}

assert_check_plans() {
  local home="$1"
  local installer="$2"
  local expected="$3"
  local after
  local before
  local output
  shift 3

  before="$(snapshot_home "${home}")"
  output="$(HOME="${home}" "${installer}" --check "$@")"
  grep -Fxq "${expected}" <<<"${output}"
  after="$(snapshot_home "${home}")"
  if [[ "${after}" != "${before}" ]]; then
    printf 'Pending-retarget preflight mutated HOME.\n' >&2
    diff -u <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") >&2 || true
    exit 1
  fi
  if find "${home}" -name '*.dotfiles-retarget.*' -print | grep -q .; then
    printf 'Pending-retarget preflight left a temporary retarget artifact.\n' >&2
    exit 1
  fi
}

new_home() {
  local name="$1"
  local home="${test_root}/homes/${name}"

  mkdir -p "${home}"
  (cd "${home}" && pwd -P)
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

# User resource options cannot alter the already-certified Stow invocation.
home="$(new_home hostile-stowrc)"
printf '%s\n' '--adopt' '--ignore=config$' '--dotfiles' >"${home}/.stowrc"
source_before="$(cksum <"${test_root}/canonical/packages/git/.config/git/config")"
HOME="${home}" "${test_root}/canonical/install.sh" git
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/canonical/packages/git/.config/git/config"
test "$(cksum <"${test_root}/canonical/packages/git/.config/git/config")" = \
  "${source_before}"
test "$(printf '%s\n' '--adopt' '--ignore=config$' '--dotfiles')" = \
  "$(cat "${home}/.stowrc")"
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git
printf 'ok: HOME .stowrc cannot alter the certified Stow plan\n'

# A link that resolves correctly but has absolute spelling still needs an
# explicit transition before Stow can accept it.
home="$(new_home absolute-link)"
mkdir -p "${home}/.config/git"
absolute_source="${test_root}/canonical/packages/git/.config/git/config"
ln -s "${absolute_source}" "${home}/.config/git/config"
absolute_expected_link="$(
  "${test_realpath}" -m --relative-to="${home}/.config/git" "${absolute_source}"
)"
assert_check_plans \
  "${home}" "${test_root}/canonical/install.sh" \
  "Would retarget: ${home}/.config/git/config -> ${absolute_expected_link}" git
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
pending_relative="$(
  "${test_realpath}" -m --relative-to="${home}/.config/git" \
    "${test_root}/sibling/packages/git/.config/git/config"
)"
assert_check_plans \
  "${home}" "${test_root}/sibling/install.sh" \
  "Would retarget: ${home}/.config/git/config -> ${pending_relative}" git
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

# INT and TERM delivered during the second move both roll back the first move.
for signal_case in INT:130 TERM:143; do
  signal_name="${signal_case%%:*}"
  expected_signal_status="${signal_case##*:}"
  home="$(new_home "signaled-${signal_name}-retarget-rollback")"
  HOME="${home}" "${test_root}/canonical/install.sh" git ssh
  git_before="$(readlink "${home}/.config/git/config")"
  ssh_before="$(readlink "${home}/.ssh/config")"
  : >"${coreutils_shim_log}"
  if signal_output="$(
    COREUTILS_SHIM_SIGNAL_MV_AT=2 \
    COREUTILS_SHIM_SIGNAL_NAME="${signal_name}" \
    COREUTILS_SHIM_LOG="${coreutils_shim_log}" \
    PATH="${coreutils_shim}:${PATH}" \
    HOME="${home}" \
    "${test_root}/sibling/install.sh" git ssh 2>&1
  )"; then
    printf 'injected %s during the second GNU mv was accepted\n' \
      "${signal_name}" >&2
    exit 1
  else
    signal_status=$?
  fi
  test "${signal_status}" -eq "${expected_signal_status}"
  grep -Fxq \
    "Interrupted by ${signal_name}; rolling back 2 retarget(s), including any in-flight move." \
    <<<"${signal_output}"
  test "$(readlink "${home}/.config/git/config")" = "${git_before}"
  test "$(readlink "${home}/.ssh/config")" = "${ssh_before}"
  test "$(grep -c '^gmv' "${coreutils_shim_log}")" -eq 4
  assert_check_clean "${home}" "${test_root}/canonical/install.sh" git ssh
done
printf 'ok: INT and TERM during a retarget batch roll back committed moves\n'

# A signal sent after the second mv commits but before it returns also restores
# both links, closing the in-flight bookkeeping race.
home="$(new_home signaled-after-mv-retarget-rollback)"
HOME="${home}" "${test_root}/canonical/install.sh" git ssh
git_before="$(readlink "${home}/.config/git/config")"
ssh_before="$(readlink "${home}/.ssh/config")"
: >"${coreutils_shim_log}"
if after_mv_signal_output="$(
  COREUTILS_SHIM_SIGNAL_AFTER_MV_AT=2 \
  COREUTILS_SHIM_SIGNAL_NAME=TERM \
  COREUTILS_SHIM_LOG="${coreutils_shim_log}" \
  PATH="${coreutils_shim}:${PATH}" \
  HOME="${home}" \
  "${test_root}/sibling/install.sh" git ssh 2>&1
)"; then
  printf 'injected TERM after the second GNU mv was accepted\n' >&2
  exit 1
else
  after_mv_signal_status=$?
fi
test "${after_mv_signal_status}" -eq 143
grep -Fxq \
  'Interrupted by TERM; rolling back 2 retarget(s), including any in-flight move.' \
  <<<"${after_mv_signal_output}"
test "$(readlink "${home}/.config/git/config")" = "${git_before}"
test "$(readlink "${home}/.ssh/config")" = "${ssh_before}"
test "$(grep -c '^gmv' "${coreutils_shim_log}")" -eq 4
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git ssh
printf 'ok: after-mv signal rolls back the in-flight committed retarget\n'

# Stow itself is not transactional. An interruption names the affected
# packages and exact rerun command without claiming to undo Stow's changes.
home="$(new_home interrupted-stow)"
if interrupted_stow_output="$(
  STOW_SHIM_SIGNAL_AFTER=1 \
  STOW_SHIM_SIGNAL_NAME=TERM \
  PATH="${stow_shim}:${PATH}" \
  HOME="${home}" \
  "${test_root}/canonical/install.sh" git ssh 2>&1
)"; then
  printf 'injected TERM after Stow restow was accepted\n' >&2
  exit 1
else
  interrupted_stow_status=$?
fi
test "${interrupted_stow_status}" -eq 143
grep -Fxq \
  "Interrupted by TERM while Stow was restowing packages: git ssh. Stow changes are not transactional; rerun: ${test_root}/canonical/install.sh git ssh" \
  <<<"${interrupted_stow_output}"
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/canonical/packages/git/.config/git/config"
assert_target \
  "${home}/.ssh/config" \
  "${test_root}/canonical/packages/ssh/.ssh/config"
HOME="${home}" "${test_root}/canonical/install.sh" git ssh
assert_check_clean "${home}" "${test_root}/canonical/install.sh" git ssh
printf 'ok: interrupted Stow reports packages and a convergent rerun\n'

# If both the second move and rollback move fail, report the exact mixed state.
home="$(new_home failed-retarget-rollback)"
HOME="${home}" "${test_root}/canonical/install.sh" git ssh
git_before="$(readlink "${home}/.config/git/config")"
ssh_before="$(readlink "${home}/.ssh/config")"
: >"${coreutils_shim_log}"
if rollback_failure_output="$(
  COREUTILS_SHIM_FAIL_MV_AT=2,3 \
  COREUTILS_SHIM_LOG="${coreutils_shim_log}" \
  PATH="${coreutils_shim}:${PATH}" \
  HOME="${home}" \
  "${test_root}/sibling/install.sh" git ssh 2>&1
)"; then
  printf 'injected move and rollback failures were accepted\n' >&2
  exit 1
fi
grep -Fxq \
  "Failed to retarget link: ${home}/.ssh/config; rolling back 1 earlier link(s)." \
  <<<"${rollback_failure_output}"
grep -Fxq "Rollback failed for retargeted link: ${home}/.config/git/config" \
  <<<"${rollback_failure_output}"
grep -Fxq 'Retarget rollback was incomplete; inspect the reported links.' \
  <<<"${rollback_failure_output}"
test "$(readlink "${home}/.config/git/config")" != "${git_before}"
assert_target \
  "${home}/.config/git/config" \
  "${test_root}/sibling/packages/git/.config/git/config"
test "$(readlink "${home}/.ssh/config")" = "${ssh_before}"
test "$(grep -c '^gmv' "${coreutils_shim_log}")" -eq 3
if find "${home}" -name '*.dotfiles-retarget.*' -print | grep -q .; then
  printf 'failed rollback left a temporary retarget artifact\n' >&2
  exit 1
fi
printf 'ok: rollback failure reports and preserves the exact mixed link state\n'

# Unchanged links are accepted, then worktree -> canonical is symmetric.
home="${transitions_home}"
assert_check_clean "${home}" "${test_root}/sibling/install.sh" git
pending_relative="$(
  "${test_realpath}" -m --relative-to="${home}/.config/git" \
    "${test_root}/canonical/packages/git/.config/git/config"
)"
assert_check_plans \
  "${home}" "${test_root}/canonical/install.sh" \
  "Would retarget: ${home}/.config/git/config -> ${pending_relative}" git
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

# Package-owned symlink entries are rejected identically by check and install.
mkdir -p "${test_root}/canonical/packages/symlink-source/.config"
ln -s ../../git/.config/git/config \
  "${test_root}/canonical/packages/symlink-source/.config/source-link"
home="$(new_home symlink-source)"
symlink_diagnostic="Package source symlinks are unsupported: ${test_root}/canonical/packages/symlink-source/.config/source-link"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" "package source symlink" \
  "${symlink_diagnostic}" symlink-source
if symlink_install_output="$(
  HOME="${home}" "${test_root}/canonical/install.sh" symlink-source 2>&1
)"; then
  printf 'package source symlink was accepted by installation\n' >&2
  exit 1
fi
grep -Fxq "${symlink_diagnostic}" <<<"${symlink_install_output}"
assert_check_rejected \
  "${home}" "${test_root}/canonical/install.sh" \
  "repeated package source symlink" "${symlink_diagnostic}" symlink-source
test -z "$(snapshot_home "${home}")"
printf 'ok: package source symlink rejection is stable and non-mutating\n'

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
