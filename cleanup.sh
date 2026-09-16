#!/bin/bash
# cleanup.sh — remove unneeded files: apt cache, orphaned packages (incl. old
# kernels, keeps running one), thumbnail cache. Safe to re-run.
# Needs sudo (password asked once).
set -u

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

echo "==> apt cache clean + autoremove (old kernels, orphans)..."
S apt clean
S apt autoremove --purge -y
echo "==> thumbnail cache..."
rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
echo "==> disk now:"
df -h / | tail -1
echo "Done."
