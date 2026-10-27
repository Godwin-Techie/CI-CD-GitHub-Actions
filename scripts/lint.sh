#!/usr/bin/env bash

# Resolve the project root so linting works from any current directory.
set -uo pipefail
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
failures=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

pass() {
    printf 'PASS: %s\n' "$1"
}

# List every deliverable required by the Assignment 3 structure.
required_files=(
    README.md
    app/app.sh
    scripts/lint.sh
    scripts/build.sh
    tests/test.sh
    .github/workflows/ci.yml
    Dockerfile
    compose.yaml
    .dockerignore
    grade.sh
)

for file in "${required_files[@]}"; do
    if [[ -f $PROJECT_DIR/$file ]]; then
        pass "required file exists: $file"
    else
        fail "missing required file: $file"
    fi
done

# Parse each Bash script without executing it.
shell_scripts=(
    app/app.sh
    scripts/lint.sh
    scripts/build.sh
    tests/test.sh
    grade.sh
)

for script in "${shell_scripts[@]}"; do
    if [[ ! -f $PROJECT_DIR/$script ]]; then
        # The missing-file check above already reports this case.
        continue
    fi

    if bash -n "$PROJECT_DIR/$script"; then
        pass "Bash syntax: $script"
    else
        fail "Bash syntax: $script"
    fi
done

if (( failures > 0 )); then
    printf '\nLint failed with %d issue(s).\n' "$failures" >&2
    exit 1
fi

printf '\nLint passed.\n'
