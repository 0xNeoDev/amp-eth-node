# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this project, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, email security@edgeandnode.com with:

1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a timeline for resolution.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | Yes |
| Previous release | Security fixes only |
| Older | No |

## Security Considerations

### Default Credentials

The `.env` file ships with default credentials for development convenience. **You must change these for production:**

- `POSTGRES_PASSWORD` — default: `amp`
- `GRAFANA_ADMIN_PASSWORD` — default: `admin`

Set strong, unique passwords in `.env.local` before deploying.

### Network Exposure

By default, services bind to `0.0.0.0` inside Docker. The production overlay (`docker-compose.prod.yml`) restricts RPC and metrics endpoints to `127.0.0.1`. If you need remote access, use a reverse proxy with TLS and authentication.

### JWT Secret

The JWT secret (`jwt/jwt.hex`) authenticates the consensus-execution client connection. It is excluded from git. Protect this file:

```bash
chmod 600 jwt/jwt.hex
```

### RPC API Surface

The base configuration exposes a minimal RPC API set (`eth,net,web3,txpool`). The development overlay enables `debug` and `trace` APIs for testing. Never expose debug APIs in production.

### Container Security

The production overlay applies:
- `no-new-privileges` — prevents privilege escalation
- Bind to `127.0.0.1` — restricts network exposure
- Log rotation — prevents disk exhaustion from logs
- Resource limits — prevents OOM from affecting the host

### Pre-flight Checks

Run `just preflight` before production deployment to validate credentials, permissions, disk space, and port availability.
