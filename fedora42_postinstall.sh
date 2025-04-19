#!/bin/bash
set -euo pipefail

# ========================
# Configuration Functions
# ========================
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# ========================
# What This Script Includes
# ========================
# - Associative array for toggle flags (all ON by default)
# - Modular installation functions
# - Core utilities, ProtonVPN, multimedia, gaming, GNOME themes, extensions
# - Zsh + Powerlevel10k + Flatpak apps
# - GNOME tweaks and configuration

# ==================
# Installation Flags
# ==================
declare -A FLAGS=(
    [security]=1     [multimedia]=1  [power]=1
    [gaming]=1       [productivity]=1 [creative]=1
    [comm]=1         [zsh]=1         [themes]=1
    [extensions]=1
)

parse_flags() {
    for arg in "$@"; do
        case "${arg}" in
            --no-*) flag="${arg#--no-}"; FLAGS["${flag%%s}"]=0 ;;
            *) warn "Unknown flag: ${arg}" ;;
        esac
    done
}

# ================
# System Checks
# ================
check_requirements() {
    local -a required_cmds=(sudo dnf flatpak jq curl wget unzip git gsettings gnome-extensions)
    for cmd in "${required_cmds[@]}"; do
        command -v "${cmd}" >/dev/null 2>&1 || err "Missing required command: ${cmd}"
    done

    [[ ${EUID} -eq 0 ]] && err "Do not run as root"
    ping -c1 1.1.1.1 >/dev/null 2>&1 || err "No network connectivity"
}

# ================
# Sudo Management
# ================
keep_sudo_alive() {
    info "Initializing sudo session"
    sudo -v
    ( while true; do sudo -n true; sleep 60; done ) &
    SUDO_PID=$!
    trap 'kill ${SUDO_PID} 2>/dev/null' EXIT
}

kill_sudo() {
    info "Ending sudo session"
    kill ${SUDO_PID} 2>/dev/null
    trap - EXIT
}

# ===================
# Package Management
# ===================
setup_repos() {
    info "Configuring system repositories"
    local fedora_ver=$(rpm -E %fedora)

    SUDO_REQUIRED=true
    (( ${FLAGS[security]} || ${FLAGS[multimedia]} )) && keep_sudo_alive

    sudo dnf upgrade --refresh -y
    sudo dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"

    command -v flatpak >/dev/null 2>&1 || sudo dnf install -y flatpak gnome-software-plugin-flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    [[ $SUDO_REQUIRED = true ]] && kill_sudo
}

install_core_utilities() {
    info "Installing core utilities"
    SUDO_REQUIRED=true
    keep_sudo_alive
    sudo dnf install -y zsh git curl wget jq unzip htop gnome-tweaks gnome-extensions-app chrome-gnome-shell
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
}

install_security() {
    info "Installing UFW and ProtonVPN"
    local tmp_rpm=$(mktemp)
    SUDO_REQUIRED=true
    keep_sudo_alive
    wget -qO "${tmp_rpm}" "https://repo.protonvpn.com/fedora-$(rpm -E %fedora)-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.3-1.noarch.rpm"
    sudo dnf install -y ufw "${tmp_rpm}" proton-vpn-gnome-desktop
    rm -f "${tmp_rpm}"

    sudo systemctl enable --now ufw
    sudo ufw --force enable

    mkdir -p "${HOME}/.config/autostart"
    cat > "${HOME}/.config/autostart/protonvpn.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=protonvpn-gui
Hidden=false
X-GNOME-Autostart-enabled=true
Name=ProtonVPN
EOF
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
}

install_multimedia() {
    info "Installing multimedia codecs"
    SUDO_REQUIRED=true
    keep_sudo_alive
    sudo dnf groupupdate -y multimedia --setop='install_weak_deps=False' --exclude=gstreamer1-plugins-bad-free-devel
    sudo dnf install -y gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame* ffmpeg --allowerasing
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
}

install_power() {
    info "Installing power management tools"
    SUDO_REQUIRED=true
    keep_sudo_alive
    sudo dnf install -y tlp powertop
    sudo systemctl enable tlp
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
}

install_gaming() {
    info "Installing gaming tools"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    SUDO_REQUIRED=true
    keep_sudo_alive
    sudo dnf install -y steam gamemode libva libva-utils libvdpau
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
    flatpak install -y --user flathub \
        com.heroicgameslauncher.hgl \
        net.davidotek.pupgui2 \
        net.lutris.Lutris \
        com.usebottles.bottles
}

install_productivity() {
    info "Installing productivity tools"
    flatpak install -y --user flathub \
        org.gnome.Boxes \
        org.gnome.Calendar \
        com.github.tchx84.Flatseal \
        com.github.johnfactotum.Foliate \
        md.obsidian.Obsidian \
        net.cozic.joplin_desktop \
        org.mozilla.Thunderbird
}

