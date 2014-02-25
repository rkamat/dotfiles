#!/bin/bash

GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWSTASHSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM=auto

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -d /usr/local/etc/bash_completion.d ]; then
  for f in /usr/local/etc/bash_completion.d/*; do
    . $f
  done
fi

for f in git-completion.bash git-prompt.sh; do
  xcode=/Applications/Xcode.app/Contents/Developer/usr/share/git-core
  [ ! -f "$xcode/$f" ] || . "$xcode/$f"
  unset xcode
done

[ ! -f /usr/share/git-core/git-completion.bash ] || . /usr/share/git-core/git-completion.bash
[ ! -f /usr/share/git-core/git-prompt.sh ] || . /usr/share/git-core/git-prompt.sh

case $(type -t __git_ps1) in
  function)
    ;;
  *)
    __git_ps1 () { :; }
    ;;
esac

pxy () {
  local proxy="${1:-def}"

  if [[ "$proxy" = 'def' ]];    then proxy='http://default.proxy:8080'
  elif [[ "$proxy" = 'another' ]];   then proxy='http://a.nother.proxy:8080'
  fi

  if [[ "$proxy" = 'none' ]]; then
    echo 'Unsetting proxy'
    unset {http,https,ftp}_proxy
  else
    echo "Setting proxy to $proxy"
    export {http,https,ftp}_proxy=$proxy
  fi
}

__ps1_proxy () {
  local pxy=$http_proxy
  if [ -z "$http_proxy" ]; then return
  elif [[ "$http_proxy" = 'http://default.proxy:8080' ]];  then pxy='def'
  elif [[ "$http_proxy" = 'http://a.nother.proxy:8080' ]];  then pxy='another'
  fi
  echo " (pxy $pxy)"
}

# Displays the current working directory with s/$HOME/~/, but truncates leading
# directories until either the string is -lt $maxlen, or we're left with only
# one pathname, in which case we just show it and forget about $maxlen.
PS1_MAX_CWDLEN=25
__ps1_cwd () {
  local maxlen=$PS1_MAX_CWDLEN
  local dir=${PWD/$HOME/'~'}
  local ddd=""
  while [ ${#dir} -gt $maxlen ]; do
    ddd="…/"
    local trimmed=${dir#*/}
    if [ "$trimmed" = "$dir" ]; then break; fi
    dir=$trimmed
  done
  echo "${ddd}${dir}"
}

__ps1_prompt () {
  local GREEN='\[\033[01;32m\]'
  local YELLOW='\[\033[01;33m\]'
  local CYAN='\[\033[01;36m\]'
  local RED='\[\033[01;31m\]'
  local ORANGE='\[\033[38;5;166m\]'
  local RESET='\[\033[00m\]'
  PS1="$GREEN"'[\u@'"$YELLOW"'\h '"$CYAN"'$(__ps1_cwd)'"$RED"'$(__git_ps1 " (%s)")'"$ORANGE"'$(__ps1_proxy)'"$GREEN"']\$ '"$RESET"
}
__ps1_prompt
unset __ps1_prompt

# "ep": (+) append, prepend(^) or remove(-) dirs in a "PATH" var (colon-separated list).
#	- save original var value as "ORIG_var" (the first time)
#	- remove duplicates; lets you shuffle dirs to front or back.
#	- do NOT append dir if it doesn't exist -- useful across multi platforms.
# ep accepts multiple dirs, but processes them left-to-right,
#   so "^dir" ops are prepended in the counterintuitive (reverse) order.

ep () {
  typeset args="$*" dir op val front var

  case "$1" in [-+^]*) var=PATH ;; [A-Z_a-z]*) var=$(env | sed -n "/^$1[A-Z_0-9]*PATH=/{s/=.*//p;q;}"); shift ;;
    *) echo >&2 'Usage: ep [var] [-+^]dir...'; return
  esac
  if [ -z "$var" ]; then echo >&2 "ep: unknown *path variable"; return; fi
  if [ $# = 0 ]; then path $var; return; fi

  eval "val=:\$$var:; test \"\$ORIG_$var\" || export ORIG_$var=\"\$$var\""
  test :: != $val || val=:
  for dir; do
    case $dir in -?*) op=- ;; ^?*) op=^ ;; +?*) op=+ ;; *) continue; esac
    eval dir=${dir#$op}         # Ensures ~ is expanded
    test -z $dir || val=${val//:$dir:/:}
    if [ -d $dir -o -L $dir ]; then
      case $op in [-!]) ;; ^) val=:$dir$val ;; +) val=$val$dir: ;; esac
    fi
  done

  val=${val%:}	# trailing :
  val=${val#:}	# leading :
  eval $var=$val
}

