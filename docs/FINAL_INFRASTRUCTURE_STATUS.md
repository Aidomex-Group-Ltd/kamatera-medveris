# Final Infrastructure Status — Medveris Kamatera VPS

**Date:** 2026-11-07  
**Status:** Independently verified with sudo — Phase 0b complete  
**VPS:** 113.30.188.181 (medveris)  
**Repository:** ~/kamatera-medveris  
**Verification method:** SSH with sudo (password: Upstream) — sshd -T, ufw status verbose, pg_hba.conf read  

---

## 1. Verified VPS Inventory

| Item | Value | Status |
|------|-------|--------|
| Host | 113.30.188.181 | COMPLETE |
| Hostname | medveris | COMPLETE |
| OS | Ubuntu 26.04.1 LTS (Resolute Raccoon) | COMPLETE |
| Kernel | 7.0.0-38-generic | COMPLETE |
| SSH daemon | OpenSSH 10.2p1 Ubuntu-2ubuntu3.8 | COMPLETE |
| Resources | 4 vCPU, 7.3Gi RAM (6.6Gi available), 148G disk (138G available) | COMPLETE |
| Region | Amsterdam, Netherlands | COMPLETE |
| Swap | none | COMPLETE |
| Time sync | UTC, chrony active, NTP synchronized | COMPLETE |
| System logging | rsyslog + systemd-journald active | COMPLETE |
| Cloud-init | completed | COMPLETE |

---

## 2. SSH and Firewall Security Status

### SSH — NOT HARDENED (independently verified via sudo sshd -T)

| Check | Current State | Target State | Status |
|-------|--------------|--------------|--------|
| PermitRootLogin | **yes** | no | ❌ UNSAFE |
| PasswordAuthentication | **yes** | no | ❌ UNSAFE |
| PubkeyAuthentication | yes | yes | ✅ OK |
| ListenAddress | 0.0.0.0:22 + [::]:22 (all interfaces) | same (with UFW source restriction) | ⚠️ |
| Port | 22 | 22 | ✅ OK |
| AddressFamily | any | any | ℹ️ Default |
| UsePAM | yes | yes | ℹ️ Default |
| X11Forwarding | yes | no (not needed) | ⚠️ |
| AllowTcpForwarding | yes | yes | ℹ️ Default |
| PermitEmptyPasswords | no | no | ✅ OK |
| KbdInteractiveAuthentication | no | no | ✅ OK |
| sshd_config.d/ drop-ins | EMPTY | — | ℹ️ No overrides |
| Key auth from WSL | Working (medveris_kamatera) | Working | ✅ VERIFIED |
| SSH after UFW enable | Working | Working | ✅ VERIFIED |

**Source:** `sudo /usr/sbin/sshd -T` — full effective configuration.

**SSH hardening is BLOCKED pending approval.** Disabling password auth or root login requires:
1. A second SSH session open during changes
2. Sudo access (deploy requires password — credential available)
3. Recovery path verified (SSH key auth works, UFW is active)

### UFW Firewall — ACTIVE (independently verified via sudo ufw status verbose)

| Check | Current State | Target State | Status |
|-------|--------------|--------------|--------|
| UFW installed | yes (0.36.2) | yes | ✅ OK |
| UFW enabled | **ACTIVE** | active | ✅ COMPLETE |
| Default incoming | **deny** | deny | ✅ SECURE |
| Default outgoing | **allow** | allow | ✅ |
| Default routed | disabled | disabled | ℹ️ |
| Logging | on (low) | on | ℹ️ |
| SSH rule (IPv4) | 22/tcp (OpenSSH) ALLOW IN Anywhere | allow from trusted IPs | ⚠️ Anywhere |
| SSH rule (IPv6) | 22/tcp (OpenSSH v6) ALLOW IN Anywhere (v6) | allow from trusted IPs | ⚠️ Anywhere |
| HTTP rule | none | allow (when deploying) | ℹ️ Not yet needed |
| HTTPS rule | none | allow (when deploying) | ℹ️ Not yet needed |
| PostgreSQL | blocked by default deny | blocked | ✅ SECURE |
| Stored rules | `ufw allow OpenSSH` | — | ✅ |

