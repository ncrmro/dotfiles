#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fleet-packages.XXXXXXXXXX")"
test_root="$(cd "${test_root}" && pwd -P)"
socket_test_root=""
socket_agent_pid=""
callback_test_root=""

cleanup_socket_test() {
  if [[ -n "${socket_agent_pid}" ]]; then
    kill "${socket_agent_pid}" 2>/dev/null || true
    wait "${socket_agent_pid}" 2>/dev/null || true
    socket_agent_pid=""
  fi
  if [[ -n "${socket_test_root}" ]]; then
    rm -rf "${socket_test_root}"
    socket_test_root=""
  fi
}

cleanup_fleet_test() {
  cleanup_socket_test
  if [[ -n "${callback_test_root}" ]]; then
    rm -rf "${callback_test_root}"
  fi
  rm -rf "${test_root}"
}
trap cleanup_fleet_test EXIT

assert_path_absent() {
  local why="$1"
  local path="$2"

  if [[ -e "${path}" || -L "${path}" ]]; then
    printf 'FAIL: %s: %s\n' "${why}" "${path}" >&2
    return 1
  fi
  return 0
}

assert_find_empty() {
  local why="$1"
  local matches
  shift

  if ! matches="$(find "$@" -print)"; then
    printf 'FAIL: find failed while checking %s\n' "${why}" >&2
    return 1
  fi
  if [[ -n "${matches}" ]]; then
    printf 'FAIL: %s\n%s\n' "${why}" "${matches}" >&2
    return 1
  fi
  return 0
}

refute() {
  local why="$1"
  local status
  shift

  if grep "$@" >/dev/null; then
    printf 'FAIL: %s\n' "${why}" >&2
    grep -n "$@" >&2 || true
    return 1
  else
    status=$?
  fi
  if [[ "${status}" -ne 1 ]]; then
    printf 'FAIL: grep failed while checking %s\n' "${why}" >&2
    return 1
  fi
  return 0
}

snapshot_tree() {
  local root="$1"
  local path

  (
    cd "${root}"
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
  printf 'GNU coreutils %s is required for fleet tests. On macOS, run: brew install coreutils\n' \
    "${command_name}" >&2
  return 1
}

if ! test_realpath="$(select_test_gnu_coreutil realpath)"; then
  exit 1
fi

guard_fixture="${test_root}/negative-guard-fixture"
mkdir -p "${guard_fixture}"
printf 'forbidden marker\n' >"${guard_fixture}/present"
if assert_path_absent fixture "${guard_fixture}/present" >/dev/null 2>&1; then
  printf 'Path absence guard accepted an existing fixture.\n' >&2
  exit 1
fi
if assert_find_empty fixture "${guard_fixture}" -type f >/dev/null 2>&1; then
  printf 'Find guard accepted a matching fixture.\n' >&2
  exit 1
fi
if refute fixture -F 'forbidden marker' "${guard_fixture}/present" >/dev/null 2>&1; then
  printf 'Content guard accepted a matching fixture.\n' >&2
  exit 1
fi
rm -rf "${guard_fixture}"
printf 'ok: negative assertion guards reject live fixtures\n'
stow_root="${test_root}/dotfiles"
mkdir -p "${stow_root}"
cp "${repo_dir}/install.sh" "${stow_root}/install.sh"
cp -a "${repo_dir}/packages" "${stow_root}/packages"
git init -q "${stow_root}"
terminal=(bin bat btop git helix lazygit ssh themes zellij zsh)
desktop=(clipse ghostty hyprland-common omarchy satty walker wofi)

compositions=(
  # Mirrors dotfiles.packages per host in ks-config. Mercury is infrastructure,
  # not a development host, and keeps its own three-package list; maia does not
  # import the dotfiles module at all. Neither gets `bin`.
  "maia:git ssh zsh"
  "mercury:git ssh zsh"
  "ocean:${terminal[*]}"
  "ncrmro-workstation:${terminal[*]} ${desktop[*]} hyprland-workstation"
  "ncrmro-laptop:${terminal[*]} ${desktop[*]} hyprland-laptop"
  "ks-test-delltop:${terminal[*]} ${desktop[*]} hyprland-delltop"
)

seed_obsolete_stow_link() {
  local source="$1"
  local target="$2"

  ln -s "$("${test_realpath}" -m --relative-to="$(dirname "${target}")" "${source}")" \
    "${target}"
}

for composition in "${compositions[@]}"; do
  host="${composition%%:*}"
  read -r -a packages <<<"${composition#*:}"
  test_home="${test_root}/home-${host}"
  mkdir -p "${test_home}"

  if [[ " ${packages[*]} " == *" hyprland-common "* ]]; then
    mkdir -p "${test_home}/.config/hypr"
    seed_obsolete_stow_link \
      "${stow_root}/packages/hyprland-common/.config/hypr/hyprland.conf" \
      "${test_home}/.config/hypr/hyprland.conf"
    seed_obsolete_stow_link \
      "${stow_root}/packages/hyprland-common/.config/hypr/ncrmro.conf" \
      "${test_home}/.config/hypr/ncrmro.conf"
  fi

  for package in "${packages[@]}"; do
    if [[ "${package}" == hyprland-* && "${package}" != "hyprland-common" ]]; then
      seed_obsolete_stow_link \
        "${stow_root}/packages/${package}/.config/hypr/host.conf" \
        "${test_home}/.config/hypr/host.conf"
    fi
  done

  HOME="${test_home}" "${stow_root}/install.sh" "${packages[@]}"
  host_check_before="$(snapshot_tree "${test_home}")"
  host_check_output="$(
    HOME="${test_home}" "${stow_root}/install.sh" --check "${packages[@]}"
  )"
  host_check_after="$(snapshot_tree "${test_home}")"
  if [[ -n "${host_check_output}" ]]; then
    printf 'Host %s retained retarget drift after installation:\n%s\n' \
      "${host}" "${host_check_output}" >&2
    exit 1
  fi
  if [[ "${host_check_after}" != "${host_check_before}" ]]; then
    printf 'Host %s preflight mutated its installed HOME.\n' "${host}" >&2
    exit 1
  fi
  assert_find_empty 'host preflight left a temporary retarget artifact' \
    "${test_home}" -name '*.dotfiles-retarget.*'

  if [[ " ${packages[*]} " == *" omarchy "* ]]; then
    shell_config="${test_home}/.config/omarchy/shell.json"
    test -L "${shell_config}"
    shell_target="$(readlink "${shell_config}")"
    shell_original="$(cat "${shell_config}")"
    printf '\n' >>"${shell_config}"
    test -L "${shell_config}"
    test "$(readlink "${shell_config}")" = "${shell_target}"
    printf '%s\n' "${shell_original}" >"${shell_config}"
    HOME="${test_home}" "${stow_root}/install.sh" omarchy
    test -L "${shell_config}"
    test "$(readlink "${shell_config}")" = "${shell_target}"
  fi

  if [[ " ${packages[*]} " == *" hyprland-common "* ]]; then
    test -L "${test_home}/.config/hypr/hyprland.lua"
    test -L "${test_home}/.config/hypr/user.lua"
    test -L "${test_home}/.config/uwsm/env"
    test -L "${test_home}/.config/uwsm/env-hyprland"
    assert_path_absent 'obsolete Hyprland config remains' \
      "${test_home}/.config/hypr/hyprland.conf"
    assert_path_absent 'obsolete ncrmro Hyprland config remains' \
      "${test_home}/.config/hypr/ncrmro.conf"
    assert_path_absent 'obsolete host Hyprland config remains' \
      "${test_home}/.config/hypr/host.conf"
    test -L "${test_home}/.config/hypr/host.lua"
  fi

  rm -rf "${test_home}"
  printf 'ok: %s\n' "${host}"
