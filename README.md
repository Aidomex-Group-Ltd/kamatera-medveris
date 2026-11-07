# Medveris Infrastructure

Infrastructure configuration and operational runbooks for the Medveris Kamatera
supporting infrastructure.

> **STATUS: Independent verification complete (2026-11-07).**
> Repository corrected. VPS state independently verified via SSH with sudo.
> See `docs/IMPLEMENTATION_LOG.md` and `docs/FINAL_INFRASTRUCTURE_STATUS.md`.

## Overview

This repository contains the infrastructure as code, automation, and operational runbooks
for the Medveris supporting infrastructure on Kamatera.

## Confirmed Architecture

### Cloudflare (Application Platform)
Cloudflare remains the Medveris application platform:
- Frontend and application hosting
- Backend/API and Workers
- Authentication and authorization
- Application routing and business logic
- Existing Cloudflare R2 services

### Kamatera VPS (Supporting Services)
The Kamatera VPS hosts supporting services:
- PostgreSQL 18 (currently an empty supporting database server; Neon is production)
- Ollama (AI inference)
- n8n (workflow automation)
- Docker Engine and Docker Compose (orchestration — **not k3s/Helm**)
- Nginx only for selected VPS-hosted services and reverse proxying
- Monitoring, logging, backup and recovery services

### Important Distinctions
- **Neon PostgreSQL** is the current Medveris production source of truth.
- **Kamatera PostgreSQL** is a supporting database server (currently empty).
- Production traffic is **not** redirected to Kamatera.
- Terraform and Ansible are infrastructure-management tools operated from WSL, not VPS services.
- **Docker Compose** is the approved orchestration approach. No k3s, Helm, or containerd.

## Verified VPS Baseline

| Item | Value |
|------|-------|
| Host | 113.30.188.181 |
| Hostname | medveris |
| OS | Ubuntu 26.04.1 LTS (Resolute Raccoon) |
| Kernel | 7.0.0-38-generic |
| Resources | 4 vCPU, 8 GB RAM (7.3Gi), 150 GB disk (148G usable) |
| Region | Amsterdam, Netherlands |
| PostgreSQL | 18.6 (online, localhost:5432, accepting connections) |
| PostgreSQL listen | localhost (commented out, defaults to localhost) |
| PostgreSQL auth | scram-sha-256 (default, not overridden) |
| PostgreSQL pg_hba | VERIFIED — local=peer, host=scram-sha-256 (127.0.0.1/32, ::1/128 only) |
| PostgreSQL WAL archiving | off (not configured) |
| PostgreSQL archive_mode | off (default, commented) |
| PostgreSQL archive_command | empty (default, commented) |
| Docker | NOT installed |
| k3s/Helm/containerd | NOT installed |
| Nginx | NOT installed |
| Ollama | NOT installed |
| n8n | NOT installed |
| Fail2ban | NOT installed |
| UFW | ACTIVE — default deny incoming, allow outgoing; SSH allowed on IPv4+IPv6 |
| SSH | OpenSSH 10.2p1 — PermitRootLogin=YES, PasswordAuth=YES (NOT hardened) |
| SSHD drop-in | EMPTY (no /etc/ssh/sshd_config.d/*.conf) |
| Swap | none |
| RAM available | 6.6Gi |
| Disk available | 138G (3% used) |

See `docs/IMPLEMENTATION_LOG.md` for full verification details.

## Directory Structure

```
medveris-infrastructure/
├── README.md
├── .gitignore
├── .env.example
├── docs/           # Runbooks and architecture docs
├── terraform/      # Infrastructure provisioning
├── ansible/        # Server configuration and provisioning
├── scripts/        # Operational scripts (backup, health checks, restore, discovery)
└── config/         # Configuration templates (planned)
```

## Key Directories

- `terraform/` — Infrastructure provisioning (Kamatera, Cloudflare resources)
- `ansible/` — Server hardening, package installation, service configuration
- `scripts/` — Operational scripts (backup, health checks, restore, discovery, validation)
- `docs/` — Disaster recovery, migration, security runbooks, implementation log

## Security

- Never commit SSH private keys, API keys, passwords, or database URLs
- Key-only SSH authentication (working key: `medveris_kamatera`)
- UFW firewall ACTIVE — default deny incoming, allow outgoing; SSH (TCP 22) allowed on IPv4+IPv6
- PostgreSQL bound to localhost only (verified via ss and pg_hba.conf)
- PostgreSQL authentication: local=sudo peer, TCP=scram-sha-256 for 127.0.0.1/32 and ::1/128 only
- Ollama private API binding (to be deployed in Phase 4)
- R2 credentials managed via Cloudflare secrets
- SSH NOT hardened: PermitRootLogin=yes, PasswordAuthentication=yes — needs hardening

## Implementation Phases

1. **Phase 1 — Infrastructure Configuration Safety** (in progress)
   - Reconcile documentation with actual Ubuntu 26.04.1 and PostgreSQL 18 environment
   - Correct architecture to Docker Compose
   - Review Terraform and Ansible for safety
   - Correct outdated execution guides

2. **Phase 2 — VPS Security Baseline** (pending approval)
3. **Phase 3 — Docker Engine and Compose** (pending approval)
4. **Phase 4 — Supporting Services** (pending approval)
5. **Phase 5 — Backup and Disaster Recovery** (pending approval)
6. **Phase 6 — Cloudflare Integration Assessment** (pending approval)

## Prerequisites

- Kamatera account with server provisioned (done: 113.30.188.181)
- Cloudflare account with Workers, R2, DNS (existing)
- SSH key pair for server access (verified: `~/.ssh/medveris_kamatera`)
- Terraform and Ansible installed locally (WSL)
