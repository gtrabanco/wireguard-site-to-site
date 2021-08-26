#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC1091,SC2034,SC2128

set -euo pipefail

#[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

. "$(dirname "$BASH_SOURCE")/networking.bash"
. "$(dirname "$BASH_SOURCE")/.env"

[[
  -z "${VPN_SERVER_IP:-}" ||
  -z "${VPN_SERVER_BITS_MASK:-}" ||
  -z "${VPN_SERVER_PRIVATE_KEY:-}" ||
  -z "${VPN_SERVER_PUBLIC_KEY:-}" ||
  -z "${VPN_SERVER_CONFIG_FILE:-}" ||
  -z "${INTERFACE_PEERS_CONFIG_PATH:-}" ||
  -z "${INTERFACE_STORE_KEYS_PATH:-}"
]] && echo "Any needed variable is not configured" && exit 4

#VPN_NETWORK_CDR="${VPN_SERVER_IP}/${VPN_SERVER_BITS_MASK}"
VPN_SERVER_PORT=${VPN_SERVER_PORT:-51820}
SSHD_SERVER_PORT=${SSHD_SERVER_PORT:-22}
should_create_backup=false

mkdir -p "$INTERFACE_PEERS_CONFIG_PATH" || true
if [[ ! -w "$INTERFACE_PEERS_CONFIG_PATH" ]]; then
  echo "Failed to create the directory to store the peers configuration or is not writable"
  exit 5
fi

mkdir -p "$INTERFACE_STORE_KEYS_PATH" || true
if [[ ! -w "$INTERFACE_STORE_KEYS_PATH" ]]; then
  echo "Failed to create the directory to store the keys or is not writable"
  exit 5
fi

if [[ $VPN_SERVER_PORT -gt 65535 || $VPN_SERVER_PORT -lt 1024 ]]; then
  echo "You should choose a port between 1024 & 65535"
  exit 4
fi

if [[ -n "$(sudo lsof "-i:${VPN_SERVER_PORT}" 2> /dev/null)" ]]; then
  echo "The por '${VPN_SERVER_PORT}' is still in use"
  exit 4
fi

start_sudo

if ! has_sudo; then
  echo "sudo is necessary"
  exit 5
fi

# Generate keys
if [[ ! -r "$VPN_SERVER_PRIVATE_KEY" || ! -r "$VPN_SERVER_PUBLIC_KEY" ]]; then
  rm -f "$VPN_SERVER_PRIVATE_KEY" "$VPN_SERVER_PUBLIC_KEY"
  # Generate keys
  gen_pair_of_keys "$VPN_SERVER_PRIVATE_KEY" "$VPN_SERVER_PUBLIC_KEY" | _log "Generating server pair of keys"
fi

PEER_ROUTES="$(get_all_allowed_ips)"
SERVER_PRIVATE_KEY="$(cat "$VPN_SERVER_PRIVATE_KEY")"
SERVER_PUBLIC_KEY="$(cat "$VPN_SERVER_PUBLIC_KEY")"

# Generate server configuration
if [[ ! -r "$VPN_SERVER_CONFIG_FILE" ]]; then
  should_create_backup=true
  echo "Generating server config"
  {
    gen_interface_config "Wireguard Server ${VPN_PUBLIC_IP}:${VPN_SERVER_PORT}" "${VPN_SERVER_IP}" "${VPN_SERVER_BITS_MASK}" "$VPN_SERVER_PORT" "$SERVER_PRIVATE_KEY" "" 1 | tee "$VPN_SERVER_CONFIG_FILE" | _log "Generating server config" &> /dev/null
  } | _log "Generating server config"

  if [[ ! -r "$VPN_SERVER_CONFIG_FILE" ]]; then
    echo "Failed to generate server config"
    exit 4
  fi
fi


# Generate peers configuration
for i in "${!PEERS_IP[@]}"; do
  peer_ip="${PEERS_IP[$i]}"
  peer_name="${PEERS_NAMES[$i]:-$peer_ip}"
  peer_config_file="${INTERFACE_PEERS_CONFIG_PATH}/${peer_ip}"

  # Gerating keys
  peer_private_key_file="${INTERFACE_STORE_KEYS_PATH}/${peer_ip}"
  peer_public_key_file="${INTERFACE_STORE_KEYS_PATH}/${peer_ip}.pub"

  if [[ ! -r "$peer_private_key_file" || ! -r "$peer_public_key_file" ]]; then
    should_create_backup=true
    rm -rf "$peer_private_key_file" "$peer_public_key_file"
    echo "Generating keys for peer: ${peer_name}"
    gen_pair_of_keys "$peer_private_key_file" "$peer_public_key_file" | _log "Generating peer pair of keys"
    if [[ ! -r "$peer_private_key_file" || ! -r "$peer_public_key_file" ]]; then
      echo "Failed to generate keys for peer: ${peer_name}"
      echo "Continuing with next client"
      echo
      continue
    fi
  fi

  peer_private_key="$(cat "$peer_private_key_file")"
  peer_public_key="$(cat "$peer_public_key_file")"
  peer_pks=$(openssl rand -base64 "${PEER_PKS_LENGTH:-32}")

  # Generate peer configuration to save in server config
  if ! grep -q "^PublickKey = ${peer_public_key}" "$VPN_SERVER_CONFIG_FILE"; then
    should_create_backup=true

    echo "Generating peer config for '${peer_name}'"
    {
      gen_peer_config "${peer_name}" "" "$peer_public_key" "${peer_ip}/32" false "${peer_psk:-}" | tee -a "$VPN_SERVER_CONFIG_FILE"
    } | _log "Generated peer config for '${peer_name}'" &> /dev/null
  else
    echo "Peer '${peer_name}' already exists in server config"
  fi

  # Check if peer config already exists
  if
    [[ -f "$peer_config_file" ]] &&
    grep -q "^PrivateKey = ${peer_private_key}" &&
    grep -q "^PublicKey = ${SERVER_PUBLIC_KEY}"
  then
    echo "Peer '${peer_name}' config already exists"
    echo "Skipping"
    continue
  fi

  # Generate interface config for peer
  should_create_backup=true
  echo "Generating interface config for peer '${peer_name}'"
  {
    gen_interface_config "${peer_name}" "${peer_ip}" "${VPN_SERVER_BITS_MASK}" "" "$peer_private_key" "${PEER_DNS_SERVERS:-1.1.1.1}" false | tee "$peer_config_file"
  } | _log "Generated interface config for peer '${peer_name}'" &> /dev/null

  # Generate peer config for peer
  {
    array_name="NETWORKS_CONFIG_${i}"

    if [[ -n "${!array_name:-}" ]]; then
      gen_peer_config "${peer_name}" "${VPN_PUBLIC_IP}:${VPN_SERVER_PORT}" "$SERVER_PUBLIC_KEY" "$PEER_ROUTES" "false" "${peer_psk:-}" | tee -a "$peer_config_file"
    fi
  }
done

# Register routes to peers
register_peers_routes

# Start wireguard
stopWG && startWG
