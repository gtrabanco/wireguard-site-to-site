#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC1091,SC2034,SC2128

set -euo pipefail

#[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

. "$(dirname "$BASH_SOURCE")/networking.bash"
. "$(dirname "$BASH_SOURCE")/.env"
# . "$(dirname "$BASH_SOURCE")/generate_config.sh"

if [[ ! -r "$VPN_SERVER_CONFIG_FILE" ]]; then
  echo "The VPN server config file '${VPN_SERVER_CONFIG_FILE}' is not readable"
  exit 5
fi

# Start wireguard
stopWG "${VPN_SERVER_IP:-10.0.0.1}" "${VPN_SERVER_CONFIG_FILE:-/etc/wireguard/${VPN_SERVER_WG0:-wg0}.conf}}" "${VPN_SERVER_WG0:-wg0}"
