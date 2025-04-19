#!/bin/bash

set -euo pipefail

# === Helper Functions ===
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# === Flags (all ON by default) ===
INSTALL_SECURITY=true
INSTALL_MULTIMEDIA=true
INSTALL_POWER=true
INSTALL_GAMING=true
INSTALL_PRODUCTIVITY=true
INSTALL_CREATIVE=true
INSTALL_COMM=true
INSTALL_ZSH=true
INSTALL_THEMES=true
INSTALL_EXTENSIONS=true

for arg in "$@"; do
  case $arg in
    --no-security) INSTALL_SECURITY=false ;;
    --no-multimedia) INSTALL_MULTIMEDIA=false ;;
    --no-power) INSTALL_POWER=false ;;
    --no-gaming) INSTALL_GAMING=false ;;
    --no-productivity) INSTALL_PRODUCTIVITY=false ;;
    --no-creative) INSTALL_CREATIVE=false ;;
    --no-comm) INSTALL_COMM=false ;;
    --no-zsh) INSTALL_ZSH=false ;;
    --no-theme|--no-themes) INSTALL_THEMES=false ;;
    --no-extensions) INSTALL_EXTENSIONS=false ;;
  esac
done

# === Required Commands Check ===
REQUIRED_CMDS=(sudo dnf flatpak jq curl wget unzip git gsettings gnome-extensions)
for cmd in "${REQUIRED_CMDS[@]}"; do
    command -v "$cmd" &>/dev/null || { err "Required command '$cmd' not found."; exit 1; }
done

# === Root and Network Checks ===
if [[ $EUID -eq 0 ]]; then err "Do not run this script as root."; exit 1; fi
ping -c 1 1.1.1.1 &>/dev/null || { err "No network connectivity. Please check your connection."; exit 1; }

# === Keep Sudo Alive ===
info "Authenticating sudo..."
sudo -v
(while true; do sudo -n true; sleep 60; done) & SUDO_PID=$!
trap 'kill "$SUDO_PID"' EXIT

# === System Update ===
info "Updating system..."
sudo dnf upgrade --refresh -y

# === RPM Fusion & Flatpak ===
FEDORA_VERSION=$(rpm -E %fedora)
info "Enabling RPM Fusion..."
sudo dnf install -y \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

info "Setting up Flatpak..."
sudo dnf install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# === Core Utilities ===
info "Installing core utilities..."
sudo dnf install -y zsh git curl wget jq unzip htop gnome-tweaks gnome-extensions-app chrome-gnome-shell

# === Privacy & Security ===
if $INSTALL_SECURITY; then
  info "Installing UFW and ProtonVPN..."
  sudo dnf install -y ufw
  sudo systemctl enable ufw
  sudo ufw --force enable

  TMP_RPM="/tmp/protonvpn.rpm"
  wget -qO "$TMP_RPM" "https://repo.protonvpn.com/fedora-${FEDORA_VERSION}-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.3-1.noarch.rpm"
  sudo dnf install -y "$TMP_RPM"
  sudo dnf install -y proton-vpn-gnome-desktop
  rm -f "$TMP_RPM"

  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/protonvpn.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=protonvpn-gui
Hidden=false
X-GNOME-Autostart-enabled=true
Name=ProtonVPN
EOF
fi

# === Multimedia Codecs ===
if $INSTALL_MULTIMEDIA; then
  info "Installing multimedia codecs..."
  sudo dnf groupupdate -y multimedia --setop='install_weak_deps=False' --exclude=gstreamer1-plugins-bad-free-devel
  sudo dnf install -y gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame* ffmpeg --allowerasing
fi

# === Power Management ===
if $INSTALL_POWER; then
  info "Installing power management tools..."
  sudo dnf install -y tlp powertop
  sudo systemctl enable tlp
fi

# === Gaming Tools ===
if $INSTALL_GAMING; then
  info "Installing gaming tools..."
  sudo dnf install -y steam gamemode libva libva-utils libvdpau
  flatpak install -y --user flathub \
    com.heroicgameslauncher.hgl \
    net.davidotek.pupgui2 \
    net.lutris.Lutris \
    com.usebottles.bottles
fi

# === Productivity ===
if $INSTALL_PRODUCTIVITY; then
  info "Installing productivity tools..."
  flatpak install -y --user flathub \
    org.gnome.Boxes \
    org.gnome.Calendar \
    com.github.tchx84.Flatseal \
    com.github.johnfactotum.Foliate \
    md.obsidian.Obsidian \
    net.cozic.joplin_desktop \
    org.mozilla.Thunderbird
