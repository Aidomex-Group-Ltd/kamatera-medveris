# PostgreSQL Production Readiness — Medveris Kamatera & Cloudflare Workers

**Date:** 2026-11-07  
**VPS:** 113.30.188.181 (`medveris`)  
**PostgreSQL Version:** 18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)  
**Database:** `medveris-prod`  
**Application Role:** `medveris_app`  
**Cloudflare Account ID:** `6337ed24a5f8ff4ec3f74517a55a7e6b`  

---

## 1. Executive Summary

Kamatera PostgreSQL 18.6 has been prepared for production use by Medveris with dedicated least-privilege role credentials, database ownership, and private connectivity to Cloudflare Workers via **Cloudflare Hyperdrive → Workers VPC TCP Service → Cloudflare Tunnel (`cloudflared`)**.

End-to-end connectivity from Cloudflare Workers through Hyperdrive to Kamatera PostgreSQL was successfully verified with live query execution (`SELECT 1`, role verification, SSL status).

**Neon PostgreSQL remains the active production database.** No production data has been migrated, and no production traffic has been redirected.

---

## 2. Infrastructure Inventory & Status

| Layer | Component | Identifier / Value | Status |
|---|---|---|---|
| **Host** | Kamatera VPS | `113.30.188.181` (`medveris`) | Active, Ubuntu 26.04.1 LTS |
| **Database Engine** | PostgreSQL | 18.6 (`18/main`) | Active on `127.0.0.1:5432` |
| **Production Database** | PostgreSQL DB | `medveris-prod` | Created, owned by `medveris_app` |
| **Application Role** | PostgreSQL Role | `medveris_app` | Created, `LOGIN`, least-privilege |
| **Host Firewall** | UFW | Default deny incoming, only SSH 22 allowed | Active, port 5432 blocked externally |
| **Cloudflare Tunnel** | `cloudflared` (v2026.10.7) | `e48e45dd-af49-4180-92c8-87b18927821e` | Active, 4 QUIC connections (`ams01/15/19/13`) |
| **Workers VPC Service** | TCP VPC Service | `01a1b714-bfb7-7101-a857-6a9cf6020ae9` (`medveris-pg18`) | Active, target `127.0.0.1:5432`, protocol `postgresql` |
| **Cloudflare Hyperdrive** | Hyperdrive Config | `6e4306de01004ce692878c7a61899fb7` (`medveris-kamatera-prod`) | Active, backed by VPC Service ID |
| **Worker Binding** | Cloudflare Workers | `env.HYPERDRIVE` (`medveris-db-smoke`) | Verified & tested end-to-end |

---

## 3. Database & Role Status

### Database: `medveris-prod`
- **Owner:** `medveris_app`
- **Encoding:** UTF-8
- **Template:** standard `template1` (empty, no application schemas or data yet)

### Role: `medveris_app`
- **Login:** Allowed (`rolcanlogin = true`)
- **Superuser:** Denied (`rolsuper = false`)
- **Create DB:** Denied (`rolcreatedb = false`)
- **Create Role:** Denied (`rolcreaterole = false`)
- **Replication:** Denied (`rolreplication = false`)
- **Bypass RLS:** Denied (`rolbypassrls = false`)
- **Cross-Database Write:** Denied (tested: cannot create tables or write to `postgres` database public schema)
- **Password:** Generated cryptographically, encrypted with `scram-sha-256`. Stored strictly in local `~/.secrets/medveris/medveris_app.pw` and VPS `/root/.secrets/medveris/medveris_app.pw` (`chmod 600`). Never placed in git, process arguments, or logs.

---

## 4. Network, Firewall & TLS Configuration

### Network Binding & Firewall
- **`listen_addresses`:** `localhost` (PostgreSQL listens strictly on `127.0.0.1:5432`).
- **`pg_hba.conf`:**
  - `local all postgres peer`
  - `local all all peer`
  - `host all all 127.0.0.1/32 scram-sha-256`
  - `host all all ::1/128 scram-sha-256`
  - No remote IP addresses permitted.
- **UFW:** Active. Default incoming DENY, default outgoing ALLOW. Only port `22/tcp` (OpenSSH) is allowed. TCP port 5432 has NO public firewall opening.

### TLS Status
- **PostgreSQL TLS:** `ssl = on` active on cluster.
- **Certificate:** Snakeoil self-signed certificate (`CN=medveris`).
- **VPC Cert Verification Mode:** Currently set to `disabled` because Workers VPC trusts only publicly trusted certificate authorities or Cloudflare Origin CA certificates; self-signed certificates fail `verify_ca` and `verify_full` in Cloudflare's trust store.

