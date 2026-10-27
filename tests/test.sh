#!/usr/bin/env bash

# Run each test independently so expected error cases do not stop the suite.
set -uo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
APP="$SCRIPT_DIR/app/app.sh"
failures=0

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

# Check a command's exit code and, when provided, required output text.
check() {
    local description=$1
    local expected_status=$2
    local expected_text=$3
    shift 3

    local output
    local actual_status

    if output=$("$APP" "$@" 2>&1); then
        actual_status=0
    else
        actual_status=$?
    fi

    if (( actual_status == expected_status )) &&
        [[ -z $expected_text || $output == *"$expected_text"* ]]
    then
        pass "$description"
    else
        fail "$description (expected exit $expected_status and output containing '$expected_text'; got exit $actual_status)"
        printf '%s\n' "$output" >&2
    fi
}

check "help displays usage" 0 "Usage:" help
check "system-info displays hostname" 0 "Hostname:" system-info
check "unknown command returns exit code 2" 2 "Error:" not-a-command
check "missing command returns exit code 2" 2 "Error:"
check "check-host rejects a missing host" 2 "Error:" check-host
check "check-host resolves and reaches localhost" 0 "Resolved address:" check-host localhost
check "check-port rejects a missing port" 2 "Error:" check-port localhost
check "check-port rejects a non-numeric port" 2 "Error:" check-port localhost abc
check "check-port rejects an out-of-range port" 2 "Error:" check-port localhost 65536

if (( failures > 0 )); then
    printf '\nTests failed: %d\n' "$failures" >&2
    exit 1
fi

printf '\nAll application tests passed.\n'