done

themes_dir="${repo_dir}/packages/themes/.config/keystone/theme-catalogs/user"
theme_dirs=()
while IFS= read -r theme_dir; do
  theme_dirs+=("${theme_dir}")
done < <(find "${themes_dir}" -mindepth 1 -maxdepth 1 -type d -print | sort)
test "${#theme_dirs[@]}" -eq 15
assert_find_empty 'user themes contain retired zellij.conf files' \
  "${themes_dir}" -name zellij.conf -type f
assert_path_absent 'retired package-local royal-green Zellij theme remains' \
  "${repo_dir}/packages/zellij/.config/zellij/themes/royal-green.kdl"

test "$(find "${themes_dir}" -name helix.conf -type f | wc -l)" -eq 15
test "$(find "${themes_dir}" -name hyprland.lua -type f | wc -l)" -eq 2
test "$(find "${themes_dir}" -name zellij.kdl -type f | wc -l)" -eq 1
theme_file="${themes_dir}/royal-green/zellij.kdl"
grep -Eq '^[[:space:]]*current[[:space:]]*\{' "${theme_file}"

printf 'ok: Zellij theme contract\n'

hypridle_conf="${repo_dir}/packages/hyprland-common/.config/hypr/hypridle.conf"
hyprland_lua="${repo_dir}/packages/hyprland-common/.config/hypr/hyprland.lua"
ghostty_config="${repo_dir}/packages/ghostty/.config/ghostty/config"
uwsm_env="${repo_dir}/packages/hyprland-common/.config/uwsm/env"
uwsm_hyprland_env="${repo_dir}/packages/hyprland-common/.config/uwsm/env-hyprland"
zsh_env="${repo_dir}/packages/zsh/.zshenv"
zsh_rc="${repo_dir}/packages/zsh/.zshrc"
ssh_config="${repo_dir}/packages/ssh/.ssh/config"
startup_configs=()
while IFS= read -r startup_config; do
  startup_configs+=("${startup_config}")
done < <(
  find "${repo_dir}/packages" -type f \
    \( -path '*/.config/hypr/hyprland.lua' \
    -o -path '*/.config/hypr/user.lua' \
    -o -path '*/.config/hypr/host.lua' \
    -o -path '*/.config/hypr/monitors.lua' \
    -o -path '*/.config/keystone/theme-catalogs/user/*/hyprland.lua' \) \
    -print | sort
)
if [[ "${#startup_configs[@]}" -ne 10 ]]; then
  printf 'Expected 10 active Hyprland Lua configs. Found %d.\n' \
    "${#startup_configs[@]}" >&2
  exit 1
