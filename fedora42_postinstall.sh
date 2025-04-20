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
  sudo dnf install -y flatpak
  if dnf list gnome-software-plugin-flatpak &>/dev/null; then
    sudo dnf install -y gnome-software-plugin-flatpak
  else
    warn "gnome-software-plugin-flatpak not found in Fedora $FEDORA_VERSION. Skipping."
  fi
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

# === ... (All other install_* functions go here, unchanged) ===
# (To keep things clean, they remain unchanged from your last posted script)

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

