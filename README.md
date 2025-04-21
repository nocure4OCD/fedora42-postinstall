# Fedora 42 Post-Install Script 🎯

A fully modular and customizable post-installation script for Fedora 42 users who want a well-rounded, powerful desktop experience. This isn’t some ultra-minimalist or bloated mess—it’s a sane, thoughtfully curated setup for people with decent hardware and enough storage to actually enjoy their machine. If you’ve got a solid rig and want a blend of productivity, creativity, gaming, privacy, and polish, this script’s for you.

---

## 🔧 Features & Inclusions

✅ Modular toggle support (`--no-[flag]` to disable a module) 

✅ Flatpak + Flathub + RPM Fusion setup 

✅ Alacritty as default terminal 

✅ ZSH shell with Powerlevel10k theme 

✅ MesloLGS Nerd Fonts (for Powerlevel10k) 

✅ GNOME extensions auto-install & enable 

✅ Qogir themes (GTK, icons, cursors, shell) and Flat-Remix GNOME Darkest 

✅ Full suite of Flatpak applications 

✅ Optional NVIDIA support 


---

## 🚀 How to Use

```bash
curl -s https://raw.githubusercontent.com/nocure4OCD/fedora42-postinstall/main/fedora42_postinstall.sh | bash
```

🧱 Modules (Toggle with --no-[flag] or --nvidia)
Flag	Description
security	UFW + ProtonVPN
multimedia	Codecs + ffmpeg + gstreamer
power	TLP and Powertop
gaming	Steam, Lutris, Heroic, Bottles, ProtonUp
productivity	Calendar, Boxes, Flatseal, Foliate
creative	Krita, Darktable, PDF editors, Okular
comm	Signal, Telegram, WhatsApp, Simplex, Zed
zsh	Installs Oh My Zsh + Powerlevel10k
themes	Qogir (installed + equipped), Flat-Remix
extensions	GNOME shell extensions (see below)
nvidia	Enables NVIDIA drivers + GPU Stats Tool

To skip a module:

```
curl -s ... | bash -s -- --no-gaming --no-comm
```

To enable NVIDIA driver support:

```
curl -s ... | bash -s -- --nvidia
```

📦 Flatpak Applications Installed

    System & Productivity:

        com.github.tchx84.Flatseal

        org.gnome.Extensions

        org.gnome.DejaDup

        org.gnome.Calendar

        org.gnome.Boxes

        com.github.johnfactotum.Foliate

        md.obsidian.Obsidian

        net.cozic.joplin_desktop

    Development & Utilities:

        dev.zed.Zed

        io.neovim.nvim

        com.github.Matoking.protonupqt

        io.github.missioncenter.MissionCenter

    Creative & Media:

        org.kde.krita

        org.darktable.Darktable

        com.github.wnxemoark.MasterPDFEditor

        org.kde.okular

        org.kde.ark

        org.videolan.VLC

        org.gaias.sky

        re.sonny.Ear

        dev.mixer.Mixer

        one.zen.zen

    Gaming:

        com.heroicgameslauncher.hgl

        net.lutris.Lutris

        net.davidotek.pupgui2

        com.usebottles.bottles

    Communication:

        org.signal.Signal

        org.telegram.desktop

        io.github.mimbrero.WhatsAppDesktop

        chat.simplex.Simplex

        us.zoom.Zoom

    Privacy:

        ch.protonmail.protonmail-bridge

    NVIDIA (optional):

        io.github.realmazharhussain.NvidiaGpuStatsTool

🎨 Themes & Customizations

    Equipped by Default:

        Qogir GTK theme

        Qogir Shell theme (default, dark, and light installed)

        Qogir Icons

        Qogir Cursors (standard/light)

    Available (Not equipped):

        Flat-Remix-GNOME-Darkest shell theme

🧩 GNOME Extensions (Installed & Enabled)

    Blur My Shell

    Dash to Dock

    Alphabetical App Grid

    GNOME Fuzzy App Search

    Removable Drive Menu

    Remove World Clocks

    User Themes

    Weather or Not

    Apps Menu

🔠 Fonts

The script automatically installs:

    MesloLGS Nerd Fonts (Regular, Bold, Italic, Bold Italic)

These fonts are required for proper rendering of the Powerlevel10k theme.
🛠 Recommended Before Running

Ensure your system is fully updated and Git is installed:

sudo dnf update -y
sudo dnf install -y git

🧪 Tested On

    Fedora 42 (Workstation Edition)

    Both AMD and Intel/NVIDIA hardware

    GNOME Shell 48

🙌 Author

Josh (aka nocure4OCD)
GitHub: @nocure4OCD
Licensed under MIT — Open to all!

📣 Want to Contribute?

Feel free to fork, open an issue, or suggest improvements!
This script is meant to serve as a launchpad for Fedora users who want out-of-the-box comfort and customization.
