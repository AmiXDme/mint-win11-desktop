#!/bin/bash
# mint-win11-desktop — restore Win11-style Cinnamon desktop on a fresh Linux Mint install.
# Usage: ./install.sh
set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLET_DIR="$HOME/.local/share/cinnamon/applets"
SPICES_DIR="$HOME/.config/cinnamon/spices"

echo "==> Installing applets..."
mkdir -p "$APPLET_DIR" "$SPICES_DIR/menueleven@djb"
cp -r "$REPO_DIR/applets/menueleven@djb" "$APPLET_DIR/"
cp -r "$REPO_DIR/applets/searchbar@win11" "$APPLET_DIR/"

echo "==> Restoring applet settings..."
cp "$REPO_DIR/config/menueleven@djb.json" "$SPICES_DIR/menueleven@djb/menueleven@djb.json"

echo "==> Restoring panel layout (Menu -> Search -> windows, centered)..."
dconf write /org/cinnamon/enabled-applets "$(cat "$REPO_DIR/config/enabled-applets.txt")"
dconf write /org/cinnamon/next-applet-id "$(cat "$REPO_DIR/config/next-applet-id.txt")"

echo "==> Restarting Cinnamon..."
cinnamon --replace > /dev/null 2>&1 &
sleep 3

echo "Done. Press the Windows key to open the Win11 start menu."