fi
waybar_guard_configs=()
while IFS= read -r waybar_guard_config; do
  waybar_guard_configs+=("${waybar_guard_config}")
done < <(
  find "${repo_dir}/packages" -type f \
    \( -path '*/.config/hypr/*.lua' \
    -o -path '*/.config/hypr/*.conf' \
    -o -path '*/.config/uwsm/env' \
    -o -path '*/.config/uwsm/env-hyprland' \
    -o -path '*/.config/omarchy/shell.json' \
    -o -path '*/.config/keystone/theme-catalogs/user/*/hyprland.lua' \) \
    -print | sort
)
if [[ "${#waybar_guard_configs[@]}" -ne 18 ]]; then
  printf 'Expected 18 active desktop configuration files. Found %d.\n' \
    "${#waybar_guard_configs[@]}" >&2
  exit 1
fi

grep -Fxq 'shell-integration-features = ssh-env,ssh-terminfo' "${ghostty_config}"
grep -Fq 'KEYSTONE_PROFILE_ROOT="$HOME/.nix-profile"' "${zsh_env}"
grep -Fq 'HISTFILE="$HOME/.zsh_history"' "${zsh_rc}"
grep -Fq 'home-manager switch --flake "$HOME/repos/ncrmro/ks-config#nicholas@unsup-macbook"' "${zsh_rc}"
grep -Fq $'\tUserKnownHostsFile ~/.ssh/known_hosts' "${ssh_config}"
if grep -Fq '/home/ncrmro' "${zsh_env}" "${zsh_rc}"; then
  printf 'FAIL: zsh config contains a Linux-only home path\n' >&2
  exit 1
fi
grep -Fxq '  before_sleep_cmd=keystone-lock' "${hypridle_conf}"
grep -Fxq '  inhibit_sleep=3' "${hypridle_conf}"
grep -Fxq '  lock_cmd=keystone-lock' "${hypridle_conf}"
grep -Fxq '  on-timeout=keystone-lock' "${hypridle_conf}"
grep -Fxq '  timeout=300' "${hypridle_conf}"
# Hyprland 0.56 treats `hyprctl dispatch` as Lua shorthand. Pin the typed
# wake and blank expressions, and reject the legacy bare dispatcher form.
grep -Fxq '  after_sleep_cmd=keystone-dpms-wake || (hyprctl dispatch '"'"'hl.dsp.dpms({ action = "on" })'"'"' && brightnessctl -r)' "${hypridle_conf}"
grep -Fxq '  on-resume=keystone-dpms-wake || (hyprctl dispatch '"'"'hl.dsp.dpms({ action = "on" })'"'"' && brightnessctl -r)' "${hypridle_conf}"
grep -Fxq '  on-timeout=hyprctl dispatch '"'"'hl.dsp.dpms({ action = "off" })'"'"'' "${hypridle_conf}"
refute 'hypridle must not use the legacy bare DPMS dispatcher form' \
  -E '^[^#]*hyprctl dispatch[[:space:]]+dpms([[:space:]]|$)' "${hypridle_conf}"
grep -Fq 'hl.bind("switch:on:Lid Switch", exec("keystone-suspend --lid")' "${hyprland_lua}"
grep -Fq 'hl.bind("switch:off:Lid Switch", function()' "${hyprland_lua}"
grep -Fq 'hl.timer(function()' "${hyprland_lua}"
grep -Fq 'hl.dispatch(hl.dsp.dpms({ action = "on" }))' "${hyprland_lua}"
lid_dpms_fixture="${test_root}/unsafe-lid-dpms.lua"
printf 'hl.bind("switch:on:n", hl.dsp.dpms({ action = "on" }))\n' \
  >"${lid_dpms_fixture}"
if refute fixture -E 'hl\.bind\(.*hl\.dsp\.dpms' "${lid_dpms_fixture}" \
  >/dev/null 2>&1; then
  printf 'Lid DPMS guard accepted a same-line violation containing n.\n' >&2
  exit 1
fi
rm "${lid_dpms_fixture}"
refute 'lid-open DPMS must dispatch from a timer, not straight from the bind' \
  -E 'hl\.bind\(.*hl\.dsp\.dpms' "${hyprland_lua}"
printf 'ok: lid DPMS line guard rejects a live n-containing violation\n'
# Input is the recovery path that does not depend on any hypridle hook firing.
grep -Fq 'key_press_enables_dpms = true' "${hyprland_lua}"
grep -Fq 'mouse_move_enables_dpms = true' "${hyprland_lua}"
refute 'lock state must come from the compositor, not pidof' \
  -F 'pidof hyprlock' "${hypridle_conf}" "${hyprland_lua}"
refute 'runtime lock hooks must not tear down the session' \
  -F -- '--fail-closed' "${hypridle_conf}"
printf 'ok: lock hooks\n'