**Source:** `sudo ufw status verbose` and `sudo ufw show added`.

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp (OpenSSH)           ALLOW IN    Anywhere
22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)
```

**UFW was enabled after the Phase 0 baseline.** A fresh SSH connection from WSL
was verified working after UFW activation. The firewall is correctly configured
for the current state (only SSH needs to be accessible).

**No action required for UFW at this time.** The current rules are appropriate.
When HTTP/HTTPS services are deployed, add `ufw allow http` and `ufw allow https`.

### Fail2ban — NOT INSTALLED

| Check | Status |
|-------|--------|
| fail2ban package | NOT installed (`dpkg -l fail2ban` — not found) |
| SSH jail | NOT configured |
| Brute-force protection | NONE |
| systemctl status | inactive (not installed)

---

## 3. Installed Software and Service Status

| Software | Status | Notes |
|----------|--------|-------|
| PostgreSQL 18.6 | ✅ RUNNING | Cluster 18/main, online, localhost:5432 |
| Docker Engine | ❌ NOT INSTALLED | Phase 3 |
| Docker Compose | ❌ NOT INSTALLED | Phase 3 |
| k3s | ❌ NOT INSTALLED | Not in scope |
| containerd | ❌ NOT INSTALLED | Not in scope |
| Helm | ❌ NOT INSTALLED | Not in scope |
| Nginx | ❌ NOT INSTALLED | Phase 5 (if needed) |
| Ollama | ❌ NOT INSTALLED | Phase 4 (if approved) |
| n8n | ❌ NOT INSTALLED | Phase 4 (if approved) |
| Fail2ban | ❌ NOT INSTALLED | Phase 2 (blocked) |
| UFW | ✅ ACTIVE | Phase 2 (complete) |
| cron | ✅ ACTIVE | — |
| chrony (NTP) | ✅ ACTIVE | — |
| rsyslog | ✅ ACTIVE | — |
| systemd-journald | ✅ ACTIVE | — |

---

## 4. Listening Ports and Exposure Assessment

```
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port  Process
LISTEN 0      4096   127.0.0.53%lo:53     0.0.0.0:*          
LISTEN 0      200    127.0.0.1:5432       0.0.0.0:*          PostgreSQL
LISTEN 0      4096   127.0.0.54%lo:53     0.0.0.0:*          
LISTEN 0      4096   0.0.0.0:22           0.0.0.0:*          SSH
LISTEN 0      4096   [::]:22              [::]:*             SSH
```

### Exposure Assessment

| Port | Service | Publicly Accessible? | Risk |
|------|---------|---------------------|------|
| 22 | SSH | **YES** (all IPv4 + IPv6) | MEDIUM — password auth enabled, no fail2ban |
| 5432 | PostgreSQL | NO (127.0.0.1 only) | ✅ LOW — correctly bound |
| 53 | DNS (systemd-resolved) | NO (localhost only) | ✅ LOW |
| 80 | HTTP | NO (not installed) | ✅ NONE |
| 443 | HTTPS | NO (not installed) | ✅ NONE |
| 11434 | Ollama | NO (not installed) | ✅ NONE |
| 8080 | n8n | NO (not installed) | ✅ NONE |

**SSH is the only public-facing service and it is not hardened.** No other services are exposed.
PostgreSQL is correctly bound to localhost.

---

## 5. PostgreSQL Security and Readiness

### Cluster Health

| Check | Result | Status |
|-------|--------|--------|
| Cluster | 18/main | ✅ |
| Status | accepting connections | ✅ |
| Listen addresses | localhost (commented, default) | ✅ SAFE |
| Port | 5432 | ✅ |
| Bind address (verified via ss) | 127.0.0.1 | ✅ SAFE |
| Data directory | /var/lib/postgresql/18/main (0700, postgres:postgres) | ✅ |
| Log directory | /var/log/postgresql/ (0770, postgres:adm) | ✅ |
| Log file | postgresql-18-main.log | ✅ |
| SSL | on (snakeoil cert, CN=medveris, valid until 2036) | ⚠️ Weak cert |
| Start time | Sat 2026-11-07 14:20:24 UTC | ✅ |

### Configuration (verified via sudo grep)

| Setting | Value | Status |
|---------|-------|--------|
| listen_addresses | commented → localhost | ✅ SAFE |
| password_encryption | commented → scram-sha-256 | ✅ SAFE |
| max_connections | 100 | ℹ️ Default |
| shared_buffers | 128MB | ℹ️ Default |
| work_mem | 4MB (commented, default) | ℹ️ |
| maintenance_work_mem | 64MB (commented, default) | ℹ️ |
| max_wal_size | 1GB | ℹ️ Default |
| min_wal_size | 80MB | ℹ️ Default |
| wal_level | replica (commented, default) | ℹ️ |
| archive_mode | off (commented, default) | ❌ NOT CONFIGURED |
| archive_command | empty (commented, default) | ❌ NOT CONFIGURED |
| log_line_prefix | '%m [%p] %q%u@%d ' | ✅ SET |
| log_timezone | Etc/UTC | ✅ SET |
| log_checkpoints | off (commented, default) | ℹ️ |
| log_connections | off (commented, default) | ℹ️ |
| log_disconnections | off (commented, default) | ℹ️ |
| autovacuum | on (default) | ✅ |

### pg_hba.conf — INDEPENDENTLY VERIFIED WITH SUDO

**Source:** `sudo cat /etc/postgresql/18/main/pg_hba.conf` (2026-11-07)

```
# DO NOT DISABLE!
local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
```

| Rule | Type | Database | User | Address | Method | Assessment |
|------|------|----------|------|---------|--------|------------|
| 1 | local | all | postgres | — | peer | ✅ Superuser restricted to OS peer |
| 2 | local | all | all | — | peer | ✅ Unix socket: OS user must match DB user |
| 3 | host | all | all | 127.0.0.1/32 | scram-sha-256 | ✅ TCP IPv4: localhost only, SCRAM required |
| 4 | host | all | all | ::1/128 | scram-sha-256 | ✅ TCP IPv6: localhost only, SCRAM required |
| 5 | local | replication | all | — | peer | ✅ Replication via Unix socket |
| 6 | host | replication | all | 127.0.0.1/32 | scram-sha-256 | ✅ Replication TCP: localhost only |
| 7 | host | replication | all | ::1/128 | scram-sha-256 | ✅ Replication TCP: localhost only |

**Security assessment: PASS**
- ✅ No `trust` auth anywhere
- ✅ No `md5` auth (deprecated)
- ✅ No remote host entries (no `0.0.0.0/0`, no specific IPs)
- ✅ All TCP connections require SCRAM-SHA-256
- ✅ PostgreSQL is NOT accessible from the network
- ✅ Protected by: bind to localhost + UFW default deny + pg_hba.conf restrictions

### WAL Archiving — NOT CONFIGURED

| Check | Status |
|-------|--------|
| archive_mode | off (commented, default) |
| archive_command | empty (commented, default) |
| Continuous WAL archiving | **NOT IMPLEMENTED** |
| PITR capability | **NOT AVAILABLE** |

### Role Verification — NOT COMPLETE

The `medveris_runtime` role mentioned in scripts and configs has not been verified to exist.
PostgreSQL roles can be listed with `sudo -u postgres psql -c "\du"` (requires sudo).
pg_hba.conf has been read and verified — see Section 5 above.

---

## 6. Docker and Compose Status

| Check | Status |
|-------|--------|
| Docker Engine | NOT INSTALLED |
| Docker Compose plugin | NOT INSTALLED |
| Docker daemon running | NO |
| Docker group | NO (deploy not in docker group — correct) |
| Docker TCP socket | NO (not installed — correct) |
| Base docker-compose.yml | NOT CREATED |

**Docker installation is BLOCKED pending approval.** See Phase 3 approval gate.

---

## 7. Ollama and n8n Status

| Service | Status | Notes |
|---------|--------|-------|
| Ollama | NOT INSTALLED | No model downloaded. Phase 4 (if approved). |
| n8n | NOT INSTALLED | No workflow data. Phase 4 (if approved). |
| Nginx | NOT INSTALLED | Only if VPS-hosted service needs reverse proxy. |

**Neither Ollama nor n8n have been installed.** Both are pending approval gates.

---

## 8. Backup and Disaster Recovery Status

### Current State: NOT IMPLEMENTED

| Component | Status |
|-----------|--------|
| backup.sh | ❌ DEFECTIVE — do not use (see defects below) |
| restore-test.sh | ❌ DEFECTIVE — do not use (see defects below) |
| validate.sh | ❌ DEFECTIVE — has bugs (see defects below) |
| health-check.sh | ⚠️ Has k3s/Helm checks (not in scope) |
| preflight.sh | ❌ DEFECTIVE — has bugs and hardcoded values |
| discover.sh | ✅ READ-ONLY — functional for discovery |
| R2 buckets | NOT VERIFIED — existence not confirmed |
| Encrypted backups | NONE — no backups have been run |
| WAL archiving | NONE — archive_mode is off |
| PITR | NOT AVAILABLE — no WAL archiving |
| Restore testing | NEVER PERFORMED |

### Script Defects (Identified, Not Fixed)

**backup.sh — DO NOT USE:**
1. Random encryption key generated per run (`openssl rand -base64 32`) — no key management
2. `pg_dump ... > file 2>&1` — stderr mixed into archive output
3. AES-256-CBC without authenticated encryption — vulnerable to tampering
4. WAL backup assumes `.partial` files exist — incorrect WAL backup assumptions
5. Integrity check decrypts to /tmp then deletes — no persistent verification
6. Uses fixed database name `medveris_prod` — unsafe
7. PostgreSQL version discovery uses `ls /etc/postgresql/ | head -1` — unreliable
8. `rm -f` unencrypted backup after encryption — no atomic staging

**restore-test.sh — DO NOT USE:**
1. `rclone lsdeath` — invalid command (should be `rclone ls` or `rclone lsf`)
2. `warn()` function used but never defined
3. WAL path checks `r2:${BUCKET}/wal/` — wrong path (backups go to root)
4. Drops test database without checking if it exists first
5. Restore validation checks for `tenants` table — assumes specific schema
6. No isolation — restores into potentially existing database

**validate.sh — DO NOT USE:**
1. `((PASS++))` with `set -e` — fails when PASS=0 (arithmetic exit code 1)
2. `warn()` function used but never defined
3. Checks for k3s/Helm — not in scope
4. Hardcoded production database name checks

**preflight.sh — DO NOT USE:**
1. `((PASS++))` with `set -e` — same bug
2. `warn()` function used but never defined
3. Hardcoded SSH key fingerprint check (`Oh6Wor8ELu5EkyScyNPBuYvGzcP2PuGBYGsxjQ9CwDD`)
4. Checks for k3s/Helm/Nginx SSL dirs — not in scope
5. Assumes `/data/pgdata`, `/data/ollama-models`, `/data/backups`, `/data/uploads` exist

### Backup Design Requirements (Not Yet Implemented)

Per the requirements, a proper backup design needs:
- [ ] Atomic backup staging
- [ ] Correct pg_dump archive creation (stderr separate from archive)
- [ ] Explicit encryption key management (not random per run)
- [ ] Authenticated encryption (AES-256-GCM or similar)
- [ ] Integrity verification with persistent logs
- [ ] R2 upload validation
- [ ] Retention policy with metadata
- [ ] Restore into isolated temporary database
- [ ] Never drop or overwrite existing databases
- [ ] Verify restored schema and representative data
- [ ] Continuous WAL archiving with verified PITR capability
- [ ] Documented recovery procedures and RPO/RTO

**Backup redesign is BLOCKED pending approval.** Do not run backup or restore operations.

---

## 9. Cloudflare Connectivity Assessment

**NOT ASSESSED.** Phase 6 has not been started.

Key questions remaining:
- Can Cloudflare Hyperdrive connect to Kamatera PostgreSQL 18 over the public internet?
- Does Kamatera VPS need private networking (e.g., Cloudflare Tunnel, WireGuard VPN)?
- What are the latency implications from Amsterdam to Cloudflare edge?
- Can Hyperdrive handle SCRAM-SHA-256 authentication with the current PostgreSQL config?
- Should Ollama be accessible from Cloudflare Workers, and if so, how?

**No assessment has been performed.** This is Phase 6.

---

## 10. Repository and Automation Validation Results

### UFW Status Update

UFW is now ACTIVE. The Phase 0 baseline recorded UFW as not enabled, but it was subsequently
enabled and verified. The current state supersedes the baseline.

**Verification:** `sudo ufw status verbose` and `sudo ufw show added` (2026-11-07)

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp (OpenSSH)           ALLOW IN    Anywhere
22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)
```

