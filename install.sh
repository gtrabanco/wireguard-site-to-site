#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC1091,SC2034,SC2128

set -euo pipefail

#[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

. "$(dirname "$BASH_SOURCE")/networking.bash"
. "$(dirname "$BASH_SOURCE")/.env"

VPN_SERVER_PORT=${VPN_SERVER_PORT:-51820}

if [[ $VPN_SERVER_PORT -gt 65535 || $VPN_SERVER_PORT -lt 1024 ]]; then
  echo "You should choose a port between 1024 & 65535"
  exit 4
fi

if [[ -n "$(sudo lsof "-i:${VPN_SERVER_PORT}" 2> /dev/null)" ]]; then
  echo "The por '${VPN_SERVER_PORT}' is still in use"
  exit 4
fi

# Install wireguard
echo "deb http://deb.debian.org/debian buster-backports main" | sudo tee /etc/apt/sources.list.d/backports.list

sudo apt update && sudo apt upgrade -y

sudo apt install wireguard wireguard-tools

if ! grep -q '^net.ipv4.ip_forward = 1$' /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
fi

if ! grep -q '^net.ipv4.conf.all.proxy_arp = 1$'; then
  echo "net.ipv4.conf.all.proxy_arp = 1" | sudo tee -a  /etc/sysctl.conf
fi

sysctl -p /etc/sysctl.conf

# to add iptables forwarding rules on bounce servers
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$VPN_SERVER_WG0" -o "$VPN_SERVER_WG0" -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A POSTROUTING -s "$VPN_NETWORK_CDR" -o "$VPN_SERVER_ETH" -j MASQUERADE

# Remove duplicated iptables rules
iptables_remove_duplicates


# Generate keys
if [[ ! -r "$VPN_SERVER_PRIVATE_KEY" || ! -r "$VPN_SERVER_PUBLIC_KEY" ]]; then
  rm -f "$VPN_SERVER_PRIVATE_KEY" "$VPN_SERVER_PUBLIC_KEY"
  # Generate keys
  gen_pair_of_keys "$VPN_SERVER_PRIVATE_KEY" "$VPN_SERVER_PUBLIC_KEY"
fi

PEER_ROUTES="$(get_all_Allowed_IPs)"
# SERVER_PRIVATE_KEY="$(cat "$VPN_SERVER_PRIVATE_KEY")"
SERVER_PUBLIC_KEY="$(cat "$VPN_SERVER_PUBLIC_KEY")"

