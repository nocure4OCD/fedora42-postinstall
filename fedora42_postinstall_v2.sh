#!/usr/bin/env bash

# Fedora 42 Post-Install Script by Joshua Tyler Warren
# Hybrid system: productivity, media, gaming, privacy, and aesthetics
# Designed for GitHub-readiness and personal deployment

# ========================
#     CONFIGURATION
# ========================
ENABLE_SYSTEM=true
ENABLE_FLATPAKS=true
ENABLE_FFMPEG=true
ENABLE_MEDIA=true
ENABLE_GAMING=true
ENABLE_PRIVACY=true
ENABLE_CUSTOMIZATION=true
ENABLE_PRODUCTIVITY=true

# ========================
#     HELPER FUNCTIONS
# ========================
function info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
function warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
function error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# ========================
#     SYSTEM PREP
# ========================
if $ENABLE_SYSTEM; then
  info "Updating system and installing base packages..."
  sudo dnf upgrade --refresh -y
  sudo dnf install -y \
    git curl wget unzip nano p7zip p7zip-plugins \
    util-linux-user gnome-tweaks dconf-editor \
    libappindicator-gtk3 gnome-shell-extension-pop-shell

  info "Enabling RPM Fusion..."
  sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

  sudo dnf config-manager --set-enabled fedora-cisco-openh264
  sudo dnf groupupdate core -y
fi

# ========================
#     FLATPAK SETUP
# ========================
if $ENABLE_FLATPAKS; then
  info "Installing Flatpak & Flathub..."
  sudo dnf install -y flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak update -y
fi

# ========================
#     FFMPEG / CODECS
# ========================
if $ENABLE_FFMPEG; then
  info "Installing multimedia codecs and FFmpeg..."
  sudo dnf groupupdate multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
  sudo dnf groupupdate sound-and-video -y
  sudo dnf install -y ffmpeg-libs
fi

# ========================
#     MEDIA TOOLS
# ========================
if $ENABLE_MEDIA; then
  info "Installing media tools..."
  flatpak install -y flathub org.kde.krita
  flatpak install -y flathub org.kde.okular
  flatpak install -y flathub org.darktable.Darktable
  flatpak install -y flathub net.masterpdfeditor.MasterPDFEditor
fi

# ========================
#     GAMING
# ========================
if $ENABLE_GAMING; then
  info "Installing Steam, Lutris, and 32-bit support..."
  sudo dnf install -y steam
  sudo dnf install -y lutris
  sudo dnf install -y wine wine.i686

  # Enable 32-bit architecture
  sudo dnf install -y glibc.i686 libstdc++.i686
fi

# ========================
#     PRIVACY & COMMS
# ========================
if $ENABLE_PRIVACY; then
  info "Installing privacy and communication apps..."
  flatpak install -y flathub org.signal.Signal
  flatpak install -y flathub im.simplex.chat
fi

# ========================
#     CUSTOMIZATION
# ========================
if $ENABLE_CUSTOMIZATION; then
  info "Setting GNOME preferences and installing themes..."

  # GNOME Settings
  gsettings set org.gnome.desktop.interface gtk-theme 'Qogir'
  gsettings set org.gnome.desktop.interface icon-theme 'Qogir'
  gsettings set org.gnome.desktop.interface cursor-theme 'Qogir'
  gsettings set org.gnome.shell.extensions.user-theme name 'Qogir'
  gsettings set org.gnome.desktop.interface color-scheme 'default'
  gsettings set org.gnome.desktop.interface clock-show-date true
  gsettings set org.gnome.desktop.calendar show-weekdate true
  gsettings set org.gnome.desktop.input-sources show-all-sources true
  gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
  gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.desktop.screensaver lock-enabled false

  # ZSH & Powerlevel10k
  info "Installing ZSH and Oh-My-Zsh..."
  sudo dnf install -y zsh zsh-autosuggestions zsh-syntax-highlighting
  chsh -s /bin/zsh
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  info "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
  sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
  echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc
  echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc

  # Nerd Fonts: MesloLGS
  info "Installing MesloLGS Nerd Fonts..."
  mkdir -p ~/.local/share/fonts
  cd ~/.local/share/fonts
  curl -OL https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/L/Regular/MesloLGS%20NF%20Regular.ttf
  curl -OL https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/L/Bold/MesloLGS%20NF%20Bold.ttf
  curl -OL https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/L/Italic/MesloLGS%20NF%20Italic.ttf
  curl -OL https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/L/BoldItalic/MesloLGS%20NF%20Bold%20Italic.ttf
  fc-cache -fv
  cd ~

  # Qogir Theme & Icons (all variants)
  info "Installing Qogir theme (all variants)..."
  sudo dnf install -y qogir-gtk-theme qogir-icon-theme qogir-cursor-theme

  # GNOME Extensions
  info "Installing GNOME Extensions Manager and extensions..."
  sudo dnf install -y gnome-extensions-app gnome-shell-extension-user-theme

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

  for EXT in "${EXTENSIONS[@]}"; do
    gnome-extensions enable "$EXT" 2>/dev/null || \
    info "Extension $EXT will be active after reboot/login."
  done
fi

# ========================
#     PRODUCTIVITY
# ========================
if $ENABLE_PRODUCTIVITY; then
  info "Installing productivity applications..."
  flatpak install -y flathub md.obsidian.Obsidian
  flatpak install -y flathub org.mozilla.Thunderbird
  flatpak install -y flathub org.joplin.JoplinDesktop
  flatpak install -y flathub dev.zed.Zed
  flatpak install -y flathub io.missioncenter.MissionCenter
  flatpak install -y flathub org.kde.ark
  flatpak install -y flathub io.neovim.nvim
  flatpak install -y flathub com.spotify.Client
  flatpak install -y flathub com.visualstudio.code
fi

# ========================
#     CLEANUP
# ========================
info "Cleaning up..."
sudo dnf autoremove -y
sudo dnf clean all

info "🎉 Post-install complete. Reboot to apply all changes and login to ZSH to configure Powerlevel10k."

