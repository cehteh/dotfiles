#!/bin/bash

test -f "$HOME/.dotfilesrc" && source "$HOME/.dotfilesrc"

DOTFILES="$(realpath "$0")"

export GIT_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
export DOTFILES_BRANCH="${DOTFILES_BRANCH:-$(whoami)@$(hostname)}"

if test ! -d "$GIT_DIR"; then
    case "$1" in
    install) # install a 'dotfiles' symlink to this script in $2 or /usr/local/bin
        ln -s "$DOTFILES" "${2:-/usr/local/bin}/dotfiles"
        chmod +x "${2:-/usr/local/bin}/dotfiles"
        exit 0
        ;;
    init) # initialize the '~/.dotfiles' repository
        mkdir -p "$GIT_DIR"
        git init --bare "$GIT_DIR"
        git symbolic-ref HEAD "refs/heads/$DOTFILES_BRANCH"
        git config --local status.showUntrackedFiles no
        exit 0
        ;;
    help)
        ;;
    *)
        echo "not initialized" 1>&2
        exit 0
        ;;
    esac
fi

export GIT_WORK_TREE="${DOTFILES_HOME:-$HOME}"


function push_git()
{
    if [[ "$DOTFILES_PUSH" ]]; then
	for remote in $DOTFILES_PUSH; do
	    git push "$remote" &>/dev/null
	done
    fi
}

case "$1" in
help|'') # show this help
    if test "$2"; then
        shift
        git help "$@"
    else
        less <<EOF

  dotfiles -- manage your dotfiles in git

This file should reside as .dotfiles.sh somewhere (in /root or some
trusted users home).  That makes it possible to revision itself. An
user can then install a symlink from a directory in PATH to this file
to make it accessible for execution.

After that the 'init' command sets up '~/.dotfiles' as bare git
repository where configuration files will be stored. There will be no
'master' branch but a "\$USER@\$HOSTNAME" branch. This makes it
possible to manage dotfiles from different users/hosts in a single
repository and checkout/merge specific parts without affecting the
configuration of other installations.

If existing the '~/.dotfilesrc' file can be used to customize certain
aspects (see CONFIGURATION below).

dotfiles is a very thin layer over 'git' it adds a few commands for
convinience but otherwise all normal git commands are available.

COMMANDS

$(sed 's/ *\([[:alpha:]]*\)[^)]*) *# \(.*\)/  \1\n     \2\n/p;d' < "$0")

CONFIGURATION

  The user can configure variables in '~/.dotfilesrc'. When this file
  does not exist or variables are not defined, defaults apply.

  DOTFILES_DIR="\$HOME/.dotfiles"
    The directory where 'dotfiles' will create the local repository

  DOTFILES_BRANCH="\$(whoami)@\$(hostname)"
    Git branch name for local commits.

  DOTFILES_HOME="\$HOME"
    The toplevel directory to be tracked.

  DOTFILES_PUSH
    A list of remotes where to push automatically after storing changes.

  DOTFILES_UPGRADE
    remote/branch specification from where to update 'dotfiles' itself

EXAMPLES SETUP

  install as /usr/local/bin/dotfiles
    sh ~/.dotfiles.sh install

  initialize dotfiles once before use
    dotfiles init

  register a daily autocommit in the users crontab
    (crontab -l ; echo "@daily dotfiles autocommit" ) | crontab


  use 'git-crypt' for encrypting secret files

  initialize git-crypt
    dotfiles crypt init

  add your own gpg key for decryption
    dotfiles crypt add-gpg-user \$(git config --get user.email)

  set up .gitattributes for files to be encrypted
    echo ".ssh/** filter=git-crypt diff=git-crypt" >>.gitattributes
    echo ".ssh/**/*.pub !filter !diff" >>.gitattributes
    echo ".gnupg/** filter=git-crypt diff=git-crypt" >>.gitattributes
    dotfiles store .gitattributes

  Confirm git-crypot is working
    dotfiles check-attr -a -- .ssh/*


EXAMPLES USAGE

  Add and commit changes in '.fileA' and 'FileB' with "commit
  message". Any non-file argument to 'store' is appended as to the
  commit message.
    dotfiles store .fileA FileB "commit message"

  list all files under dotfiles control
    dotfiles ls-files

  show git status/changes
    dotfiles status
    dotfiles diff

EXAMPLE UPGRADE FROM UPSTREAM

  Updates dotfiles from the upstream/orignal repository
    dotfiles remote add upstream git://git.pipapo.org/dotfiles
    echo 'DOTFILES_UPGRADE="upstream/master"' >>.dotfilesrc
    dotfiles upgrade

EOF
    fi
    ;;
autocommit) # do an automatic commit saving all pending changes (for cron)
    shift
    git commit -a -m "autocommit:

$(git status -s)"
    push_git &
    ;;
store) # add and commit files in one go (any non-file argument becomes the commit message)
    shift
    files=()

    for i in "$@"; do
        if test -f "$i"; then
            files+=("$i")
        else
            msg+="$i
"
        fi
    done
    git add -- "${files[@]}"
    git commit -m "${msg}
stored: ${files[*]}"
    push_git &
    ;;
upgrade) # upgrade dotfiles itself
    git remote update
    if [[ ! "$(dotfiles ls-files -m "$DOTFILES")" && "$DOTFILES_UPDATE" ]]; then
        git checkout "$DOTFILES_UPGRADE" -- "$DOTFILES" 2>/dev/null
        if [[ "$(dotfiles ls-files -m "$DOTFILES")" ]]; then
            git add -- "$DOTFILES"
            git commit -m "update $DOTFILES"
            push_git &
        fi
    fi
    ;;
init)
    echo "$GIT_DIR exists already"
    exit 1
    ;;
*)
    git "$@"
    push_git &
    ;;
esac


