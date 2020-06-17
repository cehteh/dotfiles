#!/bin/bash

#PLANNED: ignore file list for autocommit
#PLANNED: rewrite history to include only current files
#PLANNED: prune history since some time in the past

test -f "$HOME/.dotfilesrc" && . "$HOME/.dotfilesrc"

export GIT_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
export DOTFILES_BRANCH="${DOTFILES_BRANCH:-$(whoami)@$(hostname)}"
export DOTFILES="$(realpath $0)"

case "$1" in

install) # install 'dotfiles' to ~/.dotfiles.sh and then to $2 or /usr/local/bin
    # first case: install from git
    DOTFILES_PATH="${DOTFILES%/*}"
    if test -f "${DOTFILES_PATH}/.DOTFILES_DISTRIBUTION"; then
        cp -v "$DOTFILES" "$HOME/.dotfiles.sh" && chmod +x "$HOME/.dotfiles.sh"
    fi

    # and then to the given folder
    test "$DOTFILES" != "${2:-/usr/local/bin}/dotfiles" &&
        cp -v "$DOTFILES" "${2:-/usr/local/bin}/dotfiles" && chmod +x "${2:-/usr/local/bin}/dotfiles"
    exit $?
    ;;

init) # initialize the '~/.dotfiles' repository
    if test ! -d "$GIT_DIR"; then
        mkdir -p "$GIT_DIR"
        git init --bare "$GIT_DIR"
        git symbolic-ref HEAD "refs/heads/$DOTFILES_BRANCH"
        git config --local status.showUntrackedFiles no

        if test -f ".dotfiles.sh"; then
            git add ".dotfiles.sh"
        fi

        exit 0
    else
        echo "already initialized" 1>&2
        exit 1
    fi
    ;;

help)
    ;;

*)
    if test ! -d "$GIT_DIR"; then
        echo "not initialized" 1>&2
        exit 1
    fi
    ;;
esac

export GIT_WORK_TREE="${DOTFILES_HOME:-$HOME}"


function push_git()
{
    if [[ "$DOTFILES_PUSH" ]]; then
	for remote in $DOTFILES_PUSH; do
	    git push "$remote" &>/dev/null &
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

This file should reside as ~/.dotfiles.sh.  That makes it possible
to revision and upgrade itself. An user can then install to
'/usr/local/bin' or any other directory.

After that the 'init' command sets up '~/.dotfiles' as bare git
repository where configuration files will be stored. There will be no
'master' branch but a "\$USER@\$HOSTNAME" branch. This makes it
possible to manage dotfiles from different users/hosts in a single
repository and checkout/merge specific parts without affecting the
configuration of other installations.

If existing the '~/.dotfilesrc' file can be used to customize certain
aspects (see CONFIGURATION below).

dotfiles is a very thin layer over 'git' it adds a few commands for
convenience but otherwise all normal git commands are available.

COMMANDS

$(sed 's/ *\([[:alpha:]]*\)[^)]*) *# \(.*\)/  \1\n     \2\n/p;d' < "$DOTFILES")

CONFIGURATION

  The user can configure variables in '~/.dotfilesrc'. When this file
  does not exist or variables are not defined, defaults apply. This
  configuration should be done before calling 'dotfiles init'.

  DOTFILES_DIR="\$HOME/.dotfiles"
    The directory where 'dotfiles' will create the local repository

  DOTFILES_BRANCH="\$(whoami)@\$(hostname)"
    Git branch name for local commits.

  DOTFILES_HOME="\$HOME"
    The top-level directory to be tracked.

  DOTFILES_PUSH
    A list of remotes where to push automatically after storing changes.

  DOTFILES_UPGRADE
    remote/branch specification from where to update 'dotfiles' itself


EXAMPLES SETUP

  install from git (upstream) as /usr/local/bin/dotfiles
    git clone --sparse git://git.pipapo.org/dotfiles
    cd dotfiles
    bash dotfiles.sh install

  (re-)install as /usr/local/bin/dotfiles
    bash ~/.dotfiles.sh install

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

  Confirm git-crypt is working
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

  Updates dotfiles from the upstream/original repository
    dotfiles remote add upstream git://git.pipapo.org/dotfiles
    echo 'DOTFILES_UPGRADE="upstream/master"' >>.dotfilesrc
    dotfiles upgrade


HIDDEN FEATURES

  * 'dotfiles' can also manage regular files, despite it's name

  Untested:
  * It may work with git-annex and git-lfs and other git extensions


CONTRIBUTING

  This is an open project, fork it, hack it, send patches!
  Note that the 'README' is autogenerated by
    ./dotfiles.sh > README

  All content is in 'dotfiles.sh'.

  consider following as .git/hooks/pre-commit:
    #!/bin/sh
    bash dotfiles.sh > README
    git add README


LICENSE

    dotfiles -- manage your dotfiles in git
    Copyright (C) 2020  Christian Thäter <ct.dotfiles@pipapo.org>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

EOF
    fi
    ;;

autocommit) # do an automatic commit saving all pending changes (for cron)
    shift
    git commit -a -m "autocommit:

$(git status -s)"
    push_git
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
    push_git
    ;;

inventory) # list all files ever manged in dotfiles
    git log --pretty=format: --name-only --diff-filter=A | sort -u
    ;;

upgrade) # upgrade dotfiles itself
    cd "$HOME"
    if [[ ! "$(dotfiles ls-files -m ".dotfiles.sh")" && "$DOTFILES_UPGRADE" ]]; then
        git remote update "${DOTFILES_UPGRADE%%/*}"
        git show "${DOTFILES_UPGRADE}:dotfiles.sh" >".dotfiles.sh$$"
        rm ".dotfiles.sh" && mv -v ".dotfiles.sh$$" ".dotfiles.sh"

        if [[ "$(dotfiles ls-files -m ".dotfiles.sh")" ]]; then
            git add -- ".dotfiles.sh"
            git commit -m ".dotfiles.sh upgrade"
            push_git
            cp -v ".dotfiles.sh" "$DOTFILES$$" && chmod +x "$DOTFILES$$" || {
                    echo "upgrade-install failed" 1>&2
                    exit 1
                }
            rm "$DOTFILES" && mv -v "$DOTFILES$$" "$DOTFILES"
       fi
    fi
    ;;

*)
    git "$@"
    push_git
    ;;
esac


