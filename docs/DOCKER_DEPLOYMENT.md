# Docker deployment guide — Medveris supporting services

This document describes how the Kamatera VPS hosts Dockerized supporting
services for Medveris, and how deployments are controlled safely.

## Scope

This deployment covers supporting infrastructure only:

- Docker Engine and Docker Compose
- Ollama
- n8n, with its own dedicated PostgreSQL container
- A private Docker network between n8n and its database

It does **not** cover Medveris application hosting. Medveris continues to run
on Cloudflare, and Neon PostgreSQL remains the production database source of
truth.

## Architecture summary

- VPS: `medveris`, `113.30.188.181`, Ubuntu 26.04.1 LTS
- Native PostgreSQL 18.6 is preserved and not used by n8n
- Deployment target: `/opt/medveris/compose/`
- Compose file: `docker/compose.yml` in this repository
- Environment file: `/opt/medveris/compose/.env` (VPS only, not in Git)

## Privilege model

The deployment privilege model is intentionally narrow.

### What the GitHub runner does

- The self-hosted runner runs as the unprivileged `deploy` user.
- The runner checks out `main` and executes the deployment workflow.
- The workflow only deploys the fixed Compose project to the fixed directory
  `/opt/medveris/compose/`.
- The workflow does not run arbitrary shell commands, arbitrary paths, or
  host-wide operations.

### What the runner must still be able to do

Docker Compose deployment requires Docker access. There are two common ways to
provide that:

1. Add `deploy` to the `docker` group.
2. Use a narrow root-owned deployment wrapper via sudo.

### Docker group risk

Membership in the `docker` group is effectively root-equivalent access on the
host. It allows containerized privilege escalation in many configurations.

Because of that, `deploy` must **not** be added to the `docker` group without
explicit approval and an explicit understanding of the consequence.

If Docker access is granted to the runner account, the following controls should
be in place:

- The runner is restricted to `main` only.
- The runner is restricted to `[self-hosted, kamatera]`.
- Untrusted pull-request workflows must never run on this runner.
- Repository write access and workflow changes must be protected.
- The deployment workflow must remain limited in scope.

### Narrow deployment wrapper design

A safer alternative is a small root-owned deployment wrapper that exposes only
a fixed set of operations. This repository documents the intended design, but
the wrapper is **not installed here** and sudoers is **not modified here**.

Intended wrapper contract:

- Exact executable path on the host, root-owned, with protected parent
  directories.
- Accepts only fixed operations such as:
  - `deploy`
  - `status`
  - `verify`
  - `rollback`
- Rejects arbitrary arguments and arbitrary commands.
- Uses fixed paths only.
- Validates the Compose configuration before deployment.
- Performs a safe pre-deployment configuration backup.
- Never deletes persistent volumes.
- Never runs broad Docker prune commands.
- Never modifies host firewall, SSH, native PostgreSQL, or system services.

If this wrapper is implemented later, the sudoers entry should use the exact
executable path and should not allow broad commands such as `/bin/bash`,
`/usr/bin/env`, `systemctl` with arbitrary arguments, or unrestricted
`/usr/bin/docker`.

## Deployment procedure

### 1. Privileged provisioning (administrator only)

Docker does not exist on the VPS yet. Installing Docker and configuring the host
requires authenticated administrator privileges.

These operations should be performed through an authenticated SSH session with a
TTY, not through the GitHub Actions runner and not through non-interactive sudo
without approval.

Approved administrative approach:

- Use an interactive SSH session with sudo using a TTY.
- Run reviewed provisioning commands manually.
- Do not embed sudo passwords in scripts, environment variables, GitHub secrets,
  or workflow files.

### 2. Deploy the Compose release

After Docker is installed and the deployment path is available, the deployment
flow is:

1. Generate required secrets on the VPS with a secure random source.
2. Write `/opt/medveris/compose/.env` with restrictive permissions.
3. Run `docker compose config` validation.
4. Deploy with the release compose file.
5. Verify service health.
6. Confirm exposed ports are still localhost-only.

The GitHub Actions workflow implements this flow for repeatable deployments from
`main`, with an explicit confirmation gate and a safe rollback path.

### 3. Verification

After deployment, verify:

- Compose project is up.
- Ollama is bound to `127.0.0.1:11434` only.
- n8n is bound to `127.0.0.1:5678` only.
- n8n database port is not published.
- Persistent volumes exist.
- Native PostgreSQL 18.6 is unchanged.
- UFW remains SSH-only for inbound by default.

## Image pinning and validation

All images in `docker/compose.yml` are pinned. Do not use `:latest`.

The deployment workflow enforces image pinning in two places:

- A direct check for `:latest` in `docker/compose.yml`.
- A pin-policy check driven by `.github/workflows/pin-policy.json`.

The pin policy requires:

- An explicit tag on every image.
- Only allow-listed registries and image prefixes.
- No `:latest`.

Current policy files:

- `.github/workflows/pin-policy.json`
- `.github/workflows/pin-policy.yml`

To update a service:

1. Choose the new pinned tag.
2. If the new image is from an already-allow-listed registry and prefix,
   update `docker/compose.yml` only.
3. If the new image needs a new registry, prefix, or tag pattern, update
   `.github/workflows/pin-policy.json` first and review it.
4. Validate the compose file locally or in CI before deploy.
5. Deploy from `main` through the workflow.
6. Verify after deployment.

Keep a short change note for image updates so rollbacks and audits are easier.

## Secrets

Required Compose secrets must be generated on the VPS with a secure random
source.

Example generation commands:

```bash
N8N_DB_PASSWORD="$(openssl rand -base64 24)"
N8N_ENCRYPTION_KEY="$(openssl rand -base64 32)"
```

Write them into `/opt/medveris/compose/.env` and restrict permissions:

```bash
chmod 600 /opt/medveris/compose/.env
```

Never commit `.env` files. Never paste real secrets into workflow logs.

## Firewall and network boundaries

By default, the VPS should keep inbound access restricted. SSH is the only
approved public inbound service for this stage.

Do not open the following without explicit approval:

- PostgreSQL port 5432
- Ollama port 11434
- n8n port 5678
- Docker API

Do not change SSH authentication policy without a verified recovery path and
explicit approval.

## Rollback

If a deployment needs to be reverted:

- Stop and remove the Compose project containers and networks.
- Preserve persistent volumes.
- Restore the previous compose configuration from the deployment backup if
  needed.

Do not use `docker compose down -v` and do not delete volumes as a routine
rollback step.

## Remaining approvals

Before this foundation becomes fully operational, the following approvals are
still required:

- Docker installation and service enablement on the VPS.
- A decision on Docker access for the runner account.
- Any decision to open ports publicly.
- Any decision to change SSH or firewall policy.
- Any decision to enable passwordless sudo, which is not required by default
  for this design.
