#!/bin/bash
# speedup.sh — EXTREME download/upload optimization for Linux Mint. Safe to re-run.
# Fast path (default): applies known-fastest settings immediately, no benchmarking.
#   ./speedup.sh --retest   re-benchmark Ubuntu mirrors before switching.
#   1. Fastest DNS (Cloudflare) via systemd-resolved drop-in.
#   2. Ubuntu archive -> fastest mirror (backup first).
#   3. nala (parallel apt downloads) + aria2 (multi-connection downloader) + lean apt.
#   4. TCP BBR + fq (max throughput both directions) + git/GitHub fast proxy.
# Needs sudo (password asked once) + network.
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

echo "==> Fastest DNS (Cloudflare 1.1.1.1)..."
S mkdir -p /etc/systemd/resolved.conf.d
# NOTE: never pipe content through S (sudo -S would eat it as the password).
S bash -c 'printf "[Resolve]\nDNS=1.1.1.1 1.0.0.1\nFallbackDNS=8.8.8.8 8.8.4.4\n" > /etc/systemd/resolved.conf.d/fast-dns.conf'
S systemctl restart systemd-resolved 2>/dev/null \
  || S service systemd-resolved restart 2>/dev/null \
  || echo "    (could not restart resolved; applies on reboot)"

# Measured winners (Bangladesh): bd.archive.ubuntu.com sustains the best
# throughput on real payloads. Override with --retest to re-measure live.
MIRROR_HOST="bd.archive.ubuntu.com"
if [ "${1:-}" = "--retest" ]; then
  CANDIDATES=(
    "http://bd.archive.ubuntu.com/ubuntu"
    "http://archive.ubuntu.com/ubuntu"
    "http://mirrors.edge.kernel.org/ubuntu"
  )
  fastest=""; fastest_speed=0
  echo "==> Benchmarking Ubuntu mirrors..."
  for base in "${CANDIDATES[@]}"; do
    speed=0; code="000"
    for tp in "/dists/noble/main/binary-amd64/Packages.gz" "/dists/noble/InRelease"; do
      read -r code speed _ < <(curl -sL -o /dev/null \
        -w "%{http_code} %{speed_download} x" --max-time 25 "${base}${tp}" 2>/dev/null)
      speed=${speed%.*}; [ -z "$speed" ] && speed=0
      [ "$code" = "200" ] && break
    done
    printf "    %-42s %s %s B/s\n" "$base" "$code" "$speed"
    if [ "$code" = "200" ] && [ "$speed" -gt "$fastest_speed" ]; then
      fastest_speed=$speed; fastest=$base
    fi
  done
  if [ -n "$fastest" ]; then
    MIRROR_HOST=$(echo "$fastest" | sed 's#http://##; s#/ubuntu##')
  fi
fi

echo "==> Ubuntu archive -> $MIRROR_HOST ..."
changed=0
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] || continue
  if grep -Eq "^[[:space:]#]*deb(-src)? +https?://[^/ ]+/ubuntu/? " "$f" 2>/dev/null; then
    [ -f "$f.bak-speedup" ] || S cp "$f" "$f.bak-speedup"
    S sed -E -i "/^[[:space:]#]*deb(-src)? +https?:\/\// s#https?://[^/ ]+/ubuntu/? #http://$MIRROR_HOST/ubuntu #g" "$f"
    echo "    updated $f (backup: $f.bak-speedup)"
    changed=1
  fi
done
# Mint main repo stays official (no faster local option).

echo "==> Lean apt config (no lang downloads, sane timeouts)..."
S bash -c 'printf "Acquire::Languages \"none\";\nAcquire::http::Timeout \"15\";\nAcquire::https::Timeout \"15\";\nAcquire::Retries \"3\";\n" > /etc/apt/apt.conf.d/99-speedup'

echo "==> nala (parallel) + aria2 (multi-connection) + refresh..."
for i in $(seq 1 6); do
  S fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || break
  echo "    (apt busy, waiting...)"; sleep 10
done
S apt update && S apt install -y nala aria2

echo "==> TCP BBR + fq (max throughput up/down)..."
S bash -c 'printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n" > /etc/sysctl.d/99-speedup-bbr.conf'
S sysctl -w net.core.default_qdisc=fq net.ipv4.tcp_congestion_control=bbr > /dev/null
# fq on the live interface now + persistently (NM dispatcher, Mint default net).
IFACE=$(ip -o route get 1.1.1.1 2>/dev/null | awk '{print $5}' | head -1)
if [ -n "$IFACE" ]; then
  S tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
  S bash -c 'printf "#!/bin/sh\n[ \"$2\" = up ] && tc qdisc replace dev \"$1\" root fq\n" > /etc/NetworkManager/dispatcher.d/50-speedup-fq.sh'
  S chmod +x /etc/NetworkManager/dispatcher.d/50-speedup-fq.sh
  echo "    fq on $IFACE (persistent)"
fi

echo "==> Disable dead IPv6 (kills happy-eyeballs delay per connection)..."
if ip -6 route get 2001:4860:4860::8888 >/dev/null 2>&1; then
  echo "    (IPv6 works here, leaving it on)"
else
  S bash -c 'printf "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1\nnet.ipv6.conf.lo.disable_ipv6=1\n" > /etc/sysctl.d/99-speedup-noipv6.conf'
  S sysctl -w net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 net.ipv6.conf.lo.disable_ipv6=1 > /dev/null
  echo "    IPv6 off (was unreachable)"
fi

echo "==> git/GitHub through fast proxy..."
git config --global url."https://gh-proxy.com/https://github.com/".insteadOf "https://github.com/" \
  && echo "    git will use gh-proxy.com for github.com"

echo "Done. Fastest DNS + mirror + parallel apt + git proxy active."