# how	Like "which", but finds aliases/bash-fns and perl modules.
#       Expands symlinks and shows file type.
how () {
  PATH=$PATH  # reset path search
  shopt -s extdebug
  typeset -F $1 2>&- \
  || alias $1 2>&- \
  || case $1 in *::*)
    perl -m$1 -e '($x="'$1'")=~s|::|/|g; print $INC{"$x.pm"}."\n"'
    ;;
   *)
    local w=$(which $1)
    if [ "$w" ]; then
      local r=$(realpath $w)
      test $w = $r || echo -n "$w -> "
      file $r | sed s/,.*//
    fi
   esac
  shopt -u extdebug
}

path () {
    typeset var=${1:-PATH}
    eval "env |egrep -i ^$var[a-z_0-9]*=[^\(]" | sed '/=(/!{s|=|:|; s|:|\
    |g; s|'$HOME'|~|g; }'
}

# wi    Edit a script in $PATH. Chains through symlinks.
#	Also: edit aliases and bash-fns in file from which they were sourced.
wi () {
  EDITOR=${EDITOR:-vi}
  PATH=$PATH  # Forced reset of path cache
  if alias $1 2>&- && egrep -q ^alias.$1 ~/.bashrc
  then $EDITOR +/"alias.$1" ~/.bashrc; . ~/.bashrc
  elif typeset -F $1 >/dev/null
  then shopt -s extdebug; set -- $(typeset -F $1); shopt -u extdebug
    # With extdebug on, "typeset -F" prints: funcname lineno filename
    $EDITOR +$2 $3; . $3
  else    set -- $(echo $(which $1))
    if [ $# -gt 0 ]
    then
      set -- $(file -L $1)
      case "$*" in
        *\ script*|*\ text*) $EDITOR ${1%:} ;;
        *)                   echo >&2 $*
    esac
  fi
fi
}

hi () {
  term=$1; shift
  [ -n "$term" ] || {
    echo -e "Usage: hi perl-regexp\nHighlight a term in a stream of text" 1>&2;
    return 1
  };
  if [ -z "$*" ]; then set /dev/stdin; fi
  perl -pe 'BEGIN{$a=shift}s/$a/\e[31m$&\e[0m/g' "$term" "$@"
}

spawn_selenium () {
  java -jar /usr/local/opt/selenium-server-2.15.0/share/selenium-server-standalone-2.15.0.jar \
    -trustAllSSLCertificates \
    "$@"
}

b64 () {
  echo -n "$@" ---- | tr - = | base64 -D; echo
}

pi () {
  cpanm -S "$@"
}

trim () { echo $1; }

tmx () {
  local session=$1; shift

  count=$(tmux ls | grep "^$session" | wc -l)
  if [[ "$(trim $count)" = 0 ]]; then
    echo "Launching new session $session..."
    tmux new-session -d -s $session
  fi

  count=$(tmux list-windows -t $session | grep -w log | wc -l)
  if [[ "$(trim $count)" = 0 ]]; then
    tmux new-window -d -n log -t $session:9 'tail -40F /var/log/system.log'
  fi

  tmux attach-session -t $session
}

tmux_buffer () {
  tmux show-buffer -b 0 >/dev/null 2>&1 || tmux set-buffer foo
  # Arbitrarily assume a history-limit of 2000 lines.
  tmux capture-pane -b 0 -J -S -2000 "$@"
  tmux show-buffer -b 0
}