grep -Fq 'local theme, load_error = loadfile(theme_path)' "${hyprland_lua}"
grep -Fq 'local ok, runtime_error = pcall(theme)' "${hyprland_lua}"
grep -Fq 'local ok, err = pcall(require, name)' "${hyprland_lua}"
grep -Fq 'load_module("user")' "${hyprland_lua}"
grep -Fq 'load_module("monitors")' "${hyprland_lua}"
grep -Fq 'load_module("host")' "${hyprland_lua}"
grep -Fq 'local app = "uwsm app -- "' "${hyprland_lua}"
grep -Fq 'hl.bind(mod .. " + P", hl.dsp.window.pseudo())' "${hyprland_lua}"
grep -Fq 'hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))' "${hyprland_lua}"
grep -Fq 'hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))' "${hyprland_lua}"
for graphical_command in \
  'ghostty' \
  'chromium --new-window --ozone-platform=wayland' \
  'nautilus --new-window' \
  'keystone-menu system' \
  'keystone-menu-keybindings' \
  'ghostty --class clipse -e clipse' \
  'walker -m symbols' \
  'keystone-screenshot' \
  'keystone-screenshot smart clipboard' \
  'hyprpicker -a' \
  'keystone-window-switch'; do
  grep -Fq "app .. \"${graphical_command}\"" "${hyprland_lua}"
done
refute 'active Hyprland configuration must not invoke Waybar' \
  -Ei '(^|[^[:alnum:]_])waybar([^[:alnum:]_]|$)' "${waybar_guard_configs[@]}"

refute 'Hyprland config must not import or tear down the session environment' \
  -E 'systemctl --user import-environment|dbus-update-activation-environment|hyprctl dispatch exit' \
  "${hyprland_lua}"
refute 'generic UWSM environment must not set renderer or cursor overrides' \
  -E 'WLR_RENDERER_ALLOW_SOFTWARE|HYPRCURSOR_' "${uwsm_env}"
refute 'generic UWSM environment must not force GTK_THEME' \
  -E '^[[:space:]]*export[[:space:]]+GTK_THEME=' "${uwsm_env}"
grep -Fxq 'export XDG_DATA_DIRS="${XDG_DATA_DIRS:-$HOME/.local/share:/usr/local/share:/usr/share}:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share"' "${uwsm_env}"
grep -Fxq 'export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gcr/ssh"' "${uwsm_env}"
grep -Fxq 'export HYPRCURSOR_SIZE=24' "${uwsm_hyprland_env}"
grep -Fxq 'export HYPRCURSOR_THEME=Adwaita' "${uwsm_hyprland_env}"
refute 'Hyprland UWSM environment must not allow the software renderer' \
  -F 'WLR_RENDERER_ALLOW_SOFTWARE' "${uwsm_hyprland_env}"

zsh -n "${zsh_env}"
socket_test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-ssh-socket.XXXXXXXXXX")"
mkdir -p "${socket_test_root}/gcr"

SSH_AUTH_SOCK="${socket_test_root}/inherited" \
  XDG_RUNTIME_DIR="${socket_test_root}" \
  zsh -f -c 'source "$1"; [[ "$SSH_AUTH_SOCK" == "$2/inherited" ]]' \
  _ "${zsh_env}" "${socket_test_root}"

env -u SSH_AUTH_SOCK XDG_RUNTIME_DIR="${socket_test_root}" \
  zsh -f -c 'source "$1"; [[ "$SSH_AUTH_SOCK" == "$2/ssh-agent" ]]' \
  _ "${zsh_env}" "${socket_test_root}"

ssh-agent -D -a "${socket_test_root}/gcr/ssh" >/dev/null 2>&1 &
socket_agent_pid="$!"
for _ in {1..50}; do
  [[ -S "${socket_test_root}/gcr/ssh" ]] && break
  if ! kill -0 "${socket_agent_pid}" 2>/dev/null; then
    printf 'The temporary SSH agent stopped before it created its socket.\n' >&2
    exit 1
  fi
  sleep 0.1
done
if [[ ! -S "${socket_test_root}/gcr/ssh" ]]; then
  printf 'The temporary SSH agent did not create its socket.\n' >&2
  exit 1
fi

env -u SSH_AUTH_SOCK XDG_RUNTIME_DIR="${socket_test_root}" \
  zsh -f -c 'source "$1"; [[ "$SSH_AUTH_SOCK" == "$2/gcr/ssh" ]]' \
  _ "${zsh_env}" "${socket_test_root}"

cleanup_socket_test
printf 'ok: SSH agent socket selection\n'

test "$(find "${repo_dir}/packages/themes/.config/keystone/theme-catalogs/user" -name hyprland.lua -type f | wc -l)" -eq 2
assert_find_empty 'user themes contain retired hyprland.conf files' \
  "${repo_dir}/packages/themes/.config/keystone/theme-catalogs/user" \
  -name hyprland.conf -type f
assert_find_empty 'packages contain retired Hyprland configuration files' \
  "${repo_dir}/packages" \
  \( -path '*/hyprland.conf' -o -path '*/ncrmro.conf' -o -path '*/host.conf' \) \
  -type f

for ecosystem_config in hypridle.conf hyprlock.conf hyprpaper.conf hyprsunset.conf xdph.conf; do
  test -f "${repo_dir}/packages/hyprland-common/.config/hypr/${ecosystem_config}"
