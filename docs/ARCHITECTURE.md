# Architecture Documentation

> **STATUS: Being corrected — Phase 1 reconciliation (2026-11-07).**
> This document previously referenced Ubuntu 24.04, PostgreSQL 16, k3s/Helm, and
> described Kamatera PostgreSQL as "production primary". All of these are outdated.
> See `docs/IMPLEMENTATION_LOG.md` and the reconciliation report.

## Overview

Medveris infrastructure architecture: Cloudflare as the application platform,
Kamatera VPS for supporting services.

## Confirmed Architecture

### 1. Cloudflare (Application Platform)
Cloudflare remains the Medveris application platform:
- Frontend and application hosting
- Backend/API and Workers
- Authentication and authorization
- Application routing and business logic
- Existing Cloudflare R2 services

### 2. Kamatera VPS (Supporting Services)
- **Server:** 4 vCPU, 8 GB RAM, 150 GB disk, Amsterdam region
- **OS:** Ubuntu 26.04.1 LTS (Resolute Raccoon) — verified 2026-11-07
- **Access:** SSH key-only authentication (working key: `medveris_kamatera`)
- **Hostname:** `medveris`

### 3. Container Platform
- **Orchestration:** Docker Compose (approved; **not k3s/Helm/containerd**)
- **Runtime:** Docker Engine + Compose plugin

### 4. Database
- **Production:** Neon PostgreSQL (current source of truth — untouched)
- **Supporting:** Kamatera PostgreSQL 18.6 (empty, localhost only, already running)
- **Connectivity:** Cloudflare Hyperdrive compatibility to be assessed (Phase 6)
- **Authentication:** SCRAM-SHA-256
- **Security:** Bound to localhost; never exposed publicly
- **Backup:** To be designed in Phase 5

### 5. Object Storage
- **Provider:** Cloudflare R2
- **Usage:** Backups, WAL archives (buckets to be verified in Phase 5)

### 6. Application Runtime
- **Workers:** Cloudflare Workers (medveris-production, medveris-staging, medveris-local)
- **Routes:** `medveris.online`, custom domains
- **AI:** Cloudflare Workers AI (when FEATURE_AI=true)

### 7. AI Inference
- **Provider:** Ollama (private, local) — to be deployed in Phase 4
- **Binding:** 127.0.0.1 only, never publicly exposed
- **Model:** Small quantized model initially
- **Storage:** Docker volume (persistent)

### 8. Workflow Automation
- **Tool:** n8n — to be deployed in Phase 4
- **Database:** Dedicated PostgreSQL database and account on Kamatera
- **Configuration:** Persistent Docker volume
- **Security:** Authentication required, webhook security

### 9. Reverse Proxy
- **Provider:** Nginx (only where a VPS-hosted service needs it)
- **TLS:** Cloudflare-managed certificates
- **Routes:** Only for VPS-hosted services that need public exposure

### 10. Monitoring & Backup
- **Host:** CPU, RAM, disk, filesystem
- **Database:** PostgreSQL connections, disk, health
- **Ollama:** Availability, memory, latency
- **n8n:** Execution health
- **Backup:** Encrypted backups to R2 (Phase 5 redesign)

## Network Design

### Firewall (UFW) — To Be Configured in Phase 2
- Allow SSH (port 22) from trusted sources only
- Allow HTTP/HTTPS (port 80/443) from anywhere
- Block PostgreSQL port 5432 publicly (already bound to localhost)
- Block Ollama API port 11434 publicly
- Rules must be validated with second SSH session before enabling

### Cloudflare Integration
- **DNS:** Managed through Cloudflare account
- **TLS:** Automatic certificate management
- **R2:** Object storage integration
- **Hyperdrive:** Compatibility with Kamatera PG18 to be assessed (Phase 6)
- **Workers:** Application execution environment

## Resource Allocation (8 GB RAM Constraint)

