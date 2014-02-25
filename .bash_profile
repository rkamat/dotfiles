if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# Setup rbenv shims and autocomplete
if $(which rbenv >/dev/null 2>&1); then eval "$(rbenv init -)"; fi
