#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC1091,SC2034,SC2128

set -euo pipefail

[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

. "$(dirname "$BASH_SOURCE")/networking.bash"
. "$(dirname "$BASH_SOURCE")/.env"
# . "$(dirname "$BASH_SOURCE")/generate_config.sh"

if [[ ! -r "$VPN_SERVER_CONFIG_FILE" ]]; then
  echo "The VPN server config file '${VPN_SERVER_CONFIG_FILE}' is not readable"
  exit 5
fi

start_sudo

if ! has_sudo; then
  echo "sudo is necessary"
  exit 5
fi

sudo systemctl enable "wg-quick@${VPN_SERVER_WG0}.service"
sudo systemctl daemon-reload
sudo systemctl start wg-quick@wg0

# To remove service
# sudo systemctl stop wg-quick@wg0
# sudo systemctl disable wg-quick@wg0.service
# sudo rm -i /etc/systemd/system/wg-quick@wg0*
# sudo systemctl daemon-reload
# sudo systemctl reset-failed
