# Stage 1 — Secure Server Foundation Execution Guide

> **STATUS: Independently verified and corrected (2026-11-07).**
> This guide reflects the verified VPS environment:
>   - Ubuntu 26.04.1 LTS (Resolute Raccoon)
>   - PostgreSQL 18.6
>   - Docker Compose (not k3s/Helm)
>   - UFW ACTIVE — default deny incoming, allow outgoing, SSH allowed on IPv4+IPv6
>   - SSH NOT hardened — PermitRootLogin=yes, PasswordAuthentication=yes
>   - pg_hba.conf VERIFIED — peer (local), scram-sha-256 (TCP), localhost only
> See `docs/IMPLEMENTATION_LOG.md` and `docs/FINAL_INFRASTRUCTURE_STATUS.md` for full
> verification history and current state.

## Overview

Stage 1 establishes the secure server foundation on Kamatera. The Kamatera server at
`113.30.188.181` is **provisioned, reachable, and already running** with:

- **OS:** Ubuntu 26.04.1 LTS (Resolute Raccoon)
- **PostgreSQL:** 18.6 (online, listening on localhost:5432)
- **SSH:** Key-based authentication working with `~/.ssh/medveris_kamatera`
- **Hostname:** `medveris`
- **Resources:** 4 vCPU, 8 GB RAM, 150 GB disk
- **Region:** Amsterdam, Netherlands

**SSH access is already working.** The server has an existing `deploy` account with
SSH key authentication configured. Do not reinstall SSH keys or recreate the deploy user
without first verifying the current state.

## Prerequisites

### 1. Kamatera Server (Verified)
- **Status:** Server provisioned and online at `113.30.188.181`
- **OS:** Ubuntu 26.04.1 LTS (Resolute Raccoon)
- **Resources:** 4 vCPU, 8 GB RAM, 150 GB disk
- **Region:** Amsterdam, Netherlands
- **Hostname:** `medveris`
- **SSH key:** `~/.ssh/medveris_kamatera` (private) / `medveris-kamatera-deploy` (public)

### 2. SSH Access Verification
SSH access is already verified working:
```bash
ssh -i ~/.ssh/medveris_kamatera -o BatchMode=yes -o ConnectTimeout=10 deploy@113.30.188.181 "echo 'SSH OK'"
```
- **Expected:** Connection succeeds (verified 2026-11-07)
- **Note:** Both `~/.ssh/medveris_kamatera` AND `~/.ssh/id_ed25519` are present on the
  VPS in `~deploy/.ssh/`. The inventory references the correct key (`medveris_kamatera`).
  Ansible inventory was corrected 2026-11-07.

### 3. Existing PostgreSQL
PostgreSQL 18.6 is already installed and running:
- Cluster: `18/main`
- Port: 5432
- Listen: localhost (127.0.0.1)
- Status: accepting connections
- Data directory: `/var/lib/postgresql/18/main`

**Do not reinstall PostgreSQL or recreate the cluster.** The existing installation
should be hardened in place.

## Stage 1 Implementation Steps

### Step 1: Verify Current State
Run the discovery script to capture current state:
```bash
./scripts/discover.sh
```

Then verify SSH and PostgreSQL:
```bash
ssh -i ~/.ssh/medveris_kamatera deploy@113.30.188.181 "pg_isready && echo 'PG OK'"
```

### Step 2: Correct Repository Configuration
Before running Ansible, fix the repository to match the verified environment:

1. **Fix Ansible inventory SSH key** — `ansible/inventory/hosts.yml` references
   `~/.ssh/id_ed25519`; change to `~/.ssh/medveris_kamatera`
2. **Fix Ansible group_vars** — YAML syntax errors (`=` → `:`), update PG version 16→18
3. **Fix Terraform outputs** — remove references to non-existent resources
4. **Update documentation** — Ubuntu 24.04→26.04.1, PG16→PG18, k3s→Docker Compose

### Step 3: Deploy Passwordless Sudo for Deploy User (REQUIRED for Ansible)
**Current state (verified 2026-11-07):** `sudo -n true` FAILS — deploy requires a password.
Ansible `become: true` WILL fail until this is resolved.

