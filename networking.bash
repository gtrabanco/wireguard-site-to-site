#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC2016

start_sudo() {
  if ! has_sudo; then
    command sudo -v -B
    if has_sudo && [[ -z "${SUDO_PID:-}" ]]; then
      (while true; do
        command sudo -v
        command sleep 30
      done) &
      SUDO_PID="$!"
      builtin trap stop_sudo SIGINT SIGTERM
    fi
  fi
}

stop_sudo() {
  builtin kill "$SUDO_PID" &> /dev/null
  builtin trap - SIGINT SIGTERM
  command sudo -k
}

has_sudo() {
  command sudo -n -v &> /dev/null
}

ipv4_netmask() {
  local IFS='.' netmask=() rest_bits tmp_netmask=0
  local -r bits="${1:-0}"

  if [[ $bits -lt 0 || $bits -gt 32 ]]; then
    echo "Error: IPv4 netmask should be between 0 and 32" 1>&2
    return 1
  fi

  local -r complete=$(( bits / 8 ))
  rest_bits=$(( bits % 8 ))

  until [[ ${#netmask[@]} -eq $complete ]]; do
    netmask+=("255")
  done

  if [[ $rest -lt 8 ]]; then
    while [[ $rest_bits -gt 0 ]]; do
      tmp_netmask=$(( ( 2 ** ( 8 - rest_bits ) ) + tmp_netmask ))
      rest_bits=$(( rest_bits - 1 ))
    done
    netmask+=("$tmp_netmask")
  fi

  while [[ ${#netmask[@]} -lt 4 ]]; do
    netmask+=("0")
  done

  echo "${netmask[*]}"
}

ipv4_wildcard() {
  local IFS='.' netmask=() i
  local -r bits="${1:-0}"

  netmask=(${1:-0})

  if [[ ${#netmask[@]} -eq 1 ]]; then
    netmask=($(ipv4_netmask "${1:-0}"))
  fi

  for i in "${!netmask[@]}"; do
    if [[ ${netmask[$i]} -lt 0 || ${netmask[$i]} -gt 255 ]]; then
      echo "Network mask should not have any octet lower than 0 and greater than 255" 1>&2
      return 1
    fi
    netmask["$i"]=$(( 255 - netmask[i] ))
  done

  echo "${netmask[*]}"
}

ipv4_bits_to_mask() {
  local mask=0 bits="${1:-0}"

  if [[ $bits -lt 0 || $bits -gt 8 ]]; then
    echo "Invalid number of bits"
    return 1
  fi

  while [[ $bits -gt 0 ]]; do
    mask=$(( ( 2 ** ( 8 - bits ) ) + mask ))
    bits=$(( bits - 1 ))

    if [[ $mask -lt 0 ]]; then
      echo "Invalid mask?" 1>&2
      return 1
    fi
  done

  echo "$mask"
}

ipv4_mask_to_bits() {
  local bits=0 mask="${1:-0}"
  if [[ $mask -gt 255 || $mask -lt 0 ]]; then
    echo "Octet should be between 0 and 255" 1>&2
    return 1
  fi

  while [[ $mask -gt 0 ]]; do
    bits=$(( bits + 1 ))
    mask=$(( mask - ( 2 ** ( 8 - bits ) ) ))

    if [[ $mask -lt 0 ]]; then
      echo "Invalid mask" 1>&2
      return 1
    fi
  done

  echo "$bits"
}

ipv4_bits() {
  local IFS='.' bits=0 total_bits=0 netmask

  netmask=(${1:-0.0.0.0})

  if [[ ${#netmask[@]} -eq 1 && ${netmask[0]} -ge 0 && ${netmask[0]} -le 32 ]]; then
    echo "${1:-0}"
    return
  elif [[ ${#netmask[@]} -ne 4 ]]; then
    echo "Network mask should have 4 octetts" 1>&2
    return 1
  fi

  for i in "${!netmask[@]}"; do
    if [[ ${netmask[$i]} -lt 0 || ${netmask[$i]} -gt 255 ]]; then
      echo "Network mask should not have any octet lower than 0 and greater than 255" 1>&2
      return 1
    fi
    bits=0

    while [[ ${netmask[$i]} -gt 0 ]]; do
      bits=$(( bits + 1))
      netmask[$i]=$(( netmask[i] - ( 2 ** ( 8 - bits ) ) ))
      
      if [[ netmask[$i] -lt 0 ]]; then
        echo "Invalid mask" 1>&2
        return 1
      fi
    done
    total_bits=$(( total_bits + bits ))
  done

  echo "$total_bits"
}

validateIPCIDR() {
  echo "$1" | grep -E -q "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\/(3[0-2]|[0-2]?[0-9]{1})?)$"
}

validateCIDR() {
  echo "$1" | grep -E -q "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(3[0-2]|[0-2]?[0-9]{1})$"
}

validateIP() {
  echo "$1" | grep -E -q "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
}

ipGetMask() {
  local bits
  bits="$(echo "$1" | grep -E -o "(\/(3[0-2]|[0-2]?[0-9]{1})?)$" || echo "/-1")"
  bits="${bits:1}"

  if [[ $bits -ge 0 && $bits -le 32 ]]; then
    echo "$bits"
  fi
}

startWG() {
  local -r interface="${3:-${VPN_SERVER_WG0:-wg0}}"
  local -r file="${2:-${VPN_SERVER_CONFIG_FILE:-/etc/wireguard/${interface}.conf}}"
  local -r server_ip="${1:-${VPN_SERVER_IP:-10.0.0.1}}"
  wg-quick up "$file"
  ip link add dev "$interface" type wireguard || echo "Wireguard interface already exists"
  ip address add dev "$interface" "${server_ip}/32" || echo "Interface address was not added"
  ip route add "${server_ip}/32" dev "${interface}" || echo "Route to ${server_ip} was not added"
  # register_peers_routes
}

stopWG() {
  local -r interface="${3:-${VPN_SERVER_WG0:-wg0}}"
  local -r file="${2:-${VPN_SERVER_CONFIG_FILE:-/etc/wireguard/${interface}.conf}}"
  local -r server_ip="${1:-${VPN_SERVER_IP:-10.0.0.1}}"
  wg-quick down "$file" || true
  ip link delete dev "$interface" type wireguard || true
  ip address delete dev "$interface" "${server_ip}/32" || true
  ip route delete "${server_ip}/32" dev "${interface}" || true
}

register_route() {
  local cidr
  local -r gateway="${1:-}"

  if ! validateIP "$gateway"; then
    echo "Needs a valid gateway" 1>&2
    return 1
  fi
  shift

  if [[ $# -eq 0 ]]; then
    echo "Needs to specify at least one valid cidr to route" 1>&2
    return 1
  fi

  for cidr in "${@}"; do
    if ! validateCIDR "$cidr"; then
      echo "Needs a valid CIDR" 1>&2
      return 1
    fi

    ip route add "$cidr" via "$gateway"
  done
}

# Nees variables PEERS_IP & NETWORKS_CONFIG_${i}
register_peers_routes() {
  local i=0 array_name="" routes=()
  for peer_ip in "${PEERS_IP[@]}"; do
    if ! validateIP "$peer_ip"; then
      echo "Peer IP '$peer_ip' is invalid ip address"
    fi

    array_name="NETWORKS_CONFIG_${i}"
    
    if [[ -n "${!array_name:-}" ]]; then
      routes=($(eval "echo \${${array_name}[@]}"))
      register_route "$peer_ip" "${routes[@]}"
    fi
    i=$(( i + 1 ))
    routes=()
    array_name=""
  done
}

get_peer_index_networks() {
  local array_name="" routes=() IFS

  local -r i="${1:-}"
  local -r peer_ip="${PEERS_IP[$i]:-}"
  [[ -z "$i" || -z "$peer_ip" ]] && return

  if ! validateIP "$peer_ip"; then
    echo "Peer IP '$peer_ip' is invalid ip address" 1>&2
    return
  fi

  array_name="NETWORKS_CONFIG_${i}"
  
  if [[ -n "${!array_name:-}" ]]; then
    routes=($(eval "echo \${${array_name}[@]}"))
  fi

  if [[ ${#routes[@]} -gt 0 ]]; then
    IFS=','
    echo "${routes[*]}"
  fi
}

get_all_allowed_ips() {
  local i=0 array_name="" routes=() IFS=$' '

  for peer_ip in "${PEERS_IP[@]}"; do
    if ! validateIP "$peer_ip"; then
      echo "Peer IP '$peer_ip' is invalid ip address"
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
    IFS=','
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

  if [[ -n "$(ipGetMask "$ip_address")" ]]; then
    local -r bits="$(ipv4_bits "$(ipGetMask "$ip_address")" || echo -n)"
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

  if [[ "${is_nat:-true}" == "true" || "${is_nat:-}" == "1" ]]; then
    echo 'PersistentKeepalive = 25'
  fi

  echo "AllowedIPs = ${allowed_ips}"
  echo
}

iptables_remove_duplicates() {
  command service iptables save &> /dev/null || true
  command iptables-save | command awk '/^COMMIT$/ { delete x; }; !x[$0]++' | tee /tmp/iptables.conf &> /dev/null
  command iptables -F
  command iptables-restore < /tmp/iptables.conf
  command service iptables save &> /dev/null || true
  command service iptables restart &> /dev/null || true

  if [[ -f /tmp/iptables.conf ]]; then
    command rm -f /tmp/iptables.conf
  fi
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

_log () {
  if [[ $# -gt 0 ]]; then
    printf "%s\n" "$@" | tee -a "${LOG_FILE:-${HOME}/wireguard-setup.log}" &> /dev/null
  fi
  
  if [[ ! -t 0 ]]; then
    printf "%s\n" "$(< /dev/stdin)" | tee -a "${LOG_FILE:-${HOME}/wireguard-setup.log}"
  fi

  echo | tee -a "${LOG_FILE:-${HOME}/wireguard-setup.log}" &> /dev/null
}

_log_exec() {
  echo "$*" | _log "Executing command" &> /dev/null
  "$@" 2>&1 | _log "Command output"
  echo "End of command execution" | _log &> /dev/null
}
