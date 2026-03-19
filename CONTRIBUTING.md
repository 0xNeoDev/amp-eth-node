# Contributing

Thank you for your interest in amp-eth-node. This project serves as the reference implementation for running Amp with a co-located Ethereum node. Other teams and developers depend on this repository for their own setups, so we maintain a high bar for changes.

## Getting Started

1. Fork and clone the repo
2. Run `just setup` to initialize
3. Run `just up-dev` to start a Sepolia development stack
4. Make your changes
5. Run `just status` to verify everything still works

## Pull Requests

- Keep PRs focused — one concern per PR
- All shell scripts must pass `shellcheck`
- All YAML must pass `yamllint -d relaxed`
- All TOML must be valid
- Docker Compose files must pass `docker compose config --quiet`
- Test your changes on both macOS (dev) and Linux (prod) if possible

## What We Accept

- Bug fixes
- Security improvements
- Performance improvements with benchmarks
- New Grafana dashboards
- Documentation improvements
- New Amp manifests for Ethereum data

## What Needs Discussion First

Open an issue before submitting PRs for:

- New services in docker-compose
- Changes to the IPC socket architecture
- Changes to the version pinning strategy
- Breaking changes to the justfile interface
- New external dependencies

## Versioning

All Docker image tags are pinned in `.env`. When updating versions:

1. Update the pin in `.env`
2. Test with `just up-dev` and `just status`
3. Run `just bench` if performance-sensitive
4. Document any migration steps in the PR

## Code Style

- Shell scripts: follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `set -euo pipefail` in all bash scripts
- YAML: 2-space indent
- TOML: follow existing patterns in `config/`

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.
