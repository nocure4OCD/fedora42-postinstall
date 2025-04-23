#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Fedora 42 Post-Install Script by Joshua Warren
# Hybrid system: productivity, media, gaming, privacy, and aesthetics
# Designed for GitHub-readiness and personal deployment

# ========================
#    CONFIGURATION
# ========================
declare -A MODULES=(
    [SYSTEM]=1
    [FLATPAK]=1
    [MULTIMEDIA]=1
    [GAMING]=1
    [PRIVACY]=1
    [CUSTOMIZATION]=1
    [PRODUCTIVITY]=1
    [SECURITY]=1
    [THEMES]=1
    [EXTENSIONS]=1
)

# ========================
#    SYSTEM INFORMATION
# ========================
FEDORA_VERSION=$(rpm -E %fedora)
GNOME_SHELL_VERSION=$(gnome-shell --version | awk '{print $3}')
TMP_DIR=$(mktemp -d -t fedora-postinstall-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# ========================
#    HELPER FUNCTIONS
# ========================
log() {
    local level=$1; shift
    declare -A colors=(
        [info]='\033[1;34m' [warn]='\033[1;33m'
        [error]='\033[1;31m' [success]='\033[1;32m'
    )
    echo -e "${colors[$level]}➤ $*\033[0m"
}

validate_checksum() {
    local file=$1 expected=$2
    actual=$(sha256sum "$file" | awk '{print $1}')
    [[ "$actual" == "$expected" ]] || return 1
}

secure_download() {
    local url=$1 dest=$2 checksum=$3
    for i in {1..3}; do
        if curl -#Lf -o "$dest" "$url"; then
            validate_checksum "$dest" "$checksum" && return 0
            log warn "Checksum mismatch, retrying..."
            rm -f "$dest"
        fi
        sleep $((i * 2))
    done
    log error "Failed to download ${url##*/}"
    exit 1
}

# ========================
#    SYSTEM PREPARATION 
# ========================
configure_repos() {
    [[ ${MODULES[SYSTEM]} -eq 1 ]] || return

    log info "Enabling RPM Fusion..."
    
    # Static checksums for Fedora 42
    free_rpm="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
    free_sha256="REPLACE_WITH_ACTUAL_FREE_CHECKSUM"
    
    nonfree_rpm="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
    nonfree_sha256="REPLACE_WITH_ACTUAL_NONFREE_CHECKSUM"

    secure_download "$free_rpm" "${TMP_DIR}/rpmfusion-free.rpm" "$free_sha256"
    secure_download "$nonfree_rpm" "${TMP_DIR}/rpmfusion-nonfree.rpm" "$nonfree_sha256"
    
    sudo dnf install -y "$TMP_DIR"/rpmfusion-*.rpm
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
    sudo dnf groupupdate core -y
}


install_base_packages() {
    [[ ${MODULES[SYSTEM]} -eq 1 ]] || return

    log info "Installing system packages..."
    local packages=(
        git curl wget unzip nano p7zip p7zip-plugins
        util-linux-user gnome-tweaks dconf-editor
        libappindicator-gtk3 gnome-shell-extension-pop-shell
        zsh zsh-autosuggestions zsh-syntax-highlighting
    )
    sudo dnf install -y "${packages[@]}"
}

# ========================
#    SECURITY SETTINGS
# ========================
configure_security() {
    [[ ${MODULES[SECURITY]} -eq 1 ]] || return

    log info "Configuring security..."
    local packages=(ufw fail2ban clamav rkhunter)
    sudo dnf install -y "${packages[@]}"
    
    sudo systemctl enable --now ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw --force enable
    
    sudo systemctl enable --now fail2ban
    sudo freshclam
}

# ========================
#    FLATPAK SETUP
# ========================
configure_flatpak() {
    [[ ${MODULES[FLATPAK]} -eq 1 ]] || return

    log info "Configuring Flatpak..."
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak update -y
}

# ========================
#    MEDIA & CODECS
# ========================
install_media() {
    [[ ${MODULES[MULTIMEDIA]} -eq 1 ]] || return

    log info "Installing media codecs..."
    sudo dnf groupupdate multimedia --setop="install_weak_deps=False" -y
    sudo dnf groupupdate sound-and-video -y
    sudo dnf install -y \
        gstreamer1-plugins-{bad-,good-,base} \
        gstreamer1-plugin-openh264 \
        ffmpeg-libs lame
}

# ========================
#    GAMING SETUP
# ========================
install_gaming() {
    [[ ${MODULES[GAMING]} -eq 1 ]] || return

    log info "Installing gaming components..."
    sudo dnf install -y steam lutris wine winetricks
    sudo dnf install -y @multilib
    
    local flatpaks=(
        com.heroicgameslauncher.hgl
        net.lutris.Lutris
        net.davidotek.pupgui2
        com.usebottles.bottles
    )
    flatpak install -y --user "${flatpaks[@]}"
}

# ========================
#    PRIVACY TOOLS
# ========================
install_privacy() {
    [[ ${MODULES[PRIVACY]} -eq 1 ]] || return

    log info "Installing privacy tools..."
    local flatpaks=(
        org.signal.Signal
        chat.simplex.Simplex
        ch.protonmail.protonmail-bridge
    )
    flatpak install -y --user "${flatpaks[@]}"
}

# ========================
#    THEMES & FONTS
# ========================
install_themes() {
    [[ ${MODULES[THEMES]} -eq 1 ]] || return

    log info "Installing themes and fonts..."
    # Qogir Theme
    sudo dnf copr enable user/qogir-theme -y
    sudo dnf install -y qogir-gtk-theme qogir-icon-theme qogir-cursor-theme
    
    # Meslo Nerd Fonts
    sudo mkdir -p /usr/local/share/fonts
    local fonts=(
        "MesloLGS%20NF%20Regular.ttf"
        "MesloLGS%20NF%20Bold.ttf"
        "MesloLGS%20NF%20Italic.ttf"
        "MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    for font in "${fonts[@]}"; do
        sudo curl -#L "https://github.com/romkatv/powerlevel10k-media/raw/master/$font" \
            -o "/usr/local/share/fonts/${font//%20/ }"
    done
    sudo fc-cache -fv
    
    # Apply GNOME Settings
    gsettings set org.gnome.desktop.interface gtk-theme 'Qogir'
    gsettings set org.gnome.desktop.interface icon-theme 'Qogir'
    gsettings set org.gnome.desktop.interface cursor-theme 'Qogir'
    gsettings set org.gnome.shell.extensions.user-theme name 'Qogir'
    gsettings set org.gnome.desktop.interface clock-show-date true
    gsettings set org.gnome.desktop.calendar show-weekdate true
    gsettings set org.gnome.desktop.input-sources show-all-sources true
    gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
    gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
}

# ========================
#    GNOME EXTENSIONS
# ========================
install_extensions() {
    [[ ${MODULES[EXTENSIONS]} -eq 1 ]] || return

    log info "Installing GNOME extensions..."
    declare -A extensions=(
        [blur-my-shell@aunetx]=""
        [dash-to-dock@micxgx.gmail.com]=""
        [alphabetical-app-grid@stuarthayhurst]=""
        [fuzzy-app-search@leavitals]=""
        [removable-drive-menu@gnome-shell-extensions.gcampax.github.com]=""
        [user-theme@gnome-shell-extensions.gcampax.github.com]=""
        [weather-or-not@Ochosi]=""
        [apps-menu@gnome-shell-extensions.gcampax.github.com]=""
    )
    
    for uuid in "${!extensions[@]}"; do
        version=$(curl -s "https://extensions.gnome.org/extension-query/?search=$uuid" |
            jq -r --arg uuid "$uuid" --arg ver "$GNOME_SHELL_VERSION" \
            '.extensions[] | select(.uuid == $uuid) | .shell_version_map[$ver] // .shell_version_map | to_entries[-1].value')
        
        log info "Installing $uuid v$version..."
        curl -#L "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=$version" \
            -o "$TMP_DIR/${uuid}.zip"
        
        gnome-extensions install "$TMP_DIR/${uuid}.zip"
        gnome-extensions enable "$uuid"
    done
}

# ========================
#    PRODUCTIVITY TOOLS
# ========================
install_productivity() {
    [[ ${MODULES[PRODUCTIVITY]} -eq 1 ]] || return

    log info "Installing productivity apps..."
    local flatpaks=(
        md.obsidian.Obsidian
        org.mozilla.Thunderbird
        net.cozic.joplin_desktop
        dev.zed.Zed
        io.missioncenter.MissionCenter
        org.kde.ark
        io.neovim.nvim
        com.spotify.Client
        com.visualstudio.code
    )
    flatpak install -y --user "${flatpaks[@]}"
}

# ========================
#    ZSH CONFIGURATION
# ========================
configure_zsh() {
    [[ ${MODULES[CUSTOMIZATION]} -eq 1 ]] || return

    log info "Configuring ZSH..."
    sudo usermod -s "$(which zsh)" "$USER"
    
    # Oh My Zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Powerlevel10k
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    
    # Plugins
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-autosuggestions.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    
    # Configuration
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    cat >> ~/.zshrc <<'EOF'
export PATH=$HOME/.local/bin:$PATH
export EDITOR=nvim
source $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

    # Default p10k config
    [[ -f ~/.p10k.zsh ]] || cat > ~/.p10k.zsh <<'EOF'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs newline prompt_char)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status time)
POWERLEVEL9K_MODE=nerdfont-complete
EOF
}

# ========================
#    MAIN EXECUTION
# ========================
main() {
    # Pre-flight checks
    [[ $EUID -eq 0 ]] && { log error "Do not run as root"; exit 1; }
    ping -c 1 1.1.1.1 >/dev/null || { log error "No network connection"; exit 1; }
    command -v jq >/dev/null || { log error "jq required"; exit 1; }

    # Keep sudo alive
    sudo -v
    while true; do sudo -n true; sleep 60; done 2>/dev/null &

    # Installation sequence
    configure_repos
    install_base_packages
    configure_security
    configure_flatpak
    install_media
    install_gaming
    install_privacy
    install_themes
    install_extensions
    install_productivity
    configure_zsh

    # Cleanup
    log info "Cleaning up..."
    sudo dnf autoremove -y
    sudo dnf clean all

    log success "Installation complete! Reboot to apply changes."
}

main "$@"