| Component | Allocation | Rationale |
|---|---|---|
| OS | ~500 MB | Base Ubuntu 26.04 |
| PostgreSQL 18 | ~1.5 GB | Conservative memory, WAL |
| Docker Engine | ~200 MB | Engine overhead |
| n8n | ~512 MB | With resource limits |
| Ollama | ~512 MB | Small model, memory-aware |
| Reserved/Buffer | ~2 GB | Spike protection |

Note: No Kubernetes overhead (Docker Compose, not k3s).

## Dependencies & Compatibility

| Dependency | Version | Notes |
|---|---|---|
| OS | Ubuntu 26.04.1 LTS | Verified installed |
| PostgreSQL | 18.6 | Verified installed, online |
| Docker | Latest stable | Engine + Compose plugin (Phase 3) |
| Docker Compose | Latest stable | Orchestration (approved) |
| Cloudflare Wrangler | 4.152.0 | For Worker deployments |
| Terraform | >= 1.5.0 | Infrastructure as code (WSL) |
| Ansible | >= 2.15 | Server provisioning (WSL) |

Not in scope: k3s, containerd, Helm, Kubernetes.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| PostgreSQL publicly exposed | Data breach | HIGH | Bound to localhost; never expose 5432; Hyperdrive not assumed |
| Ollama public API exposure | Unauthorized AI usage | MEDIUM | Private binding only; firewall rule; never expose publicly |
| SSH key compromise | Server takeover | MEDIUM | Key-only auth; second-session verification; rotate keys |
| Disk full (150 GB) | Service interruption | LOW | Monitor disk usage; 138 GB available currently |
| Insufficient RAM for all services | Service failure, OOM | MEDIUM | Resource limits; prioritize essential services |
| Hyperdrive incompatible with Kamatera PG | Connectivity loss | TBD | Assess in Phase 6 before relying on it |
| n8n/Ollama resource contention | Performance degradation | MEDIUM | Docker resource limits per workload |

## Implementation Phases

### Phase 1: Infrastructure Configuration Safety (in progress)
- Reconcile documentation with actual Ubuntu 26.04.1 and PostgreSQL 18
- Correct architecture to Docker Compose
- Review Terraform for safe VPS management
- Review Ansible for idempotence and safety
- Protect secrets and state
- Correct outdated execution guide

### Phase 2: VPS Security Baseline (partially complete)
**Independently verified 2026-11-07:**
- [x] UFW ACTIVE — default deny incoming, allow outgoing; SSH (TCP 22) allowed on IPv4+IPv6
- [x] pg_hba.conf VERIFIED — local=peer, TCP=scram-sha-256 for localhost only
- [x] PostgreSQL NOT publicly accessible — confirmed via ss and pg_hba.conf

**Remaining (BLOCKED pending approval):**
- [ ] deploy user has sudo group membership but requires password for sudo
- [ ] Fail2ban not installed
- [ ] SSH: PermitRootLogin=yes, PasswordAuthentication=yes (NOT hardened)
- [ ] No /etc/ssh/sshd_config.d/ drop-in files
- [ ] System updates not checked (requires sudo)
**Required actions:**
- Configure passwordless sudo for deploy OR document Ansible vault/sudo password approach
- Install and configure Fail2ban SSH jail
- Harden SSH: disable root login, disable password auth (after key verification)
- Review pending system updates (requires sudo)

### Phase 3: Docker Engine and Compose (pending)
- Install Docker Engine + Compose
- Configure Docker safely
- Base docker-compose.yml structure

### Phase 4: Supporting Services (pending, separate sub-phases)
- PostgreSQL 18 hardening
- Ollama (private)
- n8n (persistent, secure)
- Nginx where needed

### Phase 5: Backup and Disaster Recovery (pending)
- Redesign backup/restore scripts
- Authenticated encryption
- R2 bucket verification

### Phase 6: Cloudflare Integration Assessment (pending)
- Hyperdrive compatibility
- Private connectivity
- Ollama from Workers (if needed)
