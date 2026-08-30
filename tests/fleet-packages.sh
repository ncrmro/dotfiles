#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
stow_root="${test_root}/dotfiles"
mkdir -p "${stow_root}"
cp "${repo_dir}/install.sh" "${stow_root}/install.sh"
cp -a "${repo_dir}/packages" "${stow_root}/packages"
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

  ln -s "$(realpath -m --relative-to="$(dirname "${target}")" "${source}")" \
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
  HOME="${test_home}" "${stow_root}/install.sh" --check "${packages[@]}"

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
    ! test -L "${test_home}/.config/hypr/hyprland.conf"
    ! test -L "${test_home}/.config/hypr/ncrmro.conf"
    ! test -L "${test_home}/.config/hypr/host.conf"
    test -L "${test_home}/.config/hypr/host.lua"
  fi

  rm -rf "${test_home}"
  printf 'ok: %s\n' "${host}"
done

themes_dir="${repo_dir}/packages/themes/.config/keystone/theme-catalogs/user"
mapfile -t theme_dirs < <(find "${themes_dir}" -mindepth 1 -maxdepth 1 -type d | sort)
test "${#theme_dirs[@]}" -eq 15
! find "${themes_dir}" -name zellij.conf -type f | grep -q .
! test -e "${repo_dir}/packages/zellij/.config/zellij/themes/royal-green.kdl"

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
# `set -e` does NOT abort on a `!`-negated command, so every negative
# assertion here must go through refute() or it silently passes forever.
refute() {
  local why="$1"
  shift
  if grep "$@" >/dev/null; then
    printf 'FAIL: %s\n' "${why}" >&2
    grep -n "$@" >&2 || true
    exit 1
  fi
}

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
refute 'lid-open DPMS must dispatch from a timer, not straight from the bind' \
  -E 'hl\.bind\([^\n]*hl\.dsp\.dpms' "${hyprland_lua}"
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
  -Ei '(^|[^[:alnum:]_])waybar([^[:alnum:]_]|$)' "${hyprland_lua}"

! grep -Eq 'systemctl --user import-environment|dbus-update-activation-environment|hyprctl dispatch exit' "${hyprland_lua}"
! grep -Eq 'WLR_RENDERER_ALLOW_SOFTWARE|HYPRCURSOR_' "${uwsm_env}"
! grep -Eq '^[[:space:]]*export[[:space:]]+GTK_THEME=' "${uwsm_env}"
grep -Fxq 'export XDG_DATA_DIRS="${XDG_DATA_DIRS:-$HOME/.local/share:/usr/local/share:/usr/share}:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share"' "${uwsm_env}"
grep -Fxq 'export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gcr/ssh"' "${uwsm_env}"
grep -Fxq 'export HYPRCURSOR_SIZE=24' "${uwsm_hyprland_env}"
grep -Fxq 'export HYPRCURSOR_THEME=Adwaita' "${uwsm_hyprland_env}"
! grep -Fq 'WLR_RENDERER_ALLOW_SOFTWARE' "${uwsm_hyprland_env}"

zsh -n "${zsh_env}"
socket_test_root="$(mktemp -d)"
socket_agent_pid=""
cleanup_socket_test() {
  if [[ -n "${socket_agent_pid}" ]]; then
    kill "${socket_agent_pid}" 2>/dev/null || true
    wait "${socket_agent_pid}" 2>/dev/null || true
  fi
  rm -rf "${socket_test_root}"
}
trap cleanup_socket_test EXIT
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
trap - EXIT
printf 'ok: SSH agent socket selection\n'

test "$(find "${repo_dir}/packages/themes/.config/keystone/theme-catalogs/user" -name hyprland.lua -type f | wc -l)" -eq 2
! find "${repo_dir}/packages/themes/.config/keystone/theme-catalogs/user" -name hyprland.conf -type f | grep -q .
! find "${repo_dir}/packages" \( -path '*/hyprland.conf' -o -path '*/ncrmro.conf' -o -path '*/host.conf' \) -type f | grep -q .

