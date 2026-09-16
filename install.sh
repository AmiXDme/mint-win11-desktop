#!/bin/bash
# mint-win11-desktop — fully automatic Win11-style Cinnamon setup for Linux Mint.
# Usage: ./install.sh
# Installs theme packs from upstream (needs network + sudo for apt), then
# restores applets, settings, panel layout and themes. Safe to re-run.
set -u
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLET_DIR="$HOME/.local/share/cinnamon/applets"
SPICES_DIR="$HOME/.config/cinnamon/spices"
TMP_BASE="${TMPDIR:-/tmp}/mint-win11-setup"
mkdir -p "$TMP_BASE"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "==> Ensuring build tools (git, sassc, murrine engine)..."
if ! need_cmd git || ! need_cmd sassc; then
  sudo apt update && sudo apt install -y git sassc gtk2-engines-murrine
fi

fetch() { # fetch <name> <url> <dest>
  if [ -d "$3" ]; then echo "    (cached $1)"; return 0; fi
  git clone --depth 1 "$2" "$3"
}

echo "==> Theme pack: Fluent gtk theme (Fluent-round-Dark)..."
if [ ! -d "$HOME/.themes/Fluent-round-Dark" ]; then
  fetch Fluent-gtk-theme https://github.com/vinceliuice/Fluent-gtk-theme.git "$TMP_BASE/Fluent-gtk-theme" \
    && (cd "$TMP_BASE/Fluent-gtk-theme" && ./install.sh -d "$HOME/.themes" -c dark --tweaks round) \
    || echo "WARNING: Fluent-gtk-theme install failed, continuing..."
else
  echo "    (already installed)"
fi

echo "==> Theme pack: Win11 icons (Win11-dark)..."
if [ ! -d "$HOME/.local/share/icons/Win11-dark" ]; then
  fetch Win11-icon-theme https://github.com/yeyushengfan258/Win11-icon-theme.git "$TMP_BASE/Win11-icon-theme" \
    && (cd "$TMP_BASE/Win11-icon-theme" && ./install.sh) \
    || echo "WARNING: Win11-icon-theme install failed, continuing..."
else
  echo "    (already installed)"
fi

echo "==> Theme pack: Fluent cursors (Fluent-dark-cursors)..."
if [ ! -d "$HOME/.icons/Fluent-dark-cursors" ] && [ ! -d "$HOME/.local/share/icons/Fluent-dark-cursors" ]; then
  fetch Fluent-icon-theme https://github.com/vinceliuice/Fluent-icon-theme.git "$TMP_BASE/Fluent-icon-theme" \
    && (cd "$TMP_BASE/Fluent-icon-theme/cursors" && ./install.sh) \
    || echo "WARNING: Fluent cursor install failed, continuing..."
else
  echo "    (already installed)"
fi

echo "==> Installing applets..."
mkdir -p "$APPLET_DIR" "$SPICES_DIR/menueleven@djb"
cp -r "$REPO_DIR/applets/menueleven@djb" "$APPLET_DIR/"
cp -r "$REPO_DIR/applets/searchbar@win11" "$APPLET_DIR/"

echo "==> Restoring applet settings..."
cp "$REPO_DIR/config/menueleven@djb.json" "$SPICES_DIR/menueleven@djb/menueleven@djb.json"

echo "==> Restoring panel layout (Menu -> Search -> windows, centered)..."
dconf write /org/cinnamon/enabled-applets "$(cat "$REPO_DIR/config/enabled-applets.txt")"
dconf write /org/cinnamon/next-applet-id "$(cat "$REPO_DIR/config/next-applet-id.txt")"

echo "==> Applying themes (Fluent-round-Dark + Win11-dark icons)..."
while IFS='=' read -r key value; do
  case "$key" in
    gtk-theme) gsettings set org.cinnamon.desktop.interface gtk-theme "$value" ;;
    icon-theme) gsettings set org.cinnamon.desktop.interface icon-theme "$value" ;;
    cursor-theme) gsettings set org.cinnamon.desktop.interface cursor-theme "$value" ;;
    cinnamon-theme) dconf write /org/cinnamon/theme/name "'$value'" ;;
  esac
done < "$REPO_DIR/config/themes.txt"

echo "==> Restarting Cinnamon..."
cinnamon --replace > /dev/null 2>&1 &
sleep 3

echo "Done. Press the Windows key to open the Win11 start menu."
