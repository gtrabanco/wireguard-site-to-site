#!/usr/bin/env bash

# Usage examples:
#
#   1. Allow port 80 for VPN nodes
#     $ . .env
#     $ ./fw-open.sh 80 10.1.1.0/24
#   2. Allow port 22 for just a VPN node with IP 10.1.1.3
#     $ . .env
#     $ ./fw-open.sh 22 10.1.1.3
#   3. Allow port 53 udp for all nodes & public IPs
#     $ ./fw-open.sh 53 udp
#   4. Disallow port 22 for specific node
#     $ ./fw-open.sh 22 10.1.1.5 DROP
#
# IMPORTANT:
# You can't disallow a port connection for all networks that are behind a node
#  that must be done in the gateway. The server will see the peer ip and not
#  the local ip. Keep this in mind when you use this script.

if [[ " $* " ==  *" --help "* ]]; then
  grep '^#' "$0" | cut -c3- | tail -n +2
  exit
fi

. "$(dirname "$BASH_SOURCE")/networking.bash"

get_rule() {
  local rule="iptables -A" is_ipv6=false
  [[ $# -eq 0 ]] && return 1

  while [[ $# -gt 0 ]]; do
    if [[ $1 =~ ^[0-9]+$ ]]; then
      local -r dport="$1"
      shift
    elif validate_ipv6 "$1" || validate_ipv6_cidr "$1"; then
      is_ipv6=true
      local -r ip="$1"
      shift
    elif validate_ipv4 "$1" || validate_ipv4_cidr "$1"; then
      local -r ip="$1"
      shift
    elif [[ $1 == "tcp" || $1 == "udp" ]]; then
      local -r proto="$1"
      shift
    elif [[ $1 == "INPUT" || $1 == "OUTPUT" || $1 == "FORWARD" ]]; then
      local -r chain="$1"
      shift
    elif [[ $1 == "ACCEPT" || $1 == "DROP" || $1 == "REJECT" ]]; then
      local -r action="$1"
      shift
    else
      echo "Invalid argument: $1"
      return 1
    fi
  done

  if ${is_ipv6}; then
    rule="ip6tables -A"
  fi

  rule="${rule} ${chain:-INPUT} -p ${proto:-tcp}"

  if [[ -n "${dport:-}" ]]; then
    rule="${rule} --dport $dport"
  fi

  if [[ -n "${ip:-}" ]]; then
    rule="${rule} -s $ip"
  fi

  rule="${rule} -j ${action:-ACCEPT}"

  echo "$rule"
}

get_rule "$@"