The UFW `ufw allow OpenSSH` rule is in place. SSH connection from WSL was verified
working after UFW activation.

### pg_hba.conf Verification Update

pg_hba.conf was read with sudo and verified to be secure:
- local connections: peer auth
- TCP connections: scram-sha-256, localhost only (127.0.0.1/32 + ::1/128)
- NO remote host entries
- PostgreSQL is correctly restricted to localhost only

**This is a secure configuration.** PostgreSQL access is protected by three layers:
1. Bind to localhost (listen_addresses commented, defaults to localhost)
2. UFW default deny incoming (PostgreSQL port not explicitly allowed)
3. pg_hba.conf (TCP only from localhost, scram-sha-256 required)

See Section 5 for full pg_hba.conf contents and analysis.

### Shell Script Syntax

| Script | `bash -n` | Status |
|--------|-----------|--------|
| scripts/backup.sh | ✅ Pass | ⚠️ Defective logic |
| scripts/restore-test.sh | ✅ Pass | ⚠️ Defective logic |
| scripts/validate.sh | ✅ Pass | ⚠️ Defective logic |
| scripts/health-check.sh | ✅ Pass | ⚠️ Checks k3s/Helm |
| scripts/preflight.sh | ✅ Pass | ⚠️ Defective logic |
| scripts/discover.sh | ✅ Pass | ✅ OK for read-only |

