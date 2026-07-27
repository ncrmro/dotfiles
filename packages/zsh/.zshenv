# Environment variables
. "/etc/profiles/per-user/${USER:-$(id -un)}/etc/profile.d/hm-session-vars.sh"

# Only source this once
if [[ -z "$__HM_ZSH_SESS_VARS_SOURCED" ]]; then
  export __HM_ZSH_SESS_VARS_SOURCED=1
  
fi

if [ -z "$SSH_AUTH_SOCK" ]; then
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent
fi

ZSH="/etc/profiles/per-user/${USER:-$(id -un)}/share/oh-my-zsh";
ZSH_CACHE_DIR="/home/ncrmro/.cache/oh-my-zsh";