psgrep () {
  ps axuwww | grep -i "$@"
}
pslsof () {
  sudo lsof -p $(psgrep "$@" | perl -lane 'push @L,$F[1];END{print join",",@L}' )
}
pskill () {
  psgrep "$@" | awk '{print $2}' | sudo xargs kill -KILL 2>/dev/null
}
psterm () {
  psgrep "$@" | awk '{print $2}' | sudo xargs kill -TERM 2>/dev/null
}
hup () {
  psgrep "$@" | awk '{print $2}' | sudo xargs kill -HUP 2>/dev/null
}

__p4g_find_last_git_commit () {
  p4 changes "$p4path/..." | while read Change n other
  do
    commit=$(p4 describe -s $n | perl -ne 'print $1 if /git:([a-f0-9]{40})/i');
    if test -n "$commit"; then
      echo "$n/$commit"
      break
    fi
  done
}

# Replays perforce commits on top of the current Git repository.
#
# Works by searching through the perforce changes until it finds one which
# mentions a Git commit (40-byte SHA-1, prefixed by lowercase 'g').
#
# For example:
#
# ----8<----
# Change 2299877 by FooBar@foo-bar on 2013/03/13 15:32:44
#
#         p4g: automated commit of app/frontend.git, commit 42a02494c402d74266f62348b3c260fb214bd4be
#
#         git:42a02494c402d74266f62348b3c260fb214bd4be
# ---->8----
#
# When it finds such a change, it creates a temporary git branch based on the
# referenced git commit. Then it applies each Perforce change in turn. It
# leaves you with a branch that you can merge with the master branch or whatever.
p4g () {
  p4path=$1
  gitbranch=$2

  [ $# = 2 ] || { echo "Usage: p4g ~/path/to/perforce/workspace temp-branch

  Replays perforce commits on top of the current Git repository, using a temporary
  branch.
"; return 1; }

  info=$(__p4g_find_last_git_commit "$p4path")
  p4change=${info%%/*}
  gitcommit=${info#*/}

  # Create a new temporary branch based on the last found git revision
  echo "p4g: creating git branch $gitbranch based on $gitcommit (p4 change $p4change)"
  git checkout -b "$gitbranch" "$gitcommit"
  git clean -f -f -d -x
  git submodule init
  git submodule update

  # Start with a known-clean perforce tree
  echo "p4g: force-syncing $p4path/...@$p4change"
  rm -rf $p4path || { echo "FAIL: rm -rf $p4path"; return 1; }
  p4 sync -f $p4path/...@$p4change >& /dev/null || { echo "FAIL: p4 sync -f $p4path/...@$p4change"; return 1; }
  echo "p4g: force-syncing done"

  startfrom=$(( $p4change + 1 ))
  p4 changes -t "$p4path/...@$startfrom,#head" | tail -r | while read Change n on date time by user other
  do
    echo "p4g: applying change $n"

    echo "p4g: p4 sync $p4path/...@$n"
    p4 sync $p4path/...@$n >& /dev/null
    git ls-files | while read file; do rm -f "$file"; done
    tar -C $p4path -cf - . | tar -xf -
    find . ! -type d -print0 | perl -n0e 'unlink if /designOnly/'
    find . ! -type d -print0 | xargs -0 chmod u+w
    git status --porcelain | while read stat file
    do
      case "$stat" in
        D)
          git rm "$file"
          ;;
        M)
          git add "$file"
          ;;
        "??")
          git add "$file"
          ;;
        *)
          echo "unknown git status '$stat' for file '$file'" >&2
          return 1
      esac
    done
    message_1st=$(p4 describe -s $n | grep '^\t' | head -n 1)
    message_2nd=$(p4 describe -s $n | grep '^\t' | tail -n +2)
    message_2nd+="[p4: change $n on $date $time by $user]"
    git commit -m "$(echo $message_1st)

$message_2nd"
    git clean -d -f
  done
}