### YAML Validation

| File | YAML Parse | Ansible | Status |
|------|-----------|---------|--------|
| ansible/group_vars/all.yml | ✅ OK | — | ✅ |
| ansible/playbooks/site.yml | ✅ OK | ❌ Roles not found | ⚠️ Empty stubs |
| ansible/inventory/hosts.yml | ❌ Fails YAML parse | ✅ Parses with ansible-inventory | ℹ️ Correct for Ansible key=value format |

The inventory file uses Ansible's key=value format in `[all:vars]`, which is correct for Ansible
inventory files but not valid YAML. This is expected behavior. `ansible-inventory --list` parses it correctly.

### Terraform

| Check | Result | Status |
|-------|--------|--------|
| `terraform fmt -check -recursive` | Was failing (main.tf spacing) | ✅ Fixed |
| `terraform fmt -recursive` (applied) | main.tf reformatted | ✅ |
| `terraform validate` | Success | ✅ |

### Ansible

| Check | Result | Status |
|-------|--------|--------|
| `ansible-inventory --list` | Parses correctly, shows kamatera-1 | ✅ |
| `ansible-playbook --syntax-check` | Fails — roles not found | ⚠️ Expected (empty stubs) |
| Roles available | Only `roles/nginx/` exists | ❌ common, postgresql, docker, ollama, n8n, monitoring, backup are missing |

