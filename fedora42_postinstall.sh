#!/bin/bash
set -euo pipefail

# === Helper Functions ===
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# === Toggle Flags (all ON by default except NVIDIA) ===
declare -A FLAGS=(
  [security]=1
  [multimedia]=1
  [power]=1
  [gaming]=1
  [productivity]=1
  [creative]=1
  [comm]=1
  [zsh]=1
  [themes]=1
  [extensions]=1
  [nvidia]=0
)

parse_flags() {
  for arg in "$@"; do
    case "${arg}" in
      --no-*) flag="${arg#--no-}"; FLAGS["$flag"]=0 ;;
      --nvidia) FLAGS[nvidia]=1 ;;
      *) warn "Unknown flag: ${arg}" ;;
    esac
  done
}

# === Required Commands Check ===
REQUIRED_CMDS=(sudo dnf flatpak jq curl wget unzip git gsettings gnome-extensions)
check_requirements() {
  for cmd in "${REQUIRED_CMDS[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || err "Required command '$cmd' not found."
  done
}

# === Root and Network Checks ===
check_root_and_network() {
  if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root."
  fi
  if ! ping -c 1 1.1.1.1 &>/dev/null; then
    err "No network connectivity. Please check your connection."
  fi
}

# === Sudo Keep-Alive ===
keep_sudo_alive() { while true; do sudo -n true; sleep 60; done }
start_sudo_keepalive() { sudo -v; keep_sudo_alive & SUDO_PID=$!; trap "kill $SUDO_PID" EXIT; }

# === System Setup ===
setup_repos() {
  info "Updating system..."
  sudo dnf upgrade --refresh -y
  FEDORA_VERSION=$(rpm -E %fedora)
  info "Enabling RPM Fusion..."
  sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
  info "Setting up Flatpak..."
  sudo dnf install -y flatpak
  sudo dnf makecache -y >/dev/null
  if dnf list --available gnome-software-plugin-flatpak &>/dev/null; then
    sudo dnf install -y gnome-software-plugin-flatpak
  else
    warn "gnome-software-plugin-flatpak not found in Fedora $FEDORA_VERSION. Skipping."
  fi
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_powerlevel10k_fonts() {
  info "Installing MesloLGS Nerd Fonts for Powerlevel10k..."
  FONT_DIR="$HOME/.local/share/fonts"
  mkdir -p "$FONT_DIR"
  MESLO_FONTS=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
  )
  BASE_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/L/Regular/complete"
  for font in "${MESLO_FONTS[@]}"; do
    if [[ ! -f "$FONT_DIR/$font" ]]; then
      wget -q --show-progress -O "$FONT_DIR/$font" "$BASE_URL/${font// /%20}"
    else
      info "$font already exists, skipping."
    fi
  done
  fc-cache -fv "$FONT_DIR"
}

install_core_utilities() {
  info "Installing core utilities..."
  PKGS=(zsh git curl wget jq unzip htop gnome-tweaks gnome-extensions-app alacritty)
  for pkg in "${PKGS[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
      info "$pkg already installed, skipping."
    else
      sudo dnf install -y "$pkg"
    fi
  done
  if [[ "$SHELL" != *zsh ]]; then
    chsh -s $(which zsh)
  fi
  export RUNZSH=no
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  fi
  if grep -q '^ZSH_THEME=' ~/.zshrc; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME=\"powerlevel10k/powerlevel10k\"|' ~/.zshrc
  else
    echo 'ZSH_THEME=\"powerlevel10k/powerlevel10k\"' >> ~/.zshrc
  fi
  install_powerlevel10k_fonts
}

