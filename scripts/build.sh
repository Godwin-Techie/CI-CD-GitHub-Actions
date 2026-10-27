#!/usr/bin/env bash

# Resolve the project root so this script works from any directory.
set -uo pipefail
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE_NAME=${IMAGE_NAME:-devops-tool}

# Report a clear error if Docker is unavailable.
if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: Docker is required to build and test the image.\n' >&2
    exit 1
fi

# Build from the project root so Docker can access the expected files.
if ! docker build -t "$IMAGE_NAME" "$PROJECT_DIR"; then
    printf 'Error: Docker image build failed.\n' >&2
    exit 1
fi

# Run a container command and verify its exit status and output.
check_command() {
    local description=$1
    local expected_status=$2
    local expected_text=$3
    shift 3

    local output
    local actual_status

    if output=$(docker run --rm "$IMAGE_NAME" "$@" 2>&1); then
        actual_status=0
    else
        actual_status=$?
    fi

    if (( actual_status == expected_status )) &&
        [[ $output == *"$expected_text"* ]]
    then
        printf 'PASS: %s\n' "$description"
    else
        printf 'FAIL: %s\n' "$description" >&2
        printf '  Expected exit code: %s; got: %s\n' \
            "$expected_status" "$actual_status" >&2
        printf '  Expected output to include: %s\n' "$expected_text" >&2
        printf '  Actual output:\n%s\n' "$output" >&2
        return 1
    fi
}

# These smoke tests verify the image's basic CLI and invalid-command behavior.
failures=0
check_command "Docker help command" 0 "Usage:" help || failures=$((failures + 1))
check_command "Docker system-info command" 0 "Hostname:" system-info || failures=$((failures + 1))
check_command "Docker invalid command returns exit code 2" 2 "Error:" invalid-command || failures=$((failures + 1))

if (( failures > 0 )); then
    printf '\nDocker smoke tests failed: %d\n' "$failures" >&2
    exit 1
fi

printf '\nDocker build and smoke tests passed.\n'
