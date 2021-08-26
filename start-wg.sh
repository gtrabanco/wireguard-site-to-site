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

# Register routes to peers
register_peers_routes

# Start wireguard
stopWG && startWG