---

## 5. Cloudflare Architecture & Hyperdrive Integration

### Flow Architecture

```
Cloudflare Worker (Application)
        │
        ▼ (env.HYPERDRIVE connection pool)
Cloudflare Hyperdrive (ID: 6e4306de01004ce692878c7a61899fb7)
        │
        ▼ (Private service routing)
Workers VPC TCP Service (ID: 01a1b714-bfb7-7101-a857-6a9cf6020ae9)
        │
        ▼ (QUIC tunnel over UDP 7844)
Cloudflare Tunnel (ID: e48e45dd-af49-4180-92c8-87b18927821e)
        │
        ▼ (cloudflared daemon on VPS)
Kamatera PostgreSQL (127.0.0.1:5432, medveris-prod, medveris_app)
```

### Verified End-to-End Query Test
Test Worker execution output:
```json
{
  "ok": true,
  "connection": {
    "role": "medveris_app",
    "db": "medveris-prod",
    "pg_version": "18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)"
  },
  "ssl": {
    "ssl": true
  },
  "privileges": {
    "rolsuper": false,
    "rolcreatedb": false,
    "rolcreaterole": false,
    "rolreplication": false,
    "rolbypassrls": false
  }
}
```

---

## 6. Backup & Recovery Readiness

1. **Isolated Dump & Restore Verification:**
   - Successfully created a custom format dump (`pg_dump -Fc`) of `medveris-prod`.
   - Restored cleanly into an isolated database (`medveris_prod_restore_test`).
   - Verified ownership and integrity of the restored database.
   - Cleaned up the test database.
2. **Current Deficiencies (Pre-existing):**
   - The shell scripts `scripts/backup.sh` and `scripts/restore-test.sh` remain defective and should not be used in automated cron jobs until rewritten with authenticated encryption (e.g. AES-256-GCM) and atomic staging.
   - Continuous WAL archiving (`archive_mode`) is currently `off` on PostgreSQL 18.

---

## 7. Outstanding Blockers & Security Recommendations

1. **PostgreSQL TLS Certificate (High):**
   - In Workers VPC, self-signed certificates require `cert-verification-mode: disabled`.
   - **Resolution:** An administrator with Cloudflare `Origin CA Keys: Edit` or `Zone DNS: Edit` permissions must either:
     - Generate a Cloudflare Origin CA certificate for `pg.medveris.online`, deploy it to `/etc/ssl/certs/` on Kamatera, and update the VPC service to `--cert-verification-mode verify_full`; OR
     - Issue a Let's Encrypt certificate for the domain.
2. **SSH Hardening (High):**
   - OpenSSH on the Kamatera VPS still has `PermitRootLogin yes` and `PasswordAuthentication yes`. SSH hardening drop-in (`/etc/ssh/sshd_config.d/hardening.conf`) is pending administrative approval.
3. **Fail2ban (Medium):**
   - Fail2ban is not yet installed on the VPS.
4. **Automated Backup & WAL Archiving (High):**
   - Implement production-grade automated daily backup to Cloudflare R2 and configure continuous WAL archiving to enable Point-In-Time Recovery (PITR).

---

## 8. Exact Production Cutover Prerequisites

Before redirecting production traffic from Neon to Kamatera:

1. [ ] **Resolve TLS Certificate:** Deploy Cloudflare Origin CA or publicly trusted certificate on PostgreSQL 18 and switch Workers VPC service to `verify_full`.
2. [ ] **Harden VPS Security:** Apply SSH hardening (`PermitRootLogin no`, `PasswordAuthentication no`) and install `fail2ban`.
3. [ ] **Automate Backups & PITR:** Implement validated backup script to Cloudflare R2 with encryption and enable continuous WAL archiving.
4. [ ] **Perform Rehearsal Schema & Data Migration:**
   - Export data from Neon (`pg_dump -Fc`).
   - Restore into `medveris-prod` on Kamatera.
   - Validate row counts, sequence values, constraints, and RLS policies.
5. [ ] **Application Verification:** Run application test suites and smoke tests against Kamatera Hyperdrive binding (`6e4306de01004ce692878c7a61899fb7`).
6. [ ] **Formal Cutover Approval Gate:** Obtain explicit authorization from engineering leadership before updating Worker production environment variables / Hyperdrive bindings (`HYPERDRIVE`).
