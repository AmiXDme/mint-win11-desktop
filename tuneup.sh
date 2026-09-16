#!/bin/bash
# tuneup.sh — system performance tuning for Linux Mint (8GB-RAM friendly).
# Safe to re-run. Needs sudo (password asked once).
#   1. zram swap (4G, top priority) + swappiness tuned for it.
#   2. CPU governor -> performance on all cores.
#   3. Journal capped at 200M (frees SSD, faster boots).
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

echo "==> zram swap (4G, priority 100, above disk swap)..."
if [ ! -e /sys/block/zram0 ]; then
  S bash -c 'printf "zram\n" > /etc/modules-load.d/speedup-zram.conf'
  S modprobe zram num_devices=1
fi
S bash -c 'cat > /etc/systemd/system/zram-speedup.service <<"UNIT"
[Unit]
Description=zram swap for speedup (4G, priority 100)
Before=swap.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "echo 4G > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0"
ExecStop=/bin/sh -c "swapoff /dev/zram0 && echo 1 > /sys/block/zram0/reset"
[Install]
WantedBy=swap.target
UNIT'
S systemctl daemon-reload
S systemctl enable --now zram-speedup.service 2>/dev/null \
  || { S swapon -p 100 /dev/zram0 2>/dev/null || true; }
echo "==> swappiness -> 180 (zram-first)..."
S bash -c 'printf "vm.swappiness=180\n" > /etc/sysctl.d/99-speedup-vm.conf'
S sysctl -w vm.swappiness=180 > /dev/null
swapon --show 2>/dev/null | head -4 || true

echo "==> CPU governor -> performance..."
for g in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
  [ -w "$g" ] && echo performance > "$g" 2>/dev/null \
    || S bash -c "echo performance > $g" 2>/dev/null || true
done
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true

echo "==> Journal cap 200M + vacuum + apt clean..."
S mkdir -p /etc/systemd/journald.conf.d
S bash -c 'printf "[Journal]\nSystemMaxUse=200M\nRuntimeMaxUse=100M\n" > /etc/systemd/journald.conf.d/99-speedup.conf'
S journalctl --vacuum-size=200M 2>/dev/null | tail -1 || true
S apt autoclean 2>/dev/null | tail -1 || true

echo "Done. zram active, CPU maxed, logs capped."