Verify:
```bash
ssh -i ~/.ssh/medveris_kamatera deploy@113.30.188.181 "sudo -n true"
```
- **Current result:** Fails with "sudo: interactive authentication is required"
- **Required:** Configure passwordless sudo for deploy before running Ansible.
  Two options:
  1. Add deploy to passwordless sudo (e.g., `/etc/sudoers.d/deploy` with `deploy ALL=(ALL) NOPASSWD: ALL`)
  2. Use Ansible `--ask-become-pass` with vault-encrypted credentials
  
  Option 1 is simpler but gives deploy passwordless root access. Option 2 is more secure
  but requires interactive password entry or vault setup.
  
  **This requires approval before execution.**

### Step 4: Run Ansible Playbook (after fixes)
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml \
  --limit "kamatera-1" --tags "system"
```

**Note:** The `system` play only. Do NOT run postgresql, k3s, or other tags until
those roles are corrected for the existing environment.

### Step 5: UFW Status — ALREADY ENABLED

**Independently verified 2026-11-07:** UFW is ACTIVE.

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp (OpenSSH)           ALLOW IN    Anywhere
22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)
```

UFW was subsequently enabled (after the Phase 0 baseline). SSH is allowed on IPv4 and IPv6.
Default incoming policy is deny, default outgoing is allow.

**This is correct and should not be changed.** The UFW rule set is minimal and appropriate:
- SSH allowed on both IPv4 and IPv6
- No other rules (no HTTP/HTTPS yet — services not installed)
- Default deny incoming protects all other ports

**No action required for UFW at this time.** If HTTP/HTTPS services are deployed later,
add `ufw allow http` and `ufw allow https` rules before deploying those services.

The `ufw show added` output confirms:
```
Added user rules (see 'ufw status' for running firewall):
ufw allow OpenSSH
```

### Step 6: PostgreSQL Hardening Review
PostgreSQL 18 is already running. Review and harden in place:

**Independently verified 2026-11-07 with sudo:**

- `listen_addresses` is COMMENTED OUT → defaults to `localhost` (safe, verified)
- `password_encryption` is COMMENTED OUT → defaults to `scram-sha-256` (safe, verified)
- `pg_hba.conf` READ WITH SUDO — authentication rules VERIFIED:
  ```
  local   all             postgres                                peer
  local   all             all                                     peer
  host    all             all             127.0.0.1/32            scram-sha-256
  host    all             all             ::1/128                 scram-sha-256
  local   replication     all                                     peer
  host    replication     all             127.0.0.1/32            scram-sha-256
  host    replication     all             ::1/128                 scram-sha-256
  ```
  **This is secure:**
  - Unix socket connections use `peer` auth (OS user must match DB user)
  - TCP connections ONLY allowed from localhost (127.0.0.1/32 and ::1/128)
  - TCP connections require `scram-sha-256` authentication
  - NO remote host entries exist — PostgreSQL is NOT accessible from the network
  - Superuser `postgres` can only connect via local Unix socket with peer auth
- `archive_mode` is off (commented), `archive_command` is empty (commented)
  - WAL archiving is NOT configured. PITR is NOT available.
- `shared_buffers = 128MB` (default, conservative for 8GB RAM)
- `max_wal_size = 1GB`, `min_wal_size = 80MB` (defaults)
- Do NOT restart PostgreSQL without assessing active connections

### Step 7: System Updates
Review pending updates:
```bash
ssh -i ~/.ssh/medveris_kamatera -t deploy@113.30.188.181 "sudo apt list --upgradable 2>/dev/null | wc -l"
```
(Note: requires sudo password — deploy currently has no passwordless sudo)

Apply updates with reboot planning:
```bash
sudo apt update && sudo apt upgrade -y
```
Reboot only after verifying no critical services would be disrupted.

**Current state (verified 2026-11-07):** `apt list --upgradable` returned 0 pending updates.
However, this was checked without sudo. A proper check requires sudo access.
Kernel is 7.0.0-38-generic — check for newer kernel versions.

## Post-Stage 1 Validation

After Stage 1 completes, verify:

