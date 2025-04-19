# Fedora 42 Post-Install Script

This script automates the setup of a fresh Fedora 42 installation with a focus on AMD hardware (no NVIDIA support), privacy, productivity, media, gaming, and GNOME customization. It is ideal for personal or hybrid (fun + research) use.

## Features

- RPM Fusion and Flathub setup
- Multimedia codecs and enhancements
- GNOME shell tweaks, extensions, and theming (Qogir + Flat Remix)
- Zsh with Oh My Zsh + Powerlevel10k
- ProtonVPN and UFW firewall setup
- Gaming tools: Steam, Heroic, Lutris, and GameMode
- Productivity: Boxes, Calendar, Flatseal, Foliate
- Media & communication apps: Brave, VLC, OBS, Signal, Telegram, WhatsApp, Proton Bridge, Zoom

## Requirements

- A fresh Fedora 42 install
- AMD CPU/GPU (no NVIDIA drivers required)
- GNOME desktop environment (default on Fedora Workstation)
- Internet connection

## Installation (Quick Start)

Run this in your terminal:

```bash
curl -s https://raw.githubusercontent.com/nocure4OCD/fedora42-postinstall/main/fedora42_postinstall.sh | bash
