# Path to your oh-my-zsh configuration.
export ZSH=$HOME/.oh-my-zsh

if [[ `uname` == "Darwin" ]]; then
    OSX=1
fi

ZSH_THEME="robbyrussell"

plugins=(
  gem
  git
  git-extras
  github
  kubectl
  kubectx
  nvm
  rails
  rake
  rbenv
  ssh
)

source $ZSH/oh-my-zsh.sh

if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

eval "$(rbenv init - --no-rehash zsh)"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
eval "$(pyenv virtualenv-init -)"
