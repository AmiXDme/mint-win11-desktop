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

SUDO_PW=""
S() { # S <cmd...>: run privileged command, asking the sudo password once
  if [ -z "$SUDO_PW" ] && ! sudo -n true 2>/dev/null; then
    printf 'sudo password: ' >&2
    IFS= read -rs SUDO_PW < /dev/tty 2>/dev/null \
      || IFS= read -rs SUDO_PW \
      || { echo "cannot read password"; exit 1; }
    printf '\n' >&2
    printf '%s\n' "$SUDO_PW" | sudo -S -v 2>/dev/null \
      || { SUDO_PW=""; echo "sudo failed"; exit 1; }
  fi
  if [ -n "$SUDO_PW" ]; then printf '%s\n' "$SUDO_PW" | sudo -S "$@";
  else sudo "$@"; fi
}
trap 'SUDO_PW=""' EXIT

need_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "==> Speeding up downloads (mirrors + git proxy)..."
"$REPO_DIR/speedup.sh" || echo "WARNING: speedup.sh had issues, continuing..."

echo "==> System tune-up (zram, CPU, logs)..."
"$REPO_DIR/tuneup.sh" || echo "WARNING: tuneup.sh had issues, continuing..."

echo "==> Ensuring build tools (git, sassc, murrine engine)..."
if ! need_cmd git || ! need_cmd sassc; then
  if need_cmd nala; then S nala install -y git sassc gtk2-engines-murrine
  else S apt install -y git sassc gtk2-engines-murrine; fi
fi

fetch() { # fetch <name> <url> <dest>
  if [ -d "$3" ]; then echo "    (cached $1)"; return 0; fi
  git clone --depth 1 "$2" "$3"
}

echo "==> Theme packs (cloning in parallel)..."
fetch Fluent-gtk-theme https://github.com/vinceliuice/Fluent-gtk-theme.git "$TMP_BASE/Fluent-gtk-theme" &
fetch Win11-icon-theme https://github.com/yeyushengfan258/Win11-icon-theme.git "$TMP_BASE/Win11-icon-theme" &
fetch Fluent-icon-theme https://github.com/vinceliuice/Fluent-icon-theme.git "$TMP_BASE/Fluent-icon-theme" &
wait

echo "==> Installing theme packs..."
if [ ! -d "$HOME/.themes/Fluent-round-Dark" ]; then
  (cd "$TMP_BASE/Fluent-gtk-theme" && ./install.sh -d "$HOME/.themes" -c dark --tweaks round) \
    || echo "WARNING: Fluent-gtk-theme install failed, continuing..."
else echo "    (Fluent-round-Dark already installed)"; fi
if [ ! -d "$HOME/.local/share/icons/Win11-dark" ]; then
  (cd "$TMP_BASE/Win11-icon-theme" && ./install.sh) \
    || echo "WARNING: Win11-icon-theme install failed, continuing..."
else echo "    (Win11-dark already installed)"; fi
if [ ! -d "$HOME/.icons/Fluent-dark-cursors" ] && [ ! -d "$HOME/.local/share/icons/Fluent-dark-cursors" ]; then
  (cd "$TMP_BASE/Fluent-icon-theme/cursors" && ./install.sh) \
    || echo "WARNING: Fluent cursor install failed, continuing..."
else echo "    (Fluent-dark-cursors already installed)"; fi

echo "==> Installing applets..."
mkdir -p "$APPLET_DIR" "$SPICES_DIR/menueleven@djb" "$SPICES_DIR/multicore-sys-monitor@ccadeptic23"
cp -r "$REPO_DIR/applets/menueleven@djb" "$APPLET_DIR/"
cp -r "$REPO_DIR/applets/searchbar@win11" "$APPLET_DIR/"
cp -r "$REPO_DIR/applets/multicore-sys-monitor@ccadeptic23" "$APPLET_DIR/"
cp -r "$REPO_DIR/applets/sysmon-text@win11" "$APPLET_DIR/"

echo "==> Restoring applet settings..."
cp "$REPO_DIR/config/menueleven@djb.json" "$SPICES_DIR/menueleven@djb/menueleven@djb.json"
cp "$REPO_DIR/config/multicore-sys-monitor@ccadeptic23.json" "$SPICES_DIR/multicore-sys-monitor@ccadeptic23/multicore-sys-monitor@ccadeptic23.json"

echo "==> Max-speed downloader defaults (aria2: 16 conns x 16 splits)..."
mkdir -p "$HOME/.aria2"
cp "$REPO_DIR/config/aria2.conf" "$HOME/.aria2/aria2.conf"

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

echo "==> Final cleanup (apt cache, orphans, thumbnails)..."
"$REPO_DIR/cleanup.sh" || echo "WARNING: cleanup.sh had issues, continuing..."

echo "Done. Press the Windows key to open the Win11 start menu."
