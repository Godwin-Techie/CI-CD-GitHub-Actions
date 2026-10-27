# CI/CD with GitHub Actions

A Bash diagnostic application with automated tests, Docker packaging, and a GitHub Actions workflow. The workflow validates the scripts, runs the application tests, then builds and smoke-tests the Docker image. There is no cloud deployment.

## Requirements

- Linux with Bash
- Docker and Docker Compose for local image checks
- Git for version control
- A GitHub repository to run the Actions workflow

## Application commands

Run these from the project root:

```bash
./app/app.sh help
./app/app.sh system-info
./app/app.sh check-host localhost
./app/app.sh check-port localhost 22
```

- `system-info` displays runtime system information.
- `check-host <host>` resolves a host and attempts to ping it.
- `check-port <host> <port>` validates the port and attempts a TCP connection.
- `help` displays usage.

Exit codes:

- `0` - command completed successfully.
- `1` - an operational check failed.
- `2` - command or input is invalid.

A host may resolve but not respond to ping. TCP checks may also fail if the port is closed or blocked.

## Local validation

Make the scripts executable:

```bash
chmod +x app/*.sh scripts/*.sh tests/*.sh grade.sh
```

Run the lint checks and application tests:

```bash
./scripts/lint.sh
./tests/test.sh
```

Build the Docker image and run its smoke tests:

```bash
./scripts/build.sh
```

Run all local grading checks:

```bash
./grade.sh
```

The grader checks required files, Bash syntax and permissions, workflow triggers and job dependencies, application tests, and Docker build/smoke tests.

## Docker usage

Build and run the image directly:

```bash
docker build -t devops-tool .
docker run --rm devops-tool help
docker run --rm devops-tool system-info
```

Or use Docker Compose:

```bash
docker compose run --rm devops-tool help
docker compose run --rm devops-tool system-info
```

## GitHub Actions workflow

The workflow is in `.github/workflows/ci.yml`. It runs on pushes and pull requests with these dependent jobs:

1. `validate` runs the project linter.
2. `test` runs after `validate` succeeds.
3. `docker` runs after `test` succeeds and builds and smoke-tests the image.

## CI failure demonstration

To demonstrate CI failure handling, make a temporary branch, introduce a deliberate syntax error or failing test, and push the branch to GitHub. Confirm that the Actions run fails. Then remove the deliberate failure, push the correction, and confirm the final workflow passes. Do not leave the intentional failure in the final branch.

## Assumptions

- The network tests use `localhost` so they do not depend on an external host being reachable.
- `check-host` uses DNS resolution and ICMP ping; network policy may block ping.
- `check-port` needs the selected host and TCP port to be reachable.
- Docker must be running for image builds and Docker smoke tests.

## Submission

Do not commit passwords, tokens, private keys, or other secrets. Before submitting, clone the repository into a clean directory and run `./grade.sh`.