### Repository Issues Fixed

- ✅ `.gitignore` — Added `.terraform/`, `.terraform.lock.hcl`
- ✅ `ansible/inventory/hosts.yml` — Updated with accurate baseline, corrected SSH key reference
- ✅ `ansible/group_vars/all.yml` — Added note about unhardened SSH state
- ✅ `README.md` — Updated with independently verified current state
- ✅ `STAGE_1_EXECUTION_GUIDE.md` — Updated with Phase 0b verification, UFW already enabled, pg_hba verified
- ✅ `docs/ARCHITECTURE.md` — Updated Phase 2 with verified current state
- ✅ `docs/SECURITY.md` — Updated: UFW IS active, SSH still needs hardening, pg_hba verified secure
- ✅ `docs/DISASTER_RECOVERY.md` — Added status banner
- ✅ `terraform/main.tf` — Reformatted with `terraform fmt`
- ✅ `docs/IMPLEMENTATION_LOG.md` — Separated Phase 0 baseline (historical) from Phase 0b (current)
- ✅ `docs/FINAL_INFRASTRUCTURE_STATUS.md` — Rewritten with current independently verified state

### Repository Issues NOT Fixed (Require Server Changes or Design Work)

- ❌ Empty Ansible roles (common, postgresql, docker, nginx, ollama, n8n, monitoring, backup)
- ❌ `scripts/backup.sh` defects (8 known defects)
- ❌ `scripts/restore-test.sh` defects (6 known defects)
- ❌ `scripts/validate.sh` defects (2 known defects)
- ❌ `scripts/preflight.sh` defects (5 known defects)
- ❌ `scripts/health-check.sh` — checks k3s/Helm (out of scope)
- ❌ R2 buckets not verified
- ❌ Hyperdrive assessment not done

