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

# === System Setup Functions ===
setup_repos() {
  info "Updating system..."
  sudo dnf upgrade --refresh -y
  FEDORA_VERSION=$(rpm -E %fedora)
  info "Enabling RPM Fusion..."
  sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
  info "Setting up Flatpak..."
  sudo dnf install -y flatpak gnome-software-plugin-flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_core_utilities() {
  info "Installing core utilities..."
  sudo dnf install -y zsh git curl wget jq unzip htop gnome-tweaks gnome-extensions-app chrome-gnome-shell
}

install_security() {
  info "Installing UFW and ProtonVPN..."
  sudo dnf install -y ufw
  sudo systemctl enable ufw
  sudo ufw --force enable
  FEDORA_VERSION=$(rpm -E %fedora)
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
}

install_multimedia() {
  info "Installing multimedia codecs..."
  sudo dnf groupupdate -y multimedia --setop='install_weak_deps=False' --exclude=gstreamer1-plugins-bad-free-devel
  sudo dnf install -y gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame* ffmpeg --allowerasing
}

install_power() {
  info "Installing power management tools..."
  sudo dnf install -y tlp powertop
  sudo systemctl enable tlp
}

install_gaming() {
  info "Installing gaming tools..."
  sudo dnf install -y steam gamemode libva libva-utils libvdpau
  flatpak install -y --user flathub com.heroicgameslauncher.hgl net.davidotek.pupgui2 net.lutris.Lutris com.usebottles.bottles
}

install_productivity() {
  info "Installing productivity tools..."
  flatpak install -y --user flathub \
    org.gnome.Boxes org.gnome.Calendar com.github.tchx84.Flatseal com.github.johnfactotum.Foliate \
    md.obsidian.Obsidian net.cozic.joplindesktop org.mozilla.Thunderbird
}

install_creative() {
  info "Installing creative/media tools..."
  flatpak install -y --user flathub \
    org.kde.okular org.kde.krita org.darktable.Darktable com.github.wnxemoark.MasterPDFEditor \
    io.neovim.nvim org.kde.ark
}

install_comm() {
  info "Installing communication apps..."
  flatpak install -y --user flathub \
    org.signal.Signal chat.simplex.Simplex com.spotify.Client dev.zed.Zed
}

install_zsh() {
  info "Setting up Oh My Zsh and Powerlevel10k..."
  if [[ $SHELL != *zsh ]]; then
    chsh -s "$(command -v zsh)"
  fi
  export RUNZSH=no
  [[ -d "$HOME/.oh-my-zsh" ]] || sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  if grep -q '^ZSH_THEME=' ~/.zshrc; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
  else
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
  fi
}

install_themes() {
  info "Installing GNOME themes..."
  local tmp_dir
  tmp_dir=$(mktemp -d)
  mkdir -p ~/.themes ~/.icons
  git clone --depth=1 https://github.com/vinceliuice/Qogir-theme.git "${tmp_dir}/Qogir-theme"
  "${tmp_dir}/Qogir-theme/install.sh" -d ~/.themes
  "${tmp_dir}/Qogir-theme/install.sh" -d ~/.icons -t default -c standard
  git clone --depth=1 https://github.com/vinceliuice/Qogir-icon-theme.git "${tmp_dir}/Qogir-icon-theme"
  "${tmp_dir}/Qogir-icon-theme/install.sh" -d ~/.icons
  git clone --depth=1 https://github.com/daniruiz/flat-remix-gnome.git "${tmp_dir}/flat-remix-gnome"
  cp -r "${tmp_dir}/flat-remix-gnome/Flat"* ~/.themes/
  # Install Phinger Cursors
  git clone --depth=1 https://github.com/phisch/phinger-cursors.git "${tmp_dir}/phinger-cursors"
  cp -r "${tmp_dir}/phinger-cursors/dist/Phinger-Light" ~/.icons/
  gsettings set org.gnome.desktop.interface gtk-theme "Qogir"
  gsettings set org.gnome.desktop.interface icon-theme "Qogir-icon-theme"
  gsettings set org.gnome.desktop.interface cursor-theme "Phinger-Light"
  gsettings set org.gnome.shell.extensions.user-theme name "Flat-Remix-GNOME-Dark"
  rm -rf "$tmp_dir"
}

install_extensions() {
  info "Installing GNOME extensions..."
  EXTENSIONS=(
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "caffeine@patapon.info"
    "openweather-extension@jenslody.de"
  )
  for UUID in "${EXTENSIONS[@]}"; do
    EXT_NAME="${UUID%%@*}"
    EXT_ID=$(curl -s "https://extensions.gnome.org/extension-query/?search=$EXT_NAME" | jq -r ".extensions[] | select(.uuid==\"$UUID\") | .pk" | head -n 1)
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
}

install_nvidia() {
  info "Installing NVIDIA drivers and monitoring tools..."
  FEDORA_VERSION=$(rpm -E %fedora)
  sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
  sudo dnf install -y xorg-x11-drv-nvidia-power xorg-x11-drv-nvidia-cuda-libs
  flatpak install -y --user flathub io.github.realmazharhussain.NvidiaGpuStatsTool
}

# === Main Routine ===
main() {
  parse_flags "$@"
  check_requirements
  check_root_and_network
  start_sudo_keepalive
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
  (( FLAGS[nvidia] ))       && install_nvidia
  info "Cleaning temporary files"
  rm -rf /tmp/{Qogir-*,flat-remix-*,protonvpn.*}
  echo -e "\n\033[1;32mSetup complete. Please reboot your system.\033[0m"
}

main "$@"

