# Fedora 42 Post-Install Script

This script automates the setup of a fresh Fedora 42 installation with a focus on privacy, productivity, media, gaming, and GNOME customization. It is ideal for personal or hybrid use.

## Installation (Quick Start)

Run this in your terminal to start the installation process:

```bash
curl -s https://raw.githubusercontent.com/nocure4OCD/fedora42-postinstall/main/fedora42_postinstall.sh | bash
```

This command will download the script and execute it directly.

## Notes

Before running the script, ensure you have **Git** and **curl** installed on your system. If not, you can install them with the following command:

```bash
sudo dnf install git curl -y
```

Additionally, this script requires an **internet connection** to fetch the necessary repositories and packages.

It is recommended that your system is up-to-date before running the script. You can do this by running:

```bash
sudo dnf upgrade --refresh -y
```

Make sure to run the script **as a regular user** (not root).

If you prefer to manually update or modify the script from your GitHub repository, you can clone the repo to your system by running:

```bash
git clone https://github.com/nocure4OCD/fedora42-postinstall.git
cd fedora42-postinstall
```

Optional flags will be added soon to toggle optional groups like:

- `--no-gaming` — Skip gaming tools installation
- `--no-comm` — Skip communication/media apps installation
- `--vpn=no` — Skip ProtonVPN installation
- `--zsh=no` — Skip Oh My Zsh setup

The script includes a **sudo keep-alive** function to prevent timeout issues during long operations. It will also automatically install and enable the necessary GNOME extensions and configure **Flatpak apps** with `--user` to avoid conflicts with system-wide installations.

## License

MIT License

## Author

nocure4OCD
```
