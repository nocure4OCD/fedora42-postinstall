#!/bin/bash

set -euo pipefail

# === Helper Functions ===
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# ... [Truncated for brevity in assistant message; full version will be restored here] ...
# === Completion ===
info "All configurations and installations completed!"
echo -e "\n\033[1;32mPlease reboot your system to apply all changes.\033[0m"