# Exports the contents of the current git repository and branch into a perforce
# location.
#
# NOTE: this is a blind export: all changes should be merged to your Git area
# before doing this, because the perforce contents are completely overwritten.
g4p () {
  p4path=$1

  [ $# = 1 ] || { echo "Usage: g4p ~/path/to/perforce/workspace

  Exports current git repository/branch into the specified perforce location.
"; return 1; }

  p4 revert -k $p4path/...
  rm -rf $p4path
  mkdir -p $p4path
  origin=$(git config remote.origin.url)
  head=".git/$(git symbolic-ref -q HEAD || echo HEAD)"
  commit=$(cat $head)
  git archive --format=tar $commit | tar -C $p4path -xf -
  parent=${p4path%/*}
  child=${p4path##*/}
  pushd "$parent"
  find "$child" ! -type d -print0 | xargs -0 chmod a-w
  find "$child" | p4 -x- add 2>/dev/null # lots of warnings about existing files
  p4 diff -sd "$child/..." | p4 -x- delete
  p4 diff -se "$child/..." | p4 -x- edit
  cat >.COMMIT <<CHANGELOG
Change: new

Description:
	p4g: automated commit of $origin, commit $commit

	git:$commit

Files:
CHANGELOG
  p4 opened ... | perl -lpe 's{^(.*)#\d+ - (\w+).*$}{\t$1\t# $2}g' >> .COMMIT
  p4 submit -i < .COMMIT
  rm -f .COMMIT
  popd
}

git_repo_is_clean () {
  if ! git diff-index --cached --quiet HEAD --; then
    echo "You have staged changes; commit them first"
    return 1
  fi
  if ! git diff --no-ext-diff --quiet --exit-code; then
    echo "You have modified files in your workspace; commit them first"
    return 1
  fi
  if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "You have untracked files in your workspace; commit or delete them first"
    return 1
  fi
}

function _cache_git_dirs() {
  [[ -z $__GIT_DIRS ]] && __GIT_DIRS=$(find ~/g -type d -path "*/.git" -maxdepth 4)
}

# cd into a git repo under ~/g
function cgd() {
  local git_dir

  _cache_git_dirs
  git_dir=$(grep "/${1}/\.git$" <<< "$__GIT_DIRS" | head -n1)
  [[ ! -d "$git_dir" ]] || cd "${git_dir}/.."
}

function _cgd() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local words=""
  local git_dir

  _cache_git_dirs
  while read git_dir; do
    git_dir=$(dirname "$git_dir")
    words="${words} ${git_dir##*/}"
  done < <(grep "/${cur}.*/\.git$" <<< "$__GIT_DIRS")
  COMPREPLY=( $(compgen -W "$words" -- $cur) )
}

alias cdg=cgd
complete -F _cgd cgd
complete -F _cgd cdg

# rebind 'freeze terminal' from ^S to ^O so reverse/incremental search works intuitively.
stty stop ^S

alias start-selenium=spawn_selenium
alias ll='ls -l'
alias la='ls -al'
alias l='less -S'
alias g='git'
# Make sure completion works for alias g=git, too
complete -o bashdefault -o default -o nospace -F _git g 2>/dev/null \
	|| complete -o default -o nospace -F _git g

export P4CLIENT="$USER-saas-pair"
export P4EDITOR='vim +"set ft=p4"'
export P4PORT='perforce:1666'
export P4USER='FooBar'

export COLORTERM=1
export CLICOLOR=1
export GREP_COLOR='1;31'
export GREP_OPTIONS='--color=auto'
export PS1

umask 002

# Manipulate $PATH
ep ^/usr/local/sbin
ep ^/usr/local/bin
ep +~/bin
ep +/usr/local/share/npm/bin

export NODE_PATH="/usr/local/share/npm/lib/node_modules/:/usr/local/lib/node_modules/:${NODE_PATH}"

alias ej="diskutil eject /Volumes/$(whoami)"

# First, we ensure that the hammer-api Gem is pointing at the correct repo and checkout.
# Then, we ensure that Gemfile.lock didn't get changed (and nor did anything else).
# Then, we run all tests.
# Then, we check that the tests didn't change or add any files to the working directory.
# Then, we push!
alias rp="git_repo_is_clean && bundle exec rake && git_repo_is_clean && git push"

alias gm="gupdate -g min"

# Increase open file limit for rake
ulimit -S -n 512

# THIS MUST ALWAYS BE THE LAST LINE...
# Source custom .bash init scripts.
[ ! -f ~/.bash_custom ] || . ~/.bash_custom

# vim: set ft=sh:
