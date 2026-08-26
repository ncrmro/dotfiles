KEYSTONE_PROFILE_ROOT="/etc/profiles/per-user/${USER:-$(id -un)}"
if [[ ! -d "$KEYSTONE_PROFILE_ROOT" ]]; then
  KEYSTONE_PROFILE_ROOT="$HOME/.nix-profile"
fi
export KEYSTONE_PROFILE_ROOT

hm_session_vars="$KEYSTONE_PROFILE_ROOT/etc/profile.d/hm-session-vars.sh"
if [[ -r "$hm_session_vars" ]]; then
  . "$hm_session_vars"
fi
unset hm_session_vars

# Only source this once
if [[ -z "$__HM_ZSH_SESS_VARS_SOURCED" ]]; then
  export __HM_ZSH_SESS_VARS_SOURCED=1
  
fi

if [[ -z "${SSH_AUTH_SOCK:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
  if [[ -S "${XDG_RUNTIME_DIR}/gcr/ssh" ]]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gcr/ssh"
  else
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent"
  fi
fi

ZSH="$KEYSTONE_PROFILE_ROOT/share/oh-my-zsh"
ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
