#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC2016

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



validate_ipv4_cidr() {
  [[ ${1:-} =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(3[0-2]|[0-2]?[0-9]{1})$ ]]
}

validate_ipv6_cidr() {
  [[ ${1:-} =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}\/(12[0-8]|1[0-1][0-9]|[0-9]?[0-9]{1})$ ]]
}

validate_ip_cidr() {
  validate_ipv4_cidr "${1:-}" || validate_ipv6_cidr "${1:-}"
}

validate_ipv4() {
  [[ "${1:-}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]
}

validate_ipv6() {
  [[ ${1:-} =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]
}

validate_ip() {
  validate_ipv4 "${1:-}" || validate_ipv6 "${1:-}"
}

ip_get_mask() {
  local bits
  bits="$(echo "${1:-}" | grep -E -o "(\/(3[0-2]|[0-2]?[0-9]{1})?)$" || echo "/-1")"
  bits="${bits:1}"

  if [[ $bits -ge 0 && $bits -le 128 ]]; then
    echo "$bits"
  fi
}

start_wireguard() {
  local -r interface="${3:-${VPN_SERVER_WG0:-wg0}}"
  local -r file="${2:-${VPN_SERVER_CONFIG_FILE:-/etc/wireguard/${interface}.conf}}"
  local -r server_ip="${1:-${VPN_SERVER_IP:-10.0.0.1}}"
  wg-quick up "$file"
  ip link add dev "$interface" type wireguard || echo "Wireguard interface already exists"
  ip address add dev "$interface" "${server_ip}/32" || echo "Interface address was not added"
  ip route add "${server_ip}/32" dev "${interface}" || echo "Route to ${server_ip} was not added"
}

stop_wireguard() {
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

  if ! validate_ip "$gateway"; then
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

iptables_remove_duplicates() {
  if
    ! command -v service &>/dev/null ||
    ! command -v iptables &>/dev/null ||
    ! command -v iptables-save &>/dev/null ||
    ! command -v iptables-restore &>/dev/null
  then
    _info "Any iptables command does not exist or could not be found" | _log
    return
  fi

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

get_network_cidr() {
  local octects final_ip=()
  if validate_ipv4_cidr "${1:-}"; then
    local -r ip="$(echo "${1:-}" | awk -F '/' '{print $1}')"
    local -r netmask="$(echo "${1:-}" | awk -F '/' '{print $2}')"
    [ "$netmask" -ge 0 ] && [ "$netmask" -le 32 ] || return
  elif validate_ipv4 "${1:-}" && [[ ${2:-} -ge 0 && ${2:-} -le 32 ]]; then
    local -r ip="${1:-}"
    local -r netmask="${2:-}"
  else
    #echo "Needs a valid IPv4 address and netmask" 1>&2
    return
  fi

  octects=($(echo "$ip" | tr '.' '\n'))

  local -r full_octects=$(( netmask / 8))
  local -r reminder_bits=$(( netmask % 8 ))
  local -r last_octect="${octects[$(( full_octects + 1))]}"
  local -r net_octect="$(( reminder_bits > 0 ? (last_octect / ( 2 ** ( 8 - reminder_bits ))) * (2 ** ( 8 - reminder_bits )) : 0 ))"

  local IFS='.'

  while [ ${#final_ip[@]} -le $full_octects ]; do
    final_ip+=("${octects[${#final_ip[@]}]}")
  done

  final_ip+=($net_octect)

  while [[ ${#final_ip[@]} -lt 4 ]]; do
    final_ip+=(0)
  done

  echo "${final_ip[*]:1}/${netmask}"
}
