# Disaster Recovery Documentation

## Overview

**STATUS: Design phase — not yet implemented.**

Disaster recovery and business continuity for Medveris infrastructure on Kamatera with Cloudflare R2 backup storage.

**Critical caveat:** As of 2026-11-07, Kamatera PostgreSQL is an empty supporting database.
Neon PostgreSQL is the production source of truth. No production backups should be run
against Kamatera until a migration is approved. The scripts in `scripts/` have known defects
(see docs/IMPLEMENTATION_LOG.md) and must be redesigned before use.

## Recovery Objectives

| Metric | Target | Rationale |
|---|---|---|
| **Recovery Point Objective (RPO)** | ≤ 24 hours | Daily full backups + continuous WAL archiving |
| **Recovery Time Objective (RTO)** | ≤ 4 hours | Restore from R2 + PITR replay |
| **Data Loss Tolerance** | ≤ 1 day of transactions | WAL archiving to R2 limits data loss window |
| **Service Availability** | 99.9% monthly | Cloudflare R2 durability + Kamatera SLA |

## Backup Strategy

### 1. Scheduled Encrypted Backups

#### Full Database Backups
- **Frequency:** Daily at 02:00 UTC
- **Method:** `pg_dump -Fc` (custom format)
- **Encryption:** OpenSSL AES-256 before R2 upload
- **Retention:** 30 days on R2
- **Command:**
  ```bash
  pg_dump -Fc -h KAMATERA_HOST -U medveris_runtime -d medveris_prod \
    | openssl enc -aes-256-cbc -salt -pass pass: $BACKUP_PASSWORD \
    > /tmp/medveris_backup_$(date +%Y%m%d).enc
  rclone copy /tmp/medveris_backup_$(date +%Y%m%d).enc r2:medveris-production-backups/
  ```

#### WAL Archiving
- **Mode:** Continuous
- **Destination:** Cloudflare R2 bucket `medveris-production-wal`
- **Format:** Raw WAL files
- **Retention:** 7 days minimum
- **Configuration:** `archive_command` in postgresql.conf

### 2. Backup Integrity Verification

#### Weekly Verification
```bash
# Decrypt and verify backup
openssl enc -d -aes-256-cbc -in /path/to/backup.enc -out /tmp/verify_dump.dump

# Restore to test server and run checks
pg_restore -d medveris_verify /tmp/verify_dump.dump

# Run integrity checks
psql -d medveris_verify -c "SELECT count(*) FROM tenants;"
psql -d medveris_verify -c "SELECT count(*) FROM migrations;"
```

#### Monthly Restore Test
- Full restore to temporary database
- Run application health checks
- Validate data consistency
- Document RTO metrics

### 3. Backup Credential Management

- **R2 Credentials:** Stored in Cloudflare Workers secrets, never in repo
- **Database Passwords:** Managed via Ansible Vault
- **Encryption Passwords:** Rotated quarterly; separate from DB passwords
- **Access Restriction:** R2 credentials have write-only permissions to backup prefix

## Restore Procedures

### Scenario 1: Complete Server Loss
1. Provision new Kamatera server (4 vCPU, 8 GB RAM, 150 GB disk)
2. Install Ubuntu 24.04 LTS and PostgreSQL
3. Restore latest backup from R2
   ```bash
   rclone copy r2:medveris-production-backups/medveris_backup_$(date -d '1 day ago' +%Y%m%d).enc /tmp/
   openssl enc -d -aes-256-cbc -in /tmp/medveris_backup_*.enc -out /tmp/medveris_restore.dump
   pg_restore -d medveris_prod /tmp/medveris_restore.dump
   ```
4. Replay WAL files up to failure point
5. Verify application connectivity
6. Update DNS if server IP changed

### Scenario 2: Database Corruption
1. Identify corrupt table/index
2. Restore from previous day's backup
3. Replay WAL files since that backup
4. Verify data consistency
5. Resume normal operations

### Scenario 3: Ransomware/Malware
1. Isolate affected services
2. Restore from known-clean backup (previous week)
3. Verify all tables, no encrypted files
4. Apply security patches before bringing online
5. Monitor for recurrence

## Recovery Procedure Checklist

### Pre-Recovery
- [ ] Confirm disaster scope and impact
- [ ] Verify backup availability in R2
- [ ] Confirm RPO/RTO targets are met
- [ ] Assemble recovery team
- [ ] Document current state (what's failing, what data is affected)

### During Recovery
- [ ] Provision recovery environment (if needed)
- [ ] Restore database from backup
- [ ] Replay WAL archives
- [ ] Run integrity checks (row counts, constraints, RLS)
- [ ] Test application connectivity
- [ ] Validate business functionality
- [ ] Update monitoring/alerting for root cause

### Post-Recovery
- [ ] Document root cause and timeline
- [ ] Update disaster recovery runbook
- [ ] Review and improve preventive measures
- [ ] Conduct post-mortem meeting
- [ ] Test recovery procedure again in 30 days

## R2 Backup Structure

```
r2:medveris-production/
├── backups/
│   ├── medveris_backup_20240101_020000.dump.enc
│   ├── medveris_backup_20240102_020000.dump.enc
│   └── ... (30 days retention)
├── wal/
│   ├── 000000010000000000000001
│   ├── 000000010000000000000002
│   └── ... (7 days retention)
└── metadata/
    ├── backup_manifest.json
    └── recovery.log
```

### R2 Folder Details

| Folder | Contents | Retention |
|---|---|---|
| `backups/` | Encrypted pg_dump custom format | 30 days |
| `wal/` | Raw WAL sequence files | 7 days |
| `metadata/` | Manifest and recovery logs | 90 days |

### R2 Bucket Policy (example)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ""},
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::medveris-production/*",
      "Condition": {
        "StringEquals": {"s3:x-amz-acl": "private"}
      }
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::medveris-production/*"
    }
  ]
}
```

## Monitoring & Alerting

### Backup Success/Failure Alerts
- **Alert:** Backup job completed successfully
  - Channel: Operations dashboard
  - Frequency: Daily
- **Alert:** Backup job failed
  - Channel: Operations dashboard + SMS/Email
  - Frequency: Immediately
- **Alert:** R2 upload failed
  - Channel: Operations dashboard
  - Frequency: Immediately

### TLS Certificate Expiry Monitoring
- **Certificates:** Cloudflare-managed (auto-renew)
- **Monitoring:** 30-day, 14-day, 7-day, 1-day alerts
- **Alerting:** Operations dashboard + email to infrastructure team

### Disk Space Monitoring
- **Thresholds:** 
  - Warning: > 80% used (120 GB of 150 GB)
  - Critical: > 90% used (135 GB of 150 GB)
- **Alerting:** Operations dashboard + pager duty

## Documentation

- **Runbook Location:** `docs/DISASTER_RECOVERY.md` (this file)
- **Last Tested:** [Date] - [Results]
- **Next Test Date:** [Date, 30 days from last test]
- **Contact:** Infrastructure team (via ops channel)
- **R2 Bucket Names:** `medveris-production-backups`, `medveris-production-wal`

## Never Assume a Backup is Valid

> "Do not assume a backup is valid until restoration has been tested."

This is **Rule #11** from the Absolute Safety Rules. Every quarter, perform a full restore test in a non-production environment and validate:
- Row counts match expected values
- All constraints are satisfied
- RLS policies are active and functional
- Application can read and write data
- Sequences are at correct values