| Check | Command | Expected |
|---|---|---|
| SSH accessibility | `ssh -i ~/.ssh/medveris_kamatera -o BatchMode=yes deploy@113.30.188.181 "echo OK"` | Success |
| OS version | `ssh deploy@113.30.188.181 "cat /etc/os-release | grep VERSION"` | 26.04.1 |
| Kernel | `ssh deploy@113.30.188.181 "uname -r"` | 7.0.0-38-generic or newer |
| PG version | `ssh deploy@113.30.188.181 "pg_config --version"` | PostgreSQL 18.6 |
| PG online | `ssh deploy@113.30.188.181 "pg_isready"` | accepting connections |
| PG private | `ssh deploy@113.30.188.181 "ss -tlnp | grep 5432"` | 127.0.0.1 only |
| PG listen config | `ssh deploy@113.30.188.181 "grep ^listen_addresses /etc/postgresql/18/main/postgresql.conf"` | commented/localhost |
| PG auth config | `ssh deploy@113.30.188.181 "grep ^password_encryption /etc/postgresql/18/main/postgresql.conf"` | commented/scram-sha-256 |
| PG hba readable | `ssh deploy@113.30.188.181 "sudo cat /etc/postgresql/18/main/pg_hba.conf"` | succeeds with sudo |
| Firewall | `ssh deploy@113.30.188.181 "sudo ufw status verbose"` | active (after UFW enabled) |
| Fail2ban | `ssh deploy@113.30.188.181 "systemctl is-active fail2ban"` | inactive (not installed) |
| Sudo passwordless | `ssh deploy@113.30.188.181 "sudo -n true"` | fails (password required) |
| SSH hardened | `ssh deploy@113.30.188.181 "sudo sshd -T"` | PermitRootLogin=yes, PasswordAuth=yes (NOT hardened) |
| UFW status | `ssh deploy@113.30.188.181 "sudo ufw status verbose"` | active, deny incoming, SSH allowed |

## Next Stages (After Stage 1 Approval)

Once Stage 1 is validated and approved, proceed to:

**Phase 2:** VPS Security Baseline (**PARTIALLY COMPLETE**)

**Completed:**
- [x] UFW enabled — active, default deny incoming, allow outgoing, SSH allowed on IPv4+IPv6
- [x] UFW rules verified — only OpenSSH profile rule present (correct for current state)

**Remaining (BLOCKED pending approval):**
- [BLOCKED] Passwordless sudo for deploy — requires approval for security implications
- [BLOCKED] Fail2ban installation — requires sudo
- [BLOCKED] SSH hardening (PermitRootLogin=no, PasswordAuthentication=no) — requires sudo, second session
- [BLOCKED] System updates — requires sudo, reboot planning

**Phase 3:** Docker Engine and Compose
- Install Docker Engine + Compose plugin
- Configure Docker daemon (no TCP socket exposure)
- Create base docker-compose.yml structure

**Phase 4:** Supporting Services (separate sub-phases)
- PostgreSQL 18 hardening and configuration
- Ollama deployment with restricted access
- n8n deployment with persistent storage
- Nginx only where an actual VPS-hosted service needs it

**Phase 5:** Backup and Disaster Recovery
- Redesign backup.sh and restore-test.sh (known defects documented)
- Evaluate pgBackRest vs native backups
- Implement authenticated encryption
- R2 bucket verification

**Phase 6:** Cloudflare Integration Assessment
- Hyperdrive compatibility with Kamatera PG18
- Private connectivity options
- Ollama connectivity from Workers (if required)

## Safety Rules Compliance (Stage 1)

1. ✅ Never delete/overwrite existing Neon production database
2. ✅ Never perform unapproved production database cutover
3. ✅ Never alter existing Medveris production Cloudflare Worker routing
4. ✅ Never remove existing database credentials or Hyperdrive configurations
5. ✅ Never expose PostgreSQL port 5432 publicly (bound to localhost)
6. ✅ Never expose Ollama's API publicly
7. ✅ Never commit SSH private keys, API keys, passwords
8. ✅ Never run destructive disk/filesystem commands without approval
9. ✅ Never assume server is empty (discovery confirmed existing PG18)
10. ✅ Never disable SSH access before verifying alternative access
11. ✅ Never treat successful deployment as proof of successful backup
12. ✅ Keep production cutover operations separate from infrastructure provisioning

---
**Note:** This guide was corrected on 2026-11-07 to reflect the verified VPS environment.
See `docs/IMPLEMENTATION_LOG.md` for the full reconciliation report.
