#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Fedora 42 Post-Install Script by Joshua Warren
# Version 3.3 - Checksum issue resolved
# Preserves all themes, apps, customizations, and extensions

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

secure_download() {
    local url=$1 dest=$2
    for i in {1..3}; do
        if curl -#Lf -o "$dest" "$url"; then
            return 0
        else
            log warn "Download failed, retrying..."
            sleep $((i * 2))
        fi
    done
    log error "Failed to download ${url##*/}"
    exit 1
}

# ========================
#    RPM FUSION SETUP (FIXED)
# ========================
configurerepos() {
    [[ ${MODULES[SYSTEM]} -eq 1 ]] || return

    log info "Enabling RPM Fusion..."
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm
    
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
    sudo dnf groupupdate core -y
}

# ========================
#    PRESERVED FUNCTIONALITY
# ========================
installbasepackages() {
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

configuresecurity() {
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

configureflatpak() {
    [[ ${MODULES[FLATPAK]} -eq 1 ]] || return

    log info "Configuring Flatpak..."
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak update -y
}

installmedia() {
    [[ ${MODULES[MULTIMEDIA]} -eq 1 ]] || return

    log info "Installing media codecs..."
    sudo dnf groupupdate multimedia --setop=install_weak_deps=False -y
    sudo dnf groupupdate sound-and-video -y
    sudo dnf install -y gstreamer1-plugins-{bad-,good-,base} gstreamer1-plugin-openh264 ffmpeg-libs lame
}

installgaming() {
    [[ ${MODULES[GAMING]} -eq 1 ]] || return

    log info "Installing gaming components..."
    sudo dnf install -y steam lutris wine winetricks
    sudo dnf install -y multilib
    local flatpaks=(
        com.heroicgameslauncher.hgl
        net.lutris.Lutris
        net.davidotek.pupgui2
        com.usebottles.bottles
    )
    flatpak install -y --user "${flatpaks[@]}"
}

installprivacy() {
    [[ ${MODULES[PRIVACY]} -eq 1 ]] || return

    log info "Installing privacy tools..."
    local flatpaks=(
        org.signal.Signal
        chat.simplex.Simplex
        ch.protonmail.protonmail-bridge
    )
    flatpak install -y --user "${flatpaks[@]}"
}

installthemes() {
    [[ ${MODULES[THEMES]} -eq 1 ]] || return
    
    log info "Installing themes and fonts..."
    sudo dnf copr enable user/qogir-theme -y
    sudo dnf install -y qogir-gtk-theme qogir-icon-theme qogir-cursor-theme
    
    # Meslo Nerd Fonts
    sudo mkdir -p /usr/local/share/fonts
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )
    for font in "${fonts[@]}"; do
        sudo curl -L "https://github.com/romkatv/powerlevel10k-media/raw/master/${font}" \
             -o "/usr/local/share/fonts/${font}"
    done
    sudo fc-cache -fv

    # Apply GNOME settings
    gsettings set org.gnome.desktop.interface gtk-theme 'Qogir'
    gsettings set org.gnome.desktop.interface icon-theme 'Qogir'
    gsettings set org.gnome.desktop.interface cursor-theme 'Qogir'
    gsettings set org.gnome.shell.extensions.user-theme name 'Qogir'
}

installextensions() {
    [[ ${MODULES[EXTENSIONS]} -eq 1 ]] || return

    log info "Installing GNOME extensions..."
    declare -A extensions=(
        [blur-my-shell]="aunetx"
        [dash-to-dock]="micxgx.gmail.com"
        [alphabetical-app-grid]="stuarthayhurst"
        [fuzzy-app-search]="leavitals"
        [removable-drive-menu]="gnome-shell-extensions.gcampax.github.com"
        [user-theme]="gnome-shell-extensions.gcampax.github.com"
        [weather-or-not]="Ochosi"
        [apps-menu]="gnome-shell-extensions.gcampax.github.com"
    )
    for uuid in "${!extensions[@]}"; do
        version=$(curl -s "https://extensions.gnome.org/extension-query?search=${uuid}" | \
                  jq -r --arg uuid "${extensions[$uuid]}" --arg ver "$GNOME_SHELL_VERSION" \
                  '.extensions[] | select(.uuid == $uuid) | .shell_version_map[$ver]')
        log info "Installing ${uuid} v${version}..."
        secure_download "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version}" \
                        "${TMP_DIR}/${uuid}.zip"
        gnome-extensions install "${TMP_DIR}/${uuid}.zip"
        gnome-extensions enable "${uuid}"
    done
}

installproductivity() {
    [[ ${MODULES[PRODUCTIVITY]} -eq 1 ]] || return

    log info "Installing productivity apps..."
    local flatpaks=(
        md.obsidian.Obsidian
        org.mozilla.Thunderbird
        net.cozic.joplindesktop
        dev.zed.Zed
        io.missioncenter.MissionCenter
        org.kde.ark
        io.neovim.nvim
        com.spotify.Client
        com.visualstudio.code
    )
    flatpak install -y --user "${flatpaks[@]}"
}

configurezsh() {
    [[ ${MODULES[CUSTOMIZATION]} -eq 1 ]] || return

    log info "Configuring ZSH..."
    sudo usermod -s "$(which zsh)" "$USER"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    cat >> ~/.zshrc <<EOF
export PATH="\$HOME/.local/bin:\$PATH"
export EDITOR="nvim"
source \$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source \$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
}

main() {
    [[ $EUID -eq 0 ]] && { log error "Do not run as root"; exit 1; }
    ping -c 1 1.1.1.1 >/dev/null || { log error "No network connection"; exit 1; }
    command -v jq >/dev/null || { log error "jq required"; exit 1; }

    log info "Starting Fedora 42 post-install configuration..."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    configurerepos
    installbasepackages
    configuresecurity
    configureflatpak
    installmedia
    installgaming
    installprivacy
    installthemes
    installextensions
    installproductivity
    configurezsh

    log info "Cleaning up..."
    sudo dnf autoremove -y
    sudo dnf clean all
    log success "Installation complete! Reboot to apply changes."
}

main "$@"

