# Topology and security — Medveris supporting services

## Overall topology

Medveris uses two hosting platforms:

- Cloudflare hosts the Medveris application, Workers, backend, authentication,
  and application integrations.
- Kamatera hosts supporting infrastructure for the Medveris repository:
  - Native PostgreSQL 18.6
  - Docker Engine and Docker Compose
  - Ollama
  - n8n with its own dedicated PostgreSQL container

Neon PostgreSQL remains the existing Medveris production database source of
truth. This foundation does not migrate databases or redirect production
traffic.

## Kamatera VPS baseline

- Hostname: `medveris`
- Public IP: `113.30.188.181`
- OS: Ubuntu 26.04.1 LTS
- Resources: 4 vCPU, 8 GB RAM, 150 GB disk

## Deployment components

### Self-hosted GitHub Actions runner

- Runner name: `medveris-runner`
- Labels: `self-hosted`, `kamatera`
- User: `deploy`
- Directory: `/home/deploy/actions-runner/`
- Service: `actions.runner.Aidomex-Group-Ltd-kamatera-medveris.medveris-runner.service`

The runner is intended to be persistent and managed as a systemd service running
as `deploy`.

### Docker deployment target

- Deployment directory: `/opt/medveris/compose/`
- Compose file: `docker/compose.yml`
- Runtime environment: `/opt/medveris/compose/.env`

The runtime environment file is host-local and excluded from Git.

## Trust boundaries

### Private by default

The following are private in this deployment and must not be published without
explicit approval:

- PostgreSQL port 5432
- Ollama port 11434
- n8n port 5678
- Docker API

### SSH

SSH on port 22 is the only approved public inbound service for this stage.

Do not change SSH authentication policy without a verified recovery path and
explicit approval.

### Database authority

- Neon PostgreSQL remains the production database source of truth.
- The native Kamatera PostgreSQL 18.6 cluster must be preserved.
- n8n must use its own dedicated PostgreSQL container.
- Do not create a new `medveris_prod` database in the native cluster.
- Do not create n8n roles or databases in the native cluster.

### Secrets

Secrets are host-local and generated on the VPS.

Do not:
- Commit `.env` files
- Print secrets in workflow logs
- Transfer credentials through workflow output
- Reuse Medveris production database credentials for n8n

## Runner security

The self-hosted runner can execute commands with the permissions of the
`deploy` account. Protect:

- Repository write access
- Workflow modifications
- Branch protection
- Runner label assignment

Do not run untrusted pull-request workflows on this runner.

## Deployment control plane

The deployment workflow in this repository is intentionally narrow:

- `workflow_dispatch` only
- `main` branch only
- Runs only on `[self-hosted, kamatera]`
- Least-privilege GitHub token permissions
- Concurrency control
- Explicit human confirmation gate
- Validate before deploy
- Verify after deploy
- Safe rollback without volume deletion

## Remaining approvals

The following are not granted automatically:

- Docker installation and service enablement on the VPS
- Docker access for the runner account
- Any public exposure of 5432, 11434, or 5678
- Any SSH or firewall policy changes
- Any passwordless sudo configuration
- Any reboot

## Non-negotiable safety rules

- No unrestricted passwordless sudo
- No root-run GitHub Actions runner
- No public PostgreSQL
- No public Ollama
- No public n8n
- No production database migration
- No production Cloudflare changes
- No deletion of existing PostgreSQL data
- No deletion of Docker volumes
- No reboot without approval
- No secrets in Git, logs, or reports
