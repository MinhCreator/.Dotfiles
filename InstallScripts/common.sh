#!/bin/bash
# everything the installers kept copy pasting

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

info()    { echo -e "${CYAN}${BOLD}[•]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

# ask "question" [n], yes by default unless you pass n
ask() {
    local a def="${2:-y}"
    read -rp "$1 ($([[ $def == y ]] && echo Y/n || echo y/N)): " a
    [[ "${a:-$def}" =~ ^[Yy]$ ]]
}

# pick "prompt" labels..., PICK ends up as the 0 based index
pick() {
    local prompt="$1" i=1 label choice
    shift
    for label; do echo "$i. $label"; ((i += 1)); done
    read -rp "$prompt [1]: " choice
    choice="${choice:-1}"
    [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= $#)) || { error "Invalid choice."; return 1; }
    PICK=$((choice - 1))
}

# install_or_remove name install_fn remove_fn
install_or_remove() {
    local choice
    read -rp "$1: (1) Install/Update (2) Uninstall [1]: " choice
    case "${choice:-1}" in
        1) "$2" ;;
        2) "$3" ;;
        *) error "Invalid option."; return 1 ;;
    esac
}

# standalone installers set PACKAGES and AUR_PACKAGES
install_packages() {
    local helper
    helper="$(command -v yay || command -v paru || true)"
    if [[ -n "$helper" ]]; then
        "$helper" -S --needed "${PACKAGES[@]}" "${AUR_PACKAGES[@]}"
    elif command -v pacman >/dev/null; then
        warn "No AUR helper (yay/paru) found; skipping ${AUR_PACKAGES[*]}."
        sudo pacman -S --needed "${PACKAGES[@]}"
    else
        warn "Not an Arch system; install these yourself: ${PACKAGES[*]} pywal16"
    fi
}

# wal palette from the dotfiles wallpaper if there isn't one, fails if it still isn't there after
ensure_wal() {
    [[ -f "$1" ]] && { success "Using your existing pywal palette."; return 0; }
    if command -v wal >/dev/null; then
        info "Generating a pywal palette from the default wallpaper."
        # -n keeps the wallpaper, -s -t skips terminals
        wal -q -n -s -t -i "$REPO/wallpapers/pywallpaper.jpg" || true
    fi
    [[ -f "$1" ]] && success "Pywal palette generated."
}
