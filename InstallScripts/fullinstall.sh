
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fullinstall-packages.sh"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

info()    { echo -e "${CYAN}${BOLD}[•]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

DOTFILES_DIR="$HOME/Dotfiles"
HYPRLAND_STYLE_DIR=""

# backups

backup_config() {
    local timestamp="$(date +%Y%m%d_%H%M%S)" item src dest backed_up=false

    for item in \
        "$HOME/.config:$HOME/.config_backup_$timestamp" \
        "$HOME/.icons:$HOME/.icons_backup_$timestamp" \
        "$HOME/wallpapers:$HOME/wallpapers_backup_$timestamp"
    do
        src="${item%%:*}"
        dest="${item#*:}"

        if [[ -e "$src" ]]; then
            info "Backing up $src → $dest"
            mkdir -p "$dest"
            cp -a "$src/." "$dest/"
            success "Backed up $(basename "$src")"
            backed_up=true
        else
            warn "$(basename "$src") not found, skipping."
        fi
    done

    $backed_up && success "Backups complete." || warn "Nothing to back up."
}

backup_bashrc() {
    local dest="$HOME/.bashrc_backup_$(date +%Y%m%d_%H%M%S)"

    [[ -f "$HOME/.bashrc" ]] || { warn "~/.bashrc not found."; return; }

    mkdir -p "$dest"
    cp -a "$HOME/.bashrc" "$dest/.bashrc"
    success "Backed up .bashrc to $dest"
}

# hyprland profile

select_hyprland_style() {
    section "Hyprland Style"

    local profiles=() entry i=1 choice
    while IFS= read -r entry; do
        profiles+=("$entry")
    done < <("$DOTFILES_DIR/.config/hypr/utilities/hypr-profile.sh" list)

    [[ ${#profiles[@]} -gt 0 ]] || { error "No Hyprland profiles found."; return 1; }

    for entry in "${profiles[@]}"; do
        echo "$i. ${entry/\// / }"
        ((i += 1))
    done

    read -rp "Choose a style [1]: " choice
    choice="${choice:-1}"

    [[ "$choice" =~ ^[0-9]+$ ]] &&
        ((choice >= 1 && choice <= ${#profiles[@]})) ||
        { error "Invalid style."; return 1; }

    HYPRLAND_STYLE_DIR="${profiles[$((choice - 1))]}"
    success "Selected ${HYPRLAND_STYLE_DIR/\// / }"
}

# apply dotfiles

link_entry() {
    local target="$1" link="$2" backup="$3"

    if [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
        return
    fi
    if [[ -e "$link" || -L "$link" ]]; then
        mkdir -p "$backup"
        mv "$link" "$backup/$(basename "$link")"
        warn "Moved existing $link to $backup/"
    fi
    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
    success "Linked $link -> $target"
}

apply_dotfiles() {
    section "Linking Dotfiles"

    local src="$DOTFILES_DIR/.config" entry name
    local backup="$HOME/.dotfiles_replaced_$(date +%Y%m%d_%H%M%S)"

    shopt -s nullglob dotglob
    for entry in "$src"/*; do
        link_entry "$entry" "$HOME/.config/${entry##*/}" "$backup/.config"
    done
    for name in wallpapers .bashrc; do
        [[ -e "$DOTFILES_DIR/$name" ]] && link_entry "$DOTFILES_DIR/$name" "$HOME/$name" "$backup"
    done
    shopt -u nullglob dotglob

    git -C "$DOTFILES_DIR" config core.hooksPath .githooks
    link_entry "$HOME/.config/hypr/utilities/pypr.py" "$HOME/.local/bin/pypr" "$backup/.local/bin"

    if [[ -n "$HYPRLAND_STYLE_DIR" ]]; then
        "$src/hypr/utilities/hypr-profile.sh" apply "${HYPRLAND_STYLE_DIR%%/*}" "${HYPRLAND_STYLE_DIR#*/}" --offline
    fi

    success "Dotfiles linked."
    nohup bash -c 'sleep 1; hyprctl reload' >/dev/null 2>&1 &

    # restart the shells so the new utilities load now
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        "$src/hypr/utilities/shells.sh" restart
        "$src/hypr/utilities/bar.sh" boot
    fi
}

run_wallpaper_selector() {
    local script="$HOME/.config/hypr/utilities/shells.sh" choice

    # dotfiles only ship the favorites, the full library is its own repo
    read -rp "Pull the full wallpaper library? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        "$HOME/.config/hypr/utilities/wallpapers.sh" install || warn "Couldn't pull wallpapers, sticking with the defaults."
    fi

    if [[ -x "$script" ]]; then
        section "Selecting Wallpaper"
        "$script" wallpaper open
    else
        warn "Wallpaper selector not found."
    fi
}

# system setup

setup_mirrors() {
    section "Updating Pacman Mirrorlist"
    yay -S --needed reflector rsync
    sudo reflector --country US --latest 10 --sort rate \
        --save /etc/pacman.d/mirrorlist
    success "Mirrorlist updated."
}

autologin_install() {
    local user
    user="$(id -un)"

    yay -S --needed greetd greetd-tuigreet

    sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd start-hyprland"
user = "greeter"

[initial_session]
command = "start-hyprland"
user = "$user"
EOF

    sudo systemctl disable getty@tty1.service
    sudo systemctl enable greetd.service
    success "Autologin configured for $user."
}

autologin_uninstall() {
    sudo systemctl disable greetd.service 2>/dev/null || true
    sudo systemctl enable getty@tty1.service || return 1

    yay -Rns --noconfirm greetd greetd-tuigreet || return 1
    sudo rm -rf /etc/greetd

    sudo systemctl daemon-reload
    sudo systemctl reset-failed greetd.service 2>/dev/null || true
    success "Autologin removed; the default tty1 login will be used on next boot."
}

autologin() {
    local choice
    read -rp "Autologin: (1) Install/Update (2) Uninstall [1]: " choice

    case "${choice:-1}" in
        1) autologin_install ;;
        2) autologin_uninstall ;;
        *) error "Invalid option."; return 1 ;;
    esac
}
# hyprpm plugins need rebuilding after hyprland updates
update_plugins() {
    command -v hyprpm >/dev/null || return 0
    hyprpm list 2>/dev/null | grep -qi hyprglass || return 0

    info "Updating Hyprland plugins..."
    hyprpm update || { warn "hyprpm update failed; run it manually."; return 0; }
    hyprpm reload -n >/dev/null 2>&1 || true
    success "Hyprland plugins up to date."
}

glass_install() {
    yay -S --needed hyprpm
    hyprpm update
    hyprpm list 2>/dev/null | grep -qi hyprglass ||
        hyprpm add https://github.com/hyprnux/hyprglass
    hyprpm enable hyprglass
    hyprpm reload -n >/dev/null 2>&1 || true
    success "hyprglass plugin installed"
}
glass_uninstall() {
    hyprpm disable hyprglass
    hyprpm remove https://github.com/hyprnux/hyprglass
    success "hyprglass plugin removed"
}
glass() {
    local choice
    read -rp "hyprglass: (1) Install/Update (2) Uninstall [1]: " choice
    case "${choice:-1}" in
        1) glass_install ;;
        2) glass_uninstall ;;
        *) error "Invalid option."; return 1 ;;
    esac
}
setup_bluetooth() {
    section "Bluetooth"
    yay -S --needed blueman bluez
    sudo systemctl enable --now bluetooth
    success "Bluetooth enabled."
}

setup_pipewire() {
    section "PipeWire & Audio"
    yay -S --needed pipewire pipewire-pulse pipewire-alsa pipewire-jack \
        pavucontrol pulsemixer gnome-network-displays gst-plugins-bad
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    success "PipeWire configured."
}

optional_packages() {
    local choice
    read -rp "Install optional packages? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        yay -S --needed "${OPTIONAL_PACKAGES[@]}" ||
            warn "Some optional packages failed."
    fi
}

optional_reboot() {
    local choice
    read -rp "Reboot now? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        info "Rebooting..."
        sync
        sudo systemctl reboot || sudo reboot || { error "Reboot failed; reboot manually."; return 1; }
    fi
    return 0
}

finish() {
    success "Installation complete!"
    notify-send "Dotfiles Installed" \
        "Open Terminal with MOD+Q\nHello $USER, thanks for using my dotfiles!\n-EF" \
        2>/dev/null || true
}

# installation modes

auto_install() {
    section "Automatic Installation"
    
    local choice 
    read -rp "Update mirrorlist? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_mirrors

    info "Installing core packages..."
    yay -S --needed "${CORE_PACKAGES[@]}"
    sudo systemctl enable --now avahi-daemon

    setup_bluetooth
    setup_pipewire
    apply_dotfiles
    run_wallpaper_selector

    read -rp "Set up autologin? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        autologin || warn "Autologin setup failed."
    fi
    glass
    optional_packages
    finish
    optional_reboot
}

manual_install() {
    section "Manual Installation"

    local choice pkg
    read -rp "Update mirrorlist? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_mirrors

    section "Package Selection"
    for pkg in "${CORE_PACKAGES[@]}"; do
        read -rp "Install $pkg? (Y/n): " choice
        if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
            yay -S --needed "$pkg" || warn "Failed to install $pkg"
        fi
    done

    read -rp "Install Bluetooth support? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_bluetooth

    read -rp "Configure PipeWire? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_pipewire

    apply_dotfiles
    run_wallpaper_selector

    read -rp "Set up autologin? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        autologin || warn "Autologin setup failed."
    fi
    glass
    optional_packages
    finish
    optional_reboot
}

# entry point

main() {
    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
  ____        _    __ _ _
 |  _ \  ___ | |_ / _(_) | ___  ___
 | | | |/ _ \| __| |_| | |/ _ \/ __|
 | |_| | (_) | |_|  _| | |  __/\__ \
 |____/ \___/ \__|_| |_|_|\___||___/
EOF
    echo -e "${RESET}"

    [[ -d "$DOTFILES_DIR" ]] ||
        { error "Dotfiles directory not found: $DOTFILES_DIR"; return 1; }
    command -v yay >/dev/null ||
        { error "Install yay first."; return 1; }

    section "Welcome"
    select_hyprland_style

    local install_choice backup_choice
    read -rp "Installation mode: (A)utomatic or (M)anual? [A]: " install_choice
    install_choice="${install_choice:-a}"

    read -rp "Back up current dotfiles? (Y/n): " backup_choice
    if [[ "${backup_choice:-y}" =~ ^[Yy]$ ]]; then
        backup_config
        backup_bashrc
    fi

    case "${install_choice,,}" in
        a) auto_install ;;
        m) manual_install ;;
        *) error "Unknown option '$install_choice'."; return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
