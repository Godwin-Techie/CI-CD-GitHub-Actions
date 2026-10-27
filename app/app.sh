#!/usr/bin/env bash

# Show the application's commands and their required arguments.
show_help() {
    cat <<'HELP'
Usage:
  ./app/app.sh system-info
  ./app/app.sh check-host <host>
  ./app/app.sh check-port <host> <port>
  ./app/app.sh help
HELP
}

# Invalid commands and arguments must use exit code 2.
invalid_input() {
    printf 'Error: %s\n\n' "$1" >&2
    show_help >&2
    exit 2
}

# Resolve a hostname or IP address and print its first resolved address.
resolve_host() {
    local host=$1
    local addresses
    local address

    if ! addresses=$(getent ahosts "$host" 2>/dev/null); then
        printf 'Error: could not resolve host: %s\n' "$host" >&2
        return 1
    fi

    address=$(awk 'NR == 1 { print $1; exit }' <<< "$addresses")
    if [[ -z $address ]]; then
        printf 'Error: no address found for host: %s\n' "$host" >&2
        return 1
    fi

    printf '%s\n' "$address"
}

# Accept hostname, IPv4-like, and IPv6-like characters; reject shell
# metacharacters, whitespace, empty labels, and malformed DNS labels.
validate_host() {
    local host=$1
    local label
    local -a labels

    if (( ${#host} == 0 || ${#host} > 253 )); then
        return 1
    fi

    if [[ $host == *:* ]]; then
        [[ $host =~ ^[A-Fa-f0-9:.]+$ ]]
        return
    fi

    if [[ ! $host =~ ^[A-Za-z0-9.-]+$ ]]; then
        return 1
    fi

    IFS='.' read -r -a labels <<< "$host"
    for label in "${labels[@]}"; do
        if [[ -z $label || ${#label} -gt 63 ||
              ! $label =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
            return 1
        fi
    done
}

# The command name is required. Remove it so each command can validate
# only the arguments that belong to it.
if (( $# == 0 )); then
    invalid_input "a command is required"
fi

command_name=$1
shift

case "$command_name" in
    help)
        if (( $# != 0 )); then
            invalid_input "'help' does not accept additional arguments"
        fi
        show_help
        ;;

    system-info)
        if (( $# != 0 )); then
            invalid_input "'system-info' does not accept additional arguments"
        fi

        # Read system details at runtime; do not rely on fixed machine values.
        printf 'Hostname: %s\n' "$(hostname)"
        printf 'Operating system: %s\n' "$(uname -s)"
        printf 'Kernel version: %s\n' "$(uname -r)"
        printf 'Architecture: %s\n' "$(uname -m)"
        printf 'Uptime: %s\n' "$(uptime -p 2>/dev/null || uptime)"

        if command -v free >/dev/null 2>&1; then
            printf 'Memory:\n'
            free -h
        else
            printf 'Error: required command is missing: free\n' >&2
            exit 1
        fi
        ;;

    check-host)
        if (( $# != 1 )); then
            invalid_input "'check-host' requires exactly one host"
        fi

        host=$1
        if ! validate_host "$host"; then
            invalid_input "host is not a valid hostname or IP address"
        fi

        if ! address=$(resolve_host "$host"); then
            exit 1
        fi

        printf 'Host: %s\n' "$host"
        printf 'Resolved address: %s\n' "$address"

        if ! command -v ping >/dev/null 2>&1; then
            printf 'Error: required command is missing: ping\n' >&2
            exit 1
        fi

        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            printf 'Connectivity: reachable\n'
        else
            printf 'Error: host did not respond to ping: %s\n' "$host" >&2
            exit 1
        fi
        ;;

    check-port)
        if (( $# != 2 )); then
            invalid_input "'check-port' requires a host and a port"
        fi

        host=$1
        port=$2

        if ! validate_host "$host"; then
            invalid_input "host is not a valid hostname or IP address"
        fi

        if [[ ! $port =~ ^[0-9]+$ ]]; then
            invalid_input "port must be an integer from 1 to 65535"
        fi

        # Strip leading zeroes and limit the length before arithmetic.
        while [[ ${#port} -gt 1 && ${port:0:1} == 0 ]]; do
            port=${port#0}
        done

        if (( ${#port} > 5 )); then
            invalid_input "port must be an integer from 1 to 65535"
        fi

        port_value=$((10#$port))
        if (( port_value < 1 || port_value > 65535 )); then
            invalid_input "port must be an integer from 1 to 65535"
        fi

        if ! address=$(resolve_host "$host"); then
            exit 1
        fi

        printf 'Host: %s\n' "$host"
        printf 'Resolved address: %s\n' "$address"

        # timeout prevents a non-responsive TCP connection from hanging.
        if timeout 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ \
            "$host" "$port_value" 2>/dev/null
        then
            printf 'TCP port %s: reachable\n' "$port_value"
        else
            printf 'Error: TCP port %s is not reachable on %s\n' \
                "$port_value" "$host" >&2
            exit 1
        fi
        ;;

    *)
        invalid_input "unknown command: $command_name"
        ;;
esac