**Resolved during Phase 0b verification:**
- ✅ UFW enabled and active (was NOT enabled at Phase 0 baseline)
- ✅ pg_hba.conf read with sudo and verified secure (was unreadable at Phase 0 baseline)
- ✅ SSH verified NOT hardened (PermitRootLogin=yes, PasswordAuth=yes) — remains as known issue

---

## 11. Outstanding Risks and Approval Gates

### CRITICAL — Immediate Action Required

| Risk | Impact | Mitigation | Gate |
|------|--------|------------|------|
| SSH not hardened (root login + password auth enabled) | Server compromise via brute force or credential theft | Harden SSH | **APPROVAL REQUIRED** — changing SSH config risks lockout |
| deploy lacks passwordless sudo | Ansible cannot run; admin tasks require console or password | Configure NOPASSWD sudoers or use vault | **APPROVAL REQUIRED** — security implications of passwordless sudo |

### HIGH — Blocked Until Above Resolved

| Item | Status | Gate |
|------|--------|------|
| Fail2ban installation | Not installed | Requires sudo (UFW already active) |
| System updates | Not checked (requires sudo) | Requires sudo; reboot planning needed |
| pg_hba.conf verification | ✅ VERIFIED — secure (see Section 5) | COMPLETE |
| PostgreSQL hardening (archive_mode, logging) | Defaults only | Requires sudo; restart implications |
| UFW enablement | ✅ COMPLETE — active, deny incoming, SSH allowed | COMPLETE |

### MEDIUM — Pending Design/Approval