fi

# === Creative Tools ===
if $INSTALL_CREATIVE; then
  info "Installing creative/media tools..."
  flatpak install -y --user flathub \
    org.kde.okular \
    org.kde.krita \
    org.darktable.Darktable \
    com.github.wnxemoark.MasterPDFEditor \
    io.neovim.nvim \
    org.kde.ark
fi

# === Communication Apps ===
if $INSTALL_COMM; then
  info "Installing communication apps..."
  flatpak install -y --user flathub \
    org.signal.Signal \
    chat.simplex.Simplex \
    com.spotify.Client \
    dev.zed.Zed
fi

# === Oh My Zsh and Powerlevel10k ===
if $INSTALL_ZSH; then
  info "Setting up Oh My Zsh and Powerlevel10k..."
  [[ $SHELL != *zsh ]] && chsh -s "$(command -v zsh)"
  export RUNZSH=no
  [[ -d "$HOME/.oh-my-zsh" ]] || sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  grep -q '^ZSH_THEME=' ~/.zshrc && \
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME=\"powerlevel10k/powerlevel10k\"|' ~/.zshrc || \
    echo 'ZSH_THEME=\"powerlevel10k/powerlevel10k\"' >> ~/.zshrc
fi

# === GNOME Themes ===
if $INSTALL_THEMES; then
  info "Installing GNOME themes..."
  mkdir -p ~/.themes ~/.icons
  git clone --depth=1 https://github.com/vinceliuice/Qogir-theme.git /tmp/Qogir-theme
  /tmp/Qogir-theme/install.sh -d ~/.themes
  /tmp/Qogir-theme/install.sh -d ~/.icons -t default -c standard
  git clone --depth=1 https://github.com/vinceliuice/Qogir-icon-theme.git /tmp/Qogir-icon-theme
  /tmp/Qogir-icon-theme/install.sh -d ~/.icons
  git clone --depth=1 https://github.com/daniruiz/flat-remix-gnome.git /tmp/flat-remix-gnome
  cp -r /tmp/flat-remix-gnome/Flat* ~/.themes/
  gsettings set org.gnome.desktop.interface gtk-theme "Qogir"
  gsettings set org.gnome.desktop.interface icon-theme "Qogir"
  gsettings set org.gnome.desktop.interface cursor-theme "Qogir"
  gsettings set org.gnome.shell.extensions.user-theme name "Flat-Remix-GNOME-Dark"
fi

# === GNOME Extensions ===
if $INSTALL_EXTENSIONS; then
  info "Installing GNOME extensions..."
  EXTENSIONS=(
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "caffeine@patapon.info"
    "openweather-extension@jenslody.de"
  )
  for UUID in "${EXTENSIONS[@]}"; do
    EXT_NAME="${UUID%%@*}"
    EXT_ID=$(curl -s "https://extensions.gnome.org/extension-query/?search=$EXT_NAME" | jq -r ".extensions[] | select(.uuid==\\\"$UUID\\\") | .pk" | head -n 1)
    if [[ -n "$EXT_ID" ]]; then
      SHELL_VER=$(gnome-shell --version | awk '{print $3}')
      VERSION=$(curl -s "https://extensions.gnome.org/extension-info/?pk=$EXT_ID" | jq -r --arg SHELL_VER "$SHELL_VER" '.shell_version_map[$SHELL_VER] // .shell_version_map | to_entries | last.value')
      ZIP_PATH="/tmp/$UUID.zip"
      wget -qO "$ZIP_PATH" "https://extensions.gnome.org/download-extension/$UUID.shell-extension.zip?version_tag=$VERSION"
      EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
      mkdir -p "$EXT_DIR"
      unzip -qo "$ZIP_PATH" -d "$EXT_DIR"
      gnome-extensions enable "$UUID" || true
      rm -f "$ZIP_PATH"
    else
      warn "Extension $UUID not found."
    fi
  done
fi

# === Cleanup ===
rm -rf /tmp/Qogir-theme /tmp/Qogir-icon-theme /tmp/flat-remix-gnome

# === Completion ===
info "All configurations and installations completed!"
echo -e "\n\033[1;32mPlease reboot your system to apply all changes.\033[0m"
