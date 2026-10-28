#!/bin/bash
# full wallpaper library lives in elifouts/wallpapers. git dir sits outside the folder so
# Dotfiles doesn't see a nested repo and can still track the favorites
set -euo pipefail

LIB="${WALLPAPER_LIBRARY:-$HOME/wallpapers/library}"
export GIT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wallpapers.git"
URL=https://github.com/elifouts/wallpapers.git

case "${1:-}" in
    install)
        if [[ ! -d $GIT_DIR ]]; then
            git init -q
            git config core.bare false
            git config core.worktree "$LIB"
            # -t main so normal pulls never grab archive or gh-pages
            git remote add -t main origin "$URL"
            echo favorites.txt >> "$GIT_DIR/info/exclude"
        fi
        mkdir -p "$LIB"
        git fetch --depth 1 origin main
        git checkout -qf -B main origin/main ;;
    pull) git pull --ff-only ;;
    # everything: full history, every branch, and the archive unpacked next to the library
    dev-pull)
        [[ $(git rev-parse --is-shallow-repository) == true ]] && git fetch --unshallow origin
        git fetch origin '+refs/heads/*:refs/remotes/origin/*'
        git pull --ff-only
        mkdir -p "$LIB/../archive"
        git archive origin/archive | tar -x -C "$LIB/../archive" ;;
    push)
        git add -A
        git commit -qm "${2:-update wallpapers}" || true
        git push origin main ;;
    *) git "${@:-status}" ;;
esac