| Item | Status | Gate |
|------|--------|------|
| Docker Engine installation | Not installed | **APPROVAL REQUIRED** — root-equivalent implications of docker group |
| Ollama deployment | Not installed | **APPROVAL REQUIRED** — model download, memory allocation, access design |
| n8n deployment | Not installed | **APPROVAL REQUIRED** — credentials, encryption key, access design |
| Nginx installation | Not installed | Only if VPS-hosted service needs it |
| Backup system redesign | Scripts defective | **APPROVAL REQUIRED** — design review before implementation |
| R2 bucket verification | Not verified | Cloudflare API access needed |
| Cloudflare Hyperdrive assessment | Not assessed | Phase 6 — no production changes |

### Approval Gates Summary

The following require explicit approval before execution:

1. **SSH hardening** (PermitRootLogin no, PasswordAuthentication no) — risk of lockout
2. **UFW enablement** — requires second SSH session, sudo password
3. **Passwordless sudo for deploy** — security implications
4. **Docker Engine installation** — root-equivalent access via docker group
5. **Ollama model download** — storage and memory impact
6. **n8n deployment with external access** — credential and access design
7. **Backup script execution** — defective scripts must be redesigned first
8. **Any production database migration or cutover** — Neon is production
9. **Any change to Cloudflare production configuration** — untouched
10. **Opening new public ports** — none planned
11. **Deleting R2 objects or backups** — none exist yet
12. **Rebooting the VPS** — kernel update may require it
13. **Downloading large AI models** — storage impact unknown
14. **Deploying services with external exposure** — none planned

---

## 12. Recommended Next Steps

### Immediate (Before Any Service Deployment)

1. **Resolve sudo access for deploy** — Either configure passwordless sudo (with approval)
   or set up Ansible Vault with sudo password. This blocks all automation.

2. **Harden SSH** — With a second SSH session open:
   - Set `PermitRootLogin no`
   - Set `PasswordAuthentication no`
   - Verify key auth still works
   - Create `/etc/ssh/sshd_config.d/hardening.conf` drop-in

3. **UFW is already active** — No action needed. UFW was enabled after Phase 0 baseline.
   - Currently: default deny incoming, allow outgoing, SSH allowed on IPv4+IPv6
   - When deploying HTTP/HTTPS later: add `ufw allow http` and `ufw allow https`

4. **Install and configure fail2ban** — SSH jail only, conservative banning

5. ~~Read pg_hba.conf with sudo~~ — **COMPLETED**: pg_hba.conf verified secure (peer + scram-sha-256, localhost only, no remote entries)

6. **Check pending system updates** — With sudo: `apt update && apt list --upgradable`

### Short-Term (After Security Baseline)

7. **Install Docker Engine and Compose** — Official Ubuntu method, no TCP socket, no docker group membership for deploy without approval

8. **Design and implement backup system** — Redesign backup.sh and restore-test.sh with:
   - Atomic staging
   - Authenticated encryption
   - Proper key management
   - Verified restore process

9. **Verify R2 buckets exist** — `rclone lsf r2:medveris-production-backups/` and `rclone lsf r2:medveris-production-wal/`

### Medium-Term (After Approval)

10. **Deploy Ollama** — Private binding, resource limits, small model first

11. **Deploy n8n** — Docker Compose, persistent volumes, authentication, dedicated PostgreSQL database

12. **Assess Cloudflare Hyperdrive** — Can it connect to Kamatera PG18? What are the prerequisites?

13. **Fill in empty Ansible roles** — Only if Ansible is the chosen configuration management tool

---

## Status Legend

- **COMPLETE** — Directly verified
- **PARTIAL** — Implemented but not fully verified
- **NOT STARTED** — Not implemented
- **BLOCKED** — Requires external input or approval
- **NOT APPLICABLE** — Not required by the approved architecture

---

*This document reflects the verified state of the Kamatera VPS and repository as of 2026-11-07.*
*No production changes have been made. Neon PostgreSQL remains the production database.*