done
printf 'ok: Hyprland Lua contract\n'

start_callbacks_are_safe() {
  local callback_status
  local file
  local unsafe_aliases
  for file in "$@"; do
    # The focused analyzers below intentionally handle quoted strings and
    # line comments only. Reject Lua long-bracket strings/comments explicitly
    # so their body tokens can never corrupt block or parenthesis depth.
    if ! awk '
      {
        quote = ""
        escaped = 0
        for (i = 1; i <= length($0); i++) {
          character = substr($0, i, 1)
          following = substr($0, i + 1, 1)
          if (quote != "") {
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
          } else if (character == "\"" || character == "\047") {
            quote = character
          } else if (character == "-" && following == "-") {
            if (substr($0, i) ~ /^--\[=*\[/) {
              printf "Unsupported Lua long-bracket syntax while checking startup callbacks: %s:%d\n", \
                FILENAME, FNR > "/dev/stderr"
              exit 1
            }
            break
          } else if (substr($0, i) ~ /^\[=*\[/) {
            printf "Unsupported Lua long-bracket syntax while checking startup callbacks: %s:%d\n", \
              FILENAME, FNR > "/dev/stderr"
            exit 1
          }
        }
      }
    ' "${file}"; then
      return 1
    fi
    if ! unsafe_aliases="$(awk '
      function count_word(text, word, count, remaining, pattern) {
        count = 0
        remaining = text
        pattern = "(^|[^[:alnum:]_])" word "([^[:alnum:]_]|$)"
        while (match(remaining, pattern)) {
          count++
          remaining = substr(remaining, RSTART + RLENGTH)
        }
        return count
      }

      function structural_code(text, output, quote, escaped, i, character, following) {
        output = ""
        quote = ""
        escaped = 0
        for (i = 1; i <= length(text); i++) {
          character = substr(text, i, 1)
          following = substr(text, i + 1, 1)
          if (quote != "") {
            output = output " "
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
          } else if (character == "\"" || character == "\047") {
            quote = character
            output = output " "
          } else if (character == "-" && following == "-") {
            break
          } else {
            output = output character
          }
        }
        return output
      }

      {
        code = $0
        structural = structural_code(code)
        trimmed = code
        sub(/^[[:space:]]+/, "", trimmed)

        if (function_alias == "") {
          if (trimmed ~ /^(local[[:space:]]+)?function[[:space:]]+[[:alpha:]_][[:alnum:]_]*[[:space:]]*[(]/) {
            declaration = trimmed
            sub(/^local[[:space:]]+/, "", declaration)
            sub(/^function[[:space:]]+/, "", declaration)
            sub(/[[:space:]]*[(].*/, "", declaration)
            function_alias = declaration
            function_unsafe = 0
            function_depth = 0
          } else if (trimmed ~ /^(local[[:space:]]+)?[[:alpha:]_][[:alnum:]_]*[[:space:]]*=[[:space:]]*function([[:space:]]|[(])/) {
            declaration = trimmed
            sub(/^local[[:space:]]+/, "", declaration)
            sub(/[[:space:]]*=.*/, "", declaration)
            function_alias = declaration
            function_unsafe = 0
            function_depth = 0
          }
        }

        if (function_alias != "") {
          if (structural ~ /hl[.](dsp[.])?exec_(cmd|raw)[[:space:]]*[(]/) {
            function_unsafe = 1
          }
          # Lua blocks close only on standalone end/until tokens. Counting
          # function/if/do/repeat keeps nested blocks from ending the wrapper;
          # token boundaries prevent identifiers such as weekend from doing so.
          function_depth += count_word(structural, "function")
          function_depth += count_word(structural, "if")
          function_depth += count_word(structural, "do")
          function_depth += count_word(structural, "repeat")
          function_depth -= count_word(structural, "end")
          function_depth -= count_word(structural, "until")
          if (function_depth <= 0) {
            if (function_unsafe) {
              print function_alias
            }
            function_alias = ""
            function_unsafe = 0
            function_depth = 0
          }
        }

        assignment = trimmed
        if (assignment ~ /^(local[[:space:]]+)?[[:alpha:]_][[:alnum:]_]*[[:space:]]*=[[:space:]]*hl[.](dsp[.])?exec_(cmd|raw)([^[:alnum:]_]|$)/) {
          sub(/^local[[:space:]]+/, "", assignment)
          sub(/[[:space:]]*=.*/, "", assignment)
          print assignment
        }
      }

      END {
        if (function_alias != "") {
          printf "Unclosed file-scope function while checking startup callbacks: %s\n", \
            function_alias > "/dev/stderr"
          exit 2
        }
      }
    ' "${file}")"; then
      return 1
    fi
    callback_status=0
    awk -v unsafe_aliases="${unsafe_aliases}" '
      # Contract: hyprland.start callbacks may only perform compositor-local
      # typed dispatch and configuration work. They must not launch a shell,
      # process, GUI, or long-lived service, directly or through a local
      # alias of a Hyprland command dispatcher.
      function normalized_context(text, normalized) {
        normalized = text
        gsub(/[[:space:]]+/, " ", normalized)
        sub(/^ /, "", normalized)
        sub(/ $/, "", normalized)
        return normalized
      }

      function has_identifier(text, identifier, pattern) {
        pattern = "(^|[^[:alnum:]_])" identifier "([^[:alnum:]_]|$)"
        return text ~ pattern
      }

      function source_span(first, last) {
        if (first == last) {
          return FILENAME ":" first
        }
        return FILENAME ":" first "-" last
      }

      function identifier_context(text, output, quote, escaped, i, character) {
        output = ""
        quote = ""
        escaped = 0
        for (i = 1; i <= length(text); i++) {
          character = substr(text, i, 1)
          if (quote != "") {
            output = output " "
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
          } else if (character == "\"" || character == "\047") {
            quote = character
            output = output " "
          } else {
            output = output character
          }
        }
        return normalized_context(output)
      }

      function unsafe(callback, normalized, identifiers, remaining, assignment, alias, pattern, alias_i) {
        normalized = normalized_context(callback)
        identifiers = identifier_context(callback)
        captured_callback = normalized
        if (has_identifier(identifiers, "hl[.]dsp[.]exec_cmd")) {
          unsafe_reason = "forbidden builtin identifier: hl.dsp.exec_cmd"
          return 1
        }
        if (has_identifier(identifiers, "hl[.]dsp[.]exec_raw")) {
          unsafe_reason = "forbidden builtin identifier: hl.dsp.exec_raw"
          return 1
        }
        if (has_identifier(identifiers, "hl[.]exec_cmd")) {
          unsafe_reason = "forbidden builtin identifier: hl.exec_cmd"
          return 1
        }
        if (has_identifier(identifiers, "hl[.]exec_raw")) {
          unsafe_reason = "forbidden builtin identifier: hl.exec_raw"
          return 1
        }
        if (has_identifier(identifiers, "os[.]execute")) {
          unsafe_reason = "forbidden builtin identifier: os.execute"
          return 1
        }
        if (has_identifier(identifiers, "io[.]popen")) {
          unsafe_reason = "forbidden builtin identifier: io.popen"
          return 1
        }
        if (normalized ~ /(^|[^[:alnum:]_])uwsm[[:space:]]+app([^[:alnum:]_]|$)/) {
          unsafe_reason = "forbidden command context: uwsm app"
          return 1
        }

        for (alias_i = 1; alias_i <= alias_count; alias_i++) {
          alias = file_aliases[alias_i]
          if (alias != "" \
            && identifiers ~ ("(^|[^[:alnum:]_])" alias "([^[:alnum:]_]|$)")) {
            unsafe_reason = "forbidden file-scope dispatcher alias: " alias
            return 1
          }
        }

        remaining = identifiers
        pattern = "(^|[^[:alnum:]_])((local[[:space:]]+)?([[:alpha:]_][[:alnum:]_]*))[[:space:]]*=[[:space:]]*hl[.](dsp[.])?exec_(cmd|raw)([^[:alnum:]_]|$)"
        while (match(remaining, pattern)) {
          assignment = substr(remaining, RSTART, RLENGTH)
          sub(/^[^[:alpha:]_]*/, "", assignment)
          sub(/^local[[:space:]]+/, "", assignment)
          sub(/[[:space:]]*=.*/, "", assignment)
          alias = assignment
          if (identifiers ~ ("(^|[^[:alnum:]_])" alias "[[:space:]]*[(]")) {
            unsafe_reason = "forbidden callback-local dispatcher alias: " alias
            return 1
          }
          remaining = substr(remaining, RSTART + RLENGTH)
        }
        return 0
      }

      function code_before_comment(text, output, quote, escaped, i, character, following) {
        output = ""
        quote = ""
        escaped = 0
        for (i = 1; i <= length(text); i++) {
          character = substr(text, i, 1)
          following = substr(text, i + 1, 1)
          if (quote != "") {
            output = output character
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
          } else if (character == "\"" || character == "\047") {
            quote = character
            output = output character
          } else if (character == "-" && following == "-") {
            break
          } else {
            output = output character
          }
        }
        return output
      }

      function start_hook_position(text, quote, escaped, i, character, tail) {
        quote = ""
        escaped = 0
        for (i = 1; i <= length(text); i++) {
          character = substr(text, i, 1)
          if (quote != "") {
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
          } else if (character == "\"" || character == "\047") {
            quote = character
          } else {
            tail = substr(text, i)
            if (tail ~ /^hl[.]on[[:space:]]*\([[:space:]]*["\047]hyprland[.]start["\047]/) {
              return i
            }
          }
        }
        return 0
      }

      BEGIN {
        active = 0
        depth = 0
        alias_count = split(unsafe_aliases, file_aliases, "\n")
      }

      {
        code = code_before_comment($0)
        trimmed = code
        sub(/^[[:space:]]+/, "", trimmed)

        if (!active) {
          hook_at = start_hook_position(code)
          if (hook_at == 0) {
            next
          }
          active = 1
          depth = 0
          callback = ""
          callback_start = FNR
          code = substr(code, hook_at)
        }

        quote = ""
        escaped = 0
        for (i = 1; i <= length(code); i++) {
          character = substr(code, i, 1)
          following = substr(code, i + 1, 1)

          callback = callback character
          if (quote != "") {
            if (escaped) {
              escaped = 0
            } else if (character == "\\") {
              escaped = 1
            } else if (character == quote) {
              quote = ""
            }
            continue
          }

          if (character == "\"" || character == "\047") {
            quote = character
          } else if (character == "(") {
            depth++
          } else if (character == ")") {
            depth--
            if (depth == 0) {
              if (unsafe(callback)) {
                active = 0
                printf "Unsafe hyprland.start callback at %s: %s\nCaptured callback: %s\n", \
                  source_span(callback_start, FNR), unsafe_reason, captured_callback \
                  > "/dev/stderr"
                exit 1
              }
              active = 0
              callback = ""
              break
            }
          }
        }
        callback = callback "\n"
      }

      END {
        if (active) {
          printf "Unclosed hyprland.start callback at %s\nCaptured callback: %s\n", \
            source_span(callback_start, FNR), normalized_context(callback) \
            > "/dev/stderr"
          exit 2
        }
      }
    ' "${file}" || callback_status="$?"
    if [[ "${callback_status}" -ne 0 ]]; then
      return "${callback_status}"
    fi
  done
}

start_callbacks_are_safe "${startup_configs[@]}"

callback_test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-start-callback.XXXXXXXXXX")"
unsafe_fixture="${callback_test_root}/unsafe.lua"

assert_callback_rejected() {
  local expected_status="$1"
  local expected_output="$2"
  local why="$3"
  local actual_output
  local actual_status

  if actual_output="$(start_callbacks_are_safe "${unsafe_fixture}" 2>&1)"; then
    printf 'Startup callback guard accepted %s.\n' "${why}" >&2
    exit 1
  else
    actual_status="$?"
  fi
  if [[ "${actual_status}" -ne "${expected_status}" ]]; then
    printf '%s returned status %s instead of %s.\n' \
      "${why}" "${actual_status}" "${expected_status}" >&2
    exit 1
  fi
  if [[ "${actual_output}" != "${expected_output}" ]]; then
    printf '%s lacked its exact diagnostic:\nExpected:\n%s\nActual:\n%s\n' \
      "${why}" "${expected_output}" "${actual_output}" >&2
    exit 1
  fi
}

for unsafe_builtin in \
  hl.exec_cmd \
  hl.dsp.exec_cmd \
  hl.exec_raw \
  hl.dsp.exec_raw \
  os.execute \
  io.popen; do
  printf 'hl.on("hyprland.start", %s)\n' "${unsafe_builtin}" >"${unsafe_fixture}"
  expected_callback="hl.on(\"hyprland.start\", ${unsafe_builtin})"
  expected_diagnostic="$(printf \
    'Unsafe hyprland.start callback at %s:1: forbidden builtin identifier: %s\nCaptured callback: %s' \
    "${unsafe_fixture}" "${unsafe_builtin}" "${expected_callback}")"
  assert_callback_rejected \
    1 "${expected_diagnostic}" "bare builtin callback reference ${unsafe_builtin}"
done

for unsafe_dispatcher in hl.exec_cmd hl.dsp.exec_cmd hl.exec_raw hl.dsp.exec_raw; do
  cat >"${unsafe_fixture}" <<LUA
hl.on("hyprland.start", function()
  local launch = ${unsafe_dispatcher}
  launch("unsafe-example")
end)
LUA
  if start_callbacks_are_safe "${unsafe_fixture}"; then
    printf 'Startup callback guard accepted aliased dispatcher: %s\n' \
      "${unsafe_dispatcher}" >&2
    exit 1
  fi
done
cat >"${unsafe_fixture}" <<'LUA'
local exec = hl.exec_cmd
hl.on("hyprland.start", function()
  exec("unsafe-example")
end)
LUA
if start_callbacks_are_safe "${unsafe_fixture}"; then
  printf 'Startup callback guard accepted a file-scope dispatcher assignment.\n' >&2
  exit 1
fi
cat >"${unsafe_fixture}" <<'LUA'
local function exec(command)
  return hl.exec_cmd(command)
end
hl.on("hyprland.start", function()
  exec("unsafe-example")
end)
LUA
if start_callbacks_are_safe "${unsafe_fixture}"; then
  printf 'Startup callback guard accepted the repo-style dispatcher function.\n' >&2
  exit 1
fi
cat >"${unsafe_fixture}" <<'LUA'
local function exec(command)
  local marker = "uwsm app -- function if do repeat end until"; if command then
    local weekend = "end until"
  end
  return hl.exec_cmd(command)
end
hl.on("hyprland.start", function()
  exec("unsafe-example")
end)
LUA
if start_callbacks_are_safe "${unsafe_fixture}"; then
  printf 'Startup callback guard accepted a nested dispatcher wrapper.\n' >&2
  exit 1
fi
cat >"${unsafe_fixture}" <<'LUA'
local function exec(command)
  return hl.exec_cmd(command)
end
hl.on("hyprland.start", exec)
LUA
if start_callbacks_are_safe "${unsafe_fixture}"; then
  printf 'Startup callback guard accepted a dispatcher function reference.\n' >&2
  exit 1
fi
cat >"${unsafe_fixture}" <<'LUA'
local function exec(command)
  --[[
  end
  ]]
  return hl.exec_cmd(command)
end
hl.on("hyprland.start", exec)
LUA
if long_bracket_output="$(start_callbacks_are_safe "${unsafe_fixture}" 2>&1)"; then
  printf 'Startup callback guard accepted a long-comment dispatcher bypass.\n' >&2
  exit 1
fi
expected_long_bracket="Unsupported Lua long-bracket syntax while checking startup callbacks: ${unsafe_fixture}:2"
if [[ "${long_bracket_output}" != "${expected_long_bracket}" ]]; then
  printf 'Long-comment dispatcher bypass lacked its exact diagnostic:\n%s\n' \
    "${long_bracket_output}" >&2
  exit 1
fi
cat >"${unsafe_fixture}" <<'LUA'
local documentation = [=[
No startup callback is defined here.
]=]
LUA
if long_bracket_output="$(start_callbacks_are_safe "${unsafe_fixture}" 2>&1)"; then
  printf 'Startup callback guard silently accepted an unsupported long string.\n' >&2
  exit 1
fi
expected_long_bracket="Unsupported Lua long-bracket syntax while checking startup callbacks: ${unsafe_fixture}:1"
if [[ "${long_bracket_output}" != "${expected_long_bracket}" ]]; then
  printf 'Unsupported long string lacked its exact diagnostic:\n%s\n' \
    "${long_bracket_output}" >&2
  exit 1
fi
cat >"${unsafe_fixture}" <<'LUA'
local function exec(command)
  return hl.exec_cmd(command)
LUA
if unclosed_output="$(start_callbacks_are_safe "${unsafe_fixture}" 2>&1)"; then
  printf 'Startup callback guard accepted an unclosed dispatcher wrapper.\n' >&2
  exit 1
fi
case "${unclosed_output}" in
  *'Unclosed file-scope function while checking startup callbacks: exec'*) ;;
  *)
    printf 'Unclosed dispatcher wrapper lacked its diagnostic:\n%s\n' \
      "${unclosed_output}" >&2
    exit 1
    ;;
esac
for unsafe_call in \
  'hl.exec_cmd("unsafe-example")' \
  'hl.dsp.exec_cmd("unsafe-example")' \
  'hl.exec_raw("unsafe-example")' \
  'hl.dsp.exec_raw("unsafe-example")' \
  'os.execute("unsafe-example")' \
  'io.popen("unsafe-example")' \
  'local command = "uwsm app -- unsafe-example"'; do
  printf 'hl.on("hyprland.start", function()\n  %s\nend)\n' "${unsafe_call}" \
    >"${unsafe_fixture}"
  case "${unsafe_call}" in
    'local command = "uwsm app -- unsafe-example"')
      unsafe_reason='forbidden command context: uwsm app'
      ;;
    *)
      unsafe_identifier="${unsafe_call%%(*}"
      unsafe_reason="forbidden builtin identifier: ${unsafe_identifier}"
      ;;
  esac
  expected_callback="hl.on(\"hyprland.start\", function() ${unsafe_call} end)"
  expected_diagnostic="$(printf \
    'Unsafe hyprland.start callback at %s:1-3: %s\nCaptured callback: %s' \
    "${unsafe_fixture}" "${unsafe_reason}" "${expected_callback}")"
  assert_callback_rejected \
    1 "${expected_diagnostic}" "multiline unsafe callback ${unsafe_call}"
done

cat >"${unsafe_fixture}" <<'LUA'
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = 2 }))
LUA
expected_diagnostic="$(printf \
  'Unclosed hyprland.start callback at %s:1-2\nCaptured callback: hl.on("hyprland.start", function() hl.dispatch(hl.dsp.focus({ workspace = 2 }))' \
  "${unsafe_fixture}")"
assert_callback_rejected \
  2 "${expected_diagnostic}" 'unterminated multiline callback'

safe_fixture="${callback_test_root}/safe.lua"
cat >"${safe_fixture}" <<'LUA'
local explanation = true -- hl.on("hyprland.start", function() hl.exec_cmd("docs") end)
local example = 'hl.on("hyprland.start", function() hl.exec_cmd("docs") end)'
local bracket_example = "[=[ordinary quoted text]=]"
hl.on("hyprland.start", function()
  local lookalikes = {
    hl.exec_cmd_safe,
    hl.dsp.exec_cmd_safe,
    hl.exec_raw_safe,
    hl.dsp.exec_raw_safe,
    os.execute_safe,
    io.popen_safe,
    fake_hl.exec_cmd,
    "hl.exec_cmd",
  }
  hl.dispatch(hl.dsp.focus({ workspace = 2 }))
end)
LUA
start_callbacks_are_safe "${safe_fixture}"
rm -rf "${callback_test_root}"
callback_test_root=""
printf 'ok: startup callbacks lex comments and reject unsafe dispatcher aliases\n'

HYPRLAND_BIN="${HYPRLAND_BIN:-}" "${repo_dir}/tests/hyprland-lua.sh"