for ecosystem_config in hypridle.conf hyprlock.conf hyprpaper.conf hyprsunset.conf xdph.conf; do
  test -f "${repo_dir}/packages/hyprland-common/.config/hypr/${ecosystem_config}"
done
printf 'ok: Hyprland Lua contract\n'

mapfile -t startup_configs < <(
  find "${repo_dir}/packages" -type f \
    \( -path '*/.config/hypr/hyprland.lua' \
    -o -path '*/.config/hypr/user.lua' \
    -o -path '*/.config/hypr/host.lua' \) | sort
)
start_callbacks_are_safe() {
  local file
  for file in "$@"; do
    awk '
      # Contract: hyprland.start callbacks may only perform compositor-local
      # typed dispatch and configuration work. They must not launch a shell,
      # process, GUI, or long-lived service, directly or through a local
      # alias of a Hyprland command dispatcher.
      function unsafe(callback, normalized, remaining, captures, alias, pattern) {
        normalized = callback
        gsub(/[[:space:]]+/, " ", normalized)
        if (normalized ~ /hl[.]exec_(cmd|raw)[[:space:]]*\(/ \
          || normalized ~ /hl[.]dsp[.]exec_(cmd|raw)[[:space:]]*\(/ \
          || normalized ~ /os[.]execute[[:space:]]*\(/ \
          || normalized ~ /io[.]popen[[:space:]]*\(/ \
          || normalized ~ /uwsm[[:space:]]+app/) {
          return 1
        }

        remaining = normalized
        pattern = "(^|[^[:alnum:]_])((local[[:space:]]+)?([[:alpha:]_][[:alnum:]_]*))[[:space:]]*=[[:space:]]*hl[.](dsp[.])?exec_(cmd|raw)([^[:alnum:]_]|$)"
        while (match(remaining, pattern, captures)) {
          alias = captures[4]
          if (normalized ~ ("(^|[^[:alnum:]_])" alias "[[:space:]]*[(]")) {
            return 1
          }
          remaining = substr(remaining, RSTART + RLENGTH)
        }
        return 0
      }

      BEGIN {
        active = 0
        depth = 0
      }

      {
        code = $0
        trimmed = code
        sub(/^[[:space:]]+/, "", trimmed)
        if (!active && trimmed ~ /^--/) {
          next
        }

        if (!active) {
          if (!match(code, /hl[.]on[[:space:]]*\([[:space:]]*["\047]hyprland[.]start["\047]/)) {
            next
          }
          active = 1
          depth = 0
          callback = ""
          code = substr(code, RSTART)
        }

        quote = ""
        escaped = 0
        for (i = 1; i <= length(code); i++) {
          character = substr(code, i, 1)
          following = substr(code, i + 1, 1)

          if (quote == "" && character == "-" && following == "-") {
            break
          }

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
          exit 2
        }
      }
    ' "${file}" || return 1
  done
}

start_callbacks_are_safe "${startup_configs[@]}"

callback_test_root="$(mktemp -d)"
trap 'rm -rf "${callback_test_root}"' EXIT
unsafe_fixture="${callback_test_root}/unsafe.lua"
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
  if start_callbacks_are_safe "${unsafe_fixture}"; then
    printf 'Startup callback guard accepted unsafe call: %s\n' "${unsafe_call}" >&2
    exit 1
  fi
done

safe_fixture="${callback_test_root}/safe.lua"
cat >"${safe_fixture}" <<'LUA'
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = 2 }))
end)
LUA
start_callbacks_are_safe "${safe_fixture}"
rm -rf "${callback_test_root}"
trap - EXIT
printf 'ok: active startup callbacks are compositor-local\n'

HYPRLAND_BIN="${HYPRLAND_BIN:-}" "${repo_dir}/tests/hyprland-lua.sh"