install_creative() {
    info "Installing creative/media apps"
    flatpak install -y --user flathub \
        org.kde.okular \
        org.kde.krita \
        org.darktable.Darktable \
        com.github.wnxemoark.MasterPDFEditor \
        io.neovim.nvim \
        org.kde.ark
}

install_comm() {
    info "Installing communication apps"
    flatpak install -y --user flathub \
        org.signal.Signal \
        chat.simplex.Simplex \
        com.spotify.Client \
        dev.zed.Zed
}

install_zsh() {
    info "Setting up Oh My Zsh and Powerlevel10k"
    if [[ $SHELL != *zsh ]]; then
        SUDO_REQUIRED=true
        keep_sudo_alive
        sudo chsh -s "$(command -v zsh)"
        [[ $SUDO_REQUIRED = true ]] && kill_sudo
    fi

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        export RUNZSH=no
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
        grep -q '^ZSH_THEME=' ~/.zshrc && \
            sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc || \
            echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
    fi
}

install_themes() {
    info "Installing GNOME themes"
    local tmp_dir=$(mktemp -d)
    SUDO_REQUIRED=true
    keep_sudo_alive

    mkdir -p ~/.themes ~/.icons

    git clone --depth=1 https://github.com/vinceliuice/Qogir-theme.git "${tmp_dir}/Qogir-theme"
    "${tmp_dir}/Qogir-theme/install.sh" -d ~/.themes
    "${tmp_dir}/Qogir-theme/install.sh" -d ~/.icons -t default -c standard

    git clone --depth=1 https://github.com/vinceliuice/Qogir-icon-theme.git "${tmp_dir}/Qogir-icon-theme"
    "${tmp_dir}/Qogir-icon-theme/install.sh" -d ~/.icons

    git clone --depth=1 https://github.com/daniruiz/flat-remix-gnome.git "${tmp_dir}/flat-remix-gnome"
    cp -r "${tmp_dir}/flat-remix-gnome/Flat*" ~/.themes/

    gsettings set org.gnome.desktop.interface gtk-theme "Qogir"
    gsettings set org.gnome.desktop.interface icon-theme "Qogir-icon-theme"
    gsettings set org.gnome.desktop.interface cursor-theme "Qogir"
    gsettings set org.gnome.shell.extensions.user-theme name "Flat-Remix-GNOME-Dark"
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
    rm -rf "${tmp_dir}"
}

install_extensions() {
    info "Installing GNOME extensions"
    local extensions=(
        "blur-my-shell@aunetx"
        "dash-to-dock@micxgx.gmail.com"
        "caffeine@patapon.info"
        "openweather-extension@jenslody.de"
    )
    SUDO_REQUIRED=true
    keep_sudo_alive
    for uuid in "${extensions[@]}"; do
        ext_name="${uuid%%@*}"
        ext_id=$(curl -s "https://extensions.gnome.org/extension-query/?search=$ext_name" | jq -r ".extensions[] | select(.uuid==\"$uuid\") | .pk" | head -n1)
        if [[ -n "$ext_id" ]]; then
            shell_ver=$(gnome-shell --version | awk '{print $3}')
            version=$(curl -s "https://extensions.gnome.org/extension-info/?pk=$ext_id" | jq -r --arg shell_ver "$shell_ver" '.shell_version_map[$shell_ver] // .shell_version_map | to_entries | last.value')
            zip_path="/tmp/$uuid.zip"
            wget -qO "$zip_path" "https://extensions.gnome.org/download-extension/$uuid.shell-extension.zip?version_tag=$version"
            ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
            mkdir -p "$ext_dir"
            unzip -qo "$zip_path" -d "$ext_dir"
            gnome-extensions enable "$uuid" || true
            rm -f "$zip_path"
        else
            warn "Extension $uuid not found"
        fi
    done
    [[ $SUDO_REQUIRED = true ]] && kill_sudo
}

main() {
    parse_flags "$@"
    check_requirements

    setup_repos
    install_core_utilities

    (( FLAGS[security] ))     && install_security
    (( FLAGS[multimedia] ))   && install_multimedia
    (( FLAGS[power] ))        && install_power
    (( FLAGS[gaming] ))       && install_gaming
    (( FLAGS[productivity] )) && install_productivity
    (( FLAGS[creative] ))     && install_creative
    (( FLAGS[comm] ))         && install_comm
    (( FLAGS[zsh] ))          && install_zsh
    (( FLAGS[themes] ))       && install_themes
    (( FLAGS[extensions] ))   && install_extensions

    info "Cleaning temporary files"
    rm -rf /tmp/{Qogir-*,flat-remix-*,protonvpn.*}

    echo -e "\n\033[1;32mSetup complete. Please reboot your system.\033[0m"
}

main "$@"
