#!/usr/bin/env bash
#shellcheck disable=SC2206,SC2207,SC2016

# Return true if it is: true, 1 yes, y, on or enable
_check_true() {
  [[ ${1:-} == true || ${1:-} == 1 || ${1:-} == yes || ${1:-} == y || ${1:-} == on || ${1:-} == enable ]]
}

# Return false if it is: false, 0 no, n, off or disable
_check_false() {
  ! [[ ${1:-} == false || ${1:-} == 0 || ${1:-} == no || ${1:-} == n || ${1:-} == off || ${1:-} == disable ]]
}

_w() {
  echo "$*"
}

_info() {
  _w "$*" >&2
}

_i() {
  _info "$*"
}

_warn() {
  _info "WARNING: $*" | _log "== FATAL ERROR =="
  _log "WARNING: $*"
  exit 4
}

_debug() {
  _check_true "${DEBUG:-false}" && _info "$*"
}

_d() {
  _debug "$*"
}

_log () {
  if [[ $# -gt 0 ]]; then
    printf "%s\n" "$@" | tee -a "${LOG_FILE:-${HOME}/wireguard-setup.log}" &> /dev/null
  fi

  _debug "$@"
  
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

_set() {
  local -r var_name="${1:-}"
  [[ -z "${var_name}" ]] && _warn "No variable name provided"
  shift
  _debug "Setting var '${var_name}' to the value(s) '$*'"
  if [[ $# -gt 1 ]]; then
    eval "${var_name}=(${*})"
  else
    eval "${var_name}=\"${1:-\"\"}\""
  fi
}

_s() {
  _set "$@"
}

_set_secret() {
  local -r var_name="${1:-}"
  [[ -z "${var_name}" ]] && _warn "No variable name provided"
  shift
  _debug "Setting var '${var_name}'"
  if [[ $# -gt 1 ]]; then
    eval "${var_name}=(${*})"
  else
    eval "${var_name}=${1:-}"
  fi
}

_ss() {
  _set_secret "$@"
}

_unset() {
  [[ $# -eq 0 ]] && return
  _d "Unsetting var(s) $(printf "%s " "$@")"
  unset "$@"
}

_u() {
  _unset "$@"
}

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
