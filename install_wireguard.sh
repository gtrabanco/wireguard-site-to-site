#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC1091,SC2034,SC2128

set -euo pipefail

[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

. "$(dirname "$BASH_SOURCE")/networking.bash"
. "$(dirname "$BASH_SOURCE")/.env"

sysctl_modified=false

start_sudo

if ! has_sudo; then
  echo "sudo is necessary"
  exit 5
fi

# Install wireguard
if [[ ! -f "/etc/apt/sources.list.d/backports.list" ]]; then
  echo "deb http://deb.debian.org/debian buster-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
fi

if
  command -v apt &> /dev/null &&
  ! dpkg --list "wireguard" &> /dev/null &&
  ! dpkg --list "wireguard-dkms" &> /dev/null &&
  ! dpkg --list "wireguard-tools" &> /dev/null
then
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y wireguard wireguard-dkms wireguard-tools
fi

if ! grep -q '^net.ipv4.ip_forward = 1$' /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf | _log "Modify ip forward in sysctl.conf"
  sysctl_modified=true
fi

if ! grep -q '^net.ipv4.conf.all.proxy_arp = 1$' /etc/sysctl.conf; then
  echo "net.ipv4.conf.all.proxy_arp = 1" | sudo tee -a  /etc/sysctl.conf | _log "Modify arp proxy in sysctl.conf" &> /dev/null
  sysctl_modified=true
fi

if ${sysctl_modified:-false}; then
  sudo sysctl -p /etc/sysctl.conf
fi

if ! ${IGNORE_IPTABLES_CONFIG:-false}; then
  # to add iptables forwarding rules on bounce servers
  iptables -P INPUT DROP
  iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -I INPUT -p udp --dport "${VPN_SERVER_PORT:-51820}" -j ACCEPT
  iptables -I INPUT -p tcp -m tcp --dport "${SSHD_SERVER_PORT:-22}" -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i "${VPN_SERVER_WG0:-wg0}" -o "${VPN_SERVER_WG0:-wg0}" -m conntrack --ctstate NEW -j ACCEPT
  iptables -t nat -A POSTROUTING -s "$VPN_NETWORK_CDR" -o "${VPN_SERVER_ETH:-eth0}" -j MASQUERADE

  # Remove duplicated iptables rules
  iptables_remove_duplicates
fi

echo "Wireguard installed"