install_extensions() {
  info "Installing GNOME extensions..."
  EXTENSIONS=(
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "alphabetical-app-grid@stuarthayhurst"
    "fuzzy-app-search@noobsai.github.com"
    "removable-drive-menu@gnome-shell-extensions.gcampax.github.com"
    "world-clock-extension@gnome-shell-extensions.gcampax.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "weather-or-not@adel.gadllah@gmail.com"
    "apps-menu@gnome-shell-extensions.gcampax.github.com"
  )
  for UUID in "${EXTENSIONS[@]}"; do
    EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
    if [[ -d "$EXT_DIR" ]]; then
      info "Extension $UUID already installed, skipping."
      continue
    fi
    EXT_NAME="${UUID%%@*}"
    EXT_ID=$(curl -s "https://extensions.gnome.org/extension-query/?search=$EXT_NAME" | jq -r ".extensions[] | select(.uuid==\"$UUID\") | .pk" | head -n 1)
    if [[ -n "$EXT_ID" ]]; then
      SHELL_VER=$(gnome-shell --version | awk '{print $3}')
      VERSION=$(curl -s "https://extensions.gnome.org/extension-info/?pk=$EXT_ID" | jq -r --arg SHELL_VER "$SHELL_VER" '.shell_version_map[$SHELL_VER] // .shell_version_map | to_entries | last.value')
      ZIP_PATH="/tmp/$UUID.zip"
      wget -qO "$ZIP_PATH" "https://extensions.gnome.org/download-extension/$UUID.shell-extension.zip?version_tag=$VERSION"
      mkdir -p "$EXT_DIR"
      unzip -qo "$ZIP_PATH" -d "$EXT_DIR"
      gnome-extensions enable "$UUID" || true
      rm -f "$ZIP_PATH"
    else
      warn "Extension $UUID not found."
    fi
  done
}

install_flatpaks() {
  info "Installing Flatpak applications..."
  FLATPAKS=(
    com.github.tchx84.Flatseal
    com.heroicgameslauncher.hgl
    com.obsproject.Studio
    ch.protonmail.protonmail-bridge
    com.brave.Browser
    dev.zed.Zed
    chat.simplex.Simplex
    md.obsidian.Obsidian
    io.github.realmazharhussain.NvidiaGpuStatsTool
    io.github.mimbrero.WhatsAppDesktop
    io.neovim.nvim
    net.cozic.joplin_desktop
    net.davidotek.pupgui2
    net.lutris.Lutris
    org.gnome.Extensions
    org.gnome.DejaDup
    org.kde.krita
    org.signal.Signal
    org.telegram.desktop
    org.videolan.VLC
    org.gaias.sky
    us.zoom.Zoom
    re.sonny.Ear
    one.zen.zen
    io.github.fabrialberio.Simplexity
    com.github.Matoking.protonupqt
    dev.mixer.Mixer
    io.missioncenter.MissionCenter
  )
  for app in "${FLATPAKS[@]}"; do
    if flatpak list --app | grep -q "$app"; then
      info "Flatpak $app already installed, skipping."
    else
      flatpak install -y --user flathub "$app"
    fi
  done
}

install_themes() {
  info "Installing GNOME themes..."
  mkdir -p ~/.themes ~/.icons
  TMPDIR=$(mktemp -d)
  if [[ ! -d ~/.themes/Qogir ]]; then
    git clone --depth=1 https://github.com/vinceliuice/Qogir-theme.git "$TMPDIR/Qogir-theme"
    "$TMPDIR/Qogir-theme/install.sh" -d ~/.themes -t all
    "$TMPDIR/Qogir-theme/install.sh" -d ~/.icons -t default -c standard
  fi
  if [[ ! -d ~/.icons/Qogir ]]; then
    git clone --depth=1 https://github.com/vinceliuice/Qogir-icon-theme.git "$TMPDIR/Qogir-icon-theme"
    "$TMPDIR/Qogir-icon-theme/install.sh" -d ~/.icons
  fi
  if [[ ! -d ~/.themes/Flat-Remix-GNOME-Darkest ]]; then
    git clone --depth=1 https://github.com/daniruiz/flat-remix-gnome.git "$TMPDIR/flat-remix-gnome"
    cp -r "$TMPDIR/flat-remix-gnome/Flat-Remix-GNOME-Darkest" ~/.themes/
  fi
  gsettings set org.gnome.desktop.interface gtk-theme "Qogir"
  gsettings set org.gnome.desktop.interface icon-theme "Qogir"
  gsettings set org.gnome.desktop.interface cursor-theme "Qogir"
  gsettings set org.gnome.shell.extensions.user-theme name "Qogir"
  rm -rf "$TMPDIR"
}

main() {
  parse_flags "$@"
  check_requirements
  check_root_and_network
  start_sudo_keepalive
  setup_repos
  install_core_utilities
  (( FLAGS[extensions] )) && install_extensions
  install_flatpaks
  (( FLAGS[themes] )) && install_themes
  echo -e "\n\033[1;32mSetup complete. Please reboot your system.\033[0m"
}

main "$@"

