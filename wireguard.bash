#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC2016

get_peer_index_networks() {
  local array_name="" routes=() IFS

  local -r i="${1:-}"
  local -r peer_ip="${PEERS_IP[$i]:-}"
  [[ -z "$i" || -z "$peer_ip" ]] && return

  if ! validate_ip "$peer_ip"; then
    echo "Peer IP '$peer_ip' is invalid ip address" 1>&2
    return
  fi

  array_name="NETWORKS_CONFIG_${i}"
  
  if [[ -n "${!array_name:-}" ]]; then
    routes=($(eval "echo \${${array_name}[@]}"))
  fi

  if [[ ${#routes[@]} -gt 0 ]]; then
    IFS=', '
    echo "${routes[*]}"
  fi
}

get_all_allowed_ips() {
  local i=0 array_name="" routes=() IFS=$' '

  for peer_ip in "${PEERS_IP[@]}"; do
    if ! validate_ip "$peer_ip"; then
      echo "Peer IP '$peer_ip' is invalid ip address"
      return
    fi

    array_name="NETWORKS_CONFIG_${i}"

    if [[ -n "${!array_name:-}" ]]; then
      routes+=($(eval "echo \${${array_name}[*]}"))
    fi
    i=$(( i + 1 ))
    array_name=""
  done

  if ${ROUTE_ALL_PRIVATE:-false}; then
    echo "192.168.0.0/16, 172.16.0.0/12, 10.0.0.0/8"
  elif [[ ${#routes[@]} -gt 0 ]]; then
    IFS=$', '
    echo "${routes[*]}"
  else
    echo "0.0.0.0/0, ::/0"
  fi
}

gen_pair_of_keys() {
  local -r private_key_file_path="${1:-}"
  local public_key_file_path="${2:-${private_key_file_path}.pub}"

  if
    [[
      -z "$private_key_file_path" ||
      -r "$private_key_file_path" ||
      -r "$public_key_file_path"
    ]]
  then
    echo "Empty private/public key file path or private or public key file already exists" 1>&2
    return 1
  fi

  umask 077
  wg genkey | tee "$private_key_file_path" | wg pubkey | tee "$public_key_file_path" &> /dev/null
  umask 022
}

#"
# gen_interface_config()
# Generate a config for wg Interface
# @param string name
# @param string ip_address
# @param string netmask (bits) This param can be ignored if it is included with the ip address
# @param string server_port
# @param string key If none it will be generated
# @param string dns_servers If none won't add it
# @param boolean post_exec
#;
gen_interface_config() {
  local -r name="${1:-}"
  local -r ip_address="${2:-}"

  [[ -z "$ip_address" ]] && echo "Needs an IP address" 1>&2 && return
  ! type wg &> /dev/null && echo "Is wireguard installed?" 1>&2 && return

  if [[ -n "$(ip_get_mask "$ip_address")" ]]; then
    local -r bits="$(ipv4_bits "$(ip_get_mask "$ip_address")" || echo -n)"
  else
    local -r bits="$(ipv4_bits "${3:-0}" || echo -n)"
    shift
  fi
  # Validate bits
  [[ $bits -lt 0 || $bits -gt 32 ]] && echo "Wrong netmask bits" 1>&2 && return

  local -r server_port="${3:-}"
  # Validate server_port

  local -r key="${4:-}"
  local -r dns_servers="${5:-}"
  local -r post_exec=${6:-false}

  echo '[Interface]'
  echo "# Name = ${name}"
  echo "Address = ${ip_address}/${bits}"

  if [[ -n "$server_port" ]]; then
    echo "ListenPort = ${server_port}"
  fi

  echo "PrivateKey = ${key}"
  
  if [[ -n "${dns_servers:-}" ]]; then
    echo "DNS = $dns_servers"
  fi

  if [[ "${post_exec:-true}" == "true" || "${post_exec:-}" == "1" ]]; then
    [[ -n "${VPN_SERVER_IP}" && "${VPN_SERVER_IP}" != "$ip_address" ]] && echo "PostUp = ping -c1 ${VPN_SERVER_IP}"
    echo 'PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
    echo 'PostUp = echo "$(date +%s) WireGuard Started" >> /var/log/wireguard.log'
    echo 'PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE'
    echo 'PostDown = echo "$(date +%s) WireGuard Going Down" >> /var/log/wireguard.log'
  fi
  echo
}

#"
# gen_peer_config()
# Generate a config for wg Interface
# @param string name
# @param string server_address
# @param string key
# @param string allowed_ips
# @param string is_nat
# @param string pre_shared_key
#;
gen_peer_config() {
  local -r name="${1:-}"
  local -r server_address="${2:-}"
  local -r key="${3:-}"
  local -r allowed_ips="${4:-0.0.0.0/0, ::/0}"
  local -r is_nat=${5:-false}
  local -r pre_shared_key="${6:-}"

  echo '[Peer]'
  echo "# Name = ${name}"
  
  if [[ -n "$server_address" ]]; then
    echo "Endpoint = ${server_address}"
  fi

  echo "PublicKey = ${key}"
  
  if [[ -n "$pre_shared_key" ]]; then
    echo "PresharedKey = ${pre_shared_key}"
  fi

  echo "AllowedIPs = ${allowed_ips[*]}" | awk '{gsub(/,\s*/,", ", $0); print}'

  if [[ "${is_nat:-true}" == "true" || "${is_nat:-}" == "1" ]]; then
    echo 'PersistentKeepalive = 25'
  fi
  
  echo
}

qrencode_dependency_installed() {
  if
    ! command -v qrencode &> /dev/null &&
    command -v apt &> /dev/null &&
    ! dpkg --list "wireguard" &> /dev/null
  then
    echo "Installing qrencode dependency"
    command sudo apt-get install -y qrencode &> /dev/null
    if
      command -v apt &> /dev/null &&
      ! dpkg --list "wireguard" &> /dev/null
    then
      echo "Failed to install qrencode dependency" 1>&2
      return 1
    fi
  fi
}


show_file_as_qr() {
  [[ ! -r "${1:-}" ]] && return 1
  ! qrencode_dependency_installed && return 1
  qrencode -m 2 -t ansiutf8 <<< "$1"
}

generate_qr_code_from_file() {
  [[ ! -r "${1:-}" || -z "${2:-}" ]] && return 1
  ! qrencode_dependency_installed && return 1

  qrencode -m 2 -t ansiutf8 -o "${2:-}" <<< "$1"
}
