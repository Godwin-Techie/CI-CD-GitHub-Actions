#!/usr/bin/env bash

# Resolve the project root so the grader works from any directory.
set -uo pipefail
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
failures=0

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

# Verify the files required by the assignment are present.
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

# Check syntax and executable permissions for each Bash script.
shell_scripts=(
    app/app.sh
    scripts/lint.sh
    scripts/build.sh
    tests/test.sh
    grade.sh
)

for script in "${shell_scripts[@]}"; do
    if [[ ! -f $PROJECT_DIR/$script ]]; then
        continue
    fi

    if bash -n "$PROJECT_DIR/$script"; then
        pass "Bash syntax: $script"
    else
        fail "Bash syntax: $script"
    fi

    if [[ -x $PROJECT_DIR/$script ]]; then
        pass "executable permission: $script"
    else
        fail "not executable: $script"
    fi
done

workflow="$PROJECT_DIR/.github/workflows/ci.yml"

# Check the workflow has both required triggers and all three jobs.
if [[ -f $workflow ]]; then
    for trigger in push pull_request; do
        if grep -Eq "^[[:space:]]+$trigger:" "$workflow"; then
            pass "workflow trigger: $trigger"
        else
            fail "workflow is missing trigger: $trigger"
        fi
    done

    for job in validate test docker; do
        if grep -Eq "^[[:space:]]{2}$job:" "$workflow"; then
            pass "workflow job: $job"
        else
            fail "workflow is missing job: $job"
        fi
    done

    if grep -Eq '^[[:space:]]+needs:[[:space:]]*validate[[:space:]]*$' "$workflow" &&
       grep -Eq '^[[:space:]]+needs:[[:space:]]*test[[:space:]]*$' "$workflow"; then
        pass "workflow job dependencies"
    else
        fail "workflow must make test depend on validate and docker depend on test"
    fi
fi

# Run each project check and continue so all failures are reported.
run_check() {
    local description=$1
    shift

    if "$@"; then
        pass "$description"
    else
        fail "$description"
    fi
}

if [[ -x $PROJECT_DIR/scripts/lint.sh ]]; then
    run_check "project lint" "$PROJECT_DIR/scripts/lint.sh"
fi

if [[ -x $PROJECT_DIR/tests/test.sh ]]; then
    run_check "application test suite" "$PROJECT_DIR/tests/test.sh"
fi

if [[ -x $PROJECT_DIR/scripts/build.sh ]]; then
    run_check "Docker build and smoke tests" "$PROJECT_DIR/scripts/build.sh"
fi

# Confirm this project has Git history before submission.
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1; then
        pass "Git repository has at least one commit"
    else
        fail "Git repository has no commits yet"
    fi
else
    fail "project directory is not a Git repository"
fi

if (( failures > 0 )); then
    printf '\nGrading checks found %d issue(s).\n' "$failures" >&2
    exit 1
fi

printf '\nAll grading checks passed.\n'
