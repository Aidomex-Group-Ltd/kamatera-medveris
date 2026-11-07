# Database Migration Documentation

## Migration Assessment: Neon Production → Kamatera PostgreSQL

### Pre-Migration Verification

#### Schema Parity
- [ ] Compare all tables, views, and materialized views between Neon and Kamatera
- [ ] Verify data types, constraints, and defaults match
- [ ] Check for Neon-specific extensions compatibility

#### Extensions
| Extension | Neon Status | Kamatera Target | Compatibility |
|---|---|---|---|
| pgvector | Check | Install if needed | May require compilation |
| uuid-ossp | Usually available | Yes | Standard |
| jsonb | Available | Yes | Standard |
| postgis | Check | Install if needed | GIS operations |
| pg_stat_statements | Available | Yes | Monitoring |

#### Roles and Grants
| Role | Neon Purpose | Kamatera Target | Grant Level |
|---|---|---|---|
| `medveris_runtime` | Primary application | Production primary | SELECT, INSERT, UPDATE, DELETE on tenant schemas |
| `medveris_migrator` | Migration execution | Migration tooling | CREATE, ALTER on migration tables |
| `medveris_jobs` | n8n job storage | n8n dedicated | Schema-specific grants |
| `postgres` | Administration | Never used for apps | Superuser only for ops |

#### RLS Policies
- [ ] Verify all Row-Level Security policies exist on Kamatera
- [ ] Test tenant isolation queries
- [ ] Preserve existing RLS policies during migration
- [ ] Validate that no tenant can access another's data

#### Indexes and Constraints
- [ ] List all indexes on Neon tables
- [ ] Recreate indexes on Kamatera with same definitions
- [ ] Verify primary keys, unique constraints, foreign keys
- [ ] Check for partial indexes or expression indexes

#### Sequences
- [ ] List all sequences on Neon
- [ ] Verify sequence ownership and caching
- [ ] Recreate sequences on Kamatera with same start/increment values
- [ ] Test nextval() behavior

#### Migration History
- [ ] Review all migration files in `scripts/migrations.ts`
- [ ] Verify migration order and dependencies
- [ ] Check for data seeds in `scripts/seed.ts`
- [ ] Document any custom migration logic

#### Data Consistency
- [ ] Export data from Neon (pg_dump custom format)
- [ ] Verify export integrity (pg_dump --verify if possible)
- [ ] Import to Kamatera in controlled manner
- [ ] Row count comparisons between source and target

#### Application Compatibility
- [ ] Verify connection strings work with Kamatera PostgreSQL
- [ ] Test with `psql` and Node.js `pg` driver
- [ ] Check for Neon-specific features used (e.g., `pg_sleep`, `pg_advisory_xact_lock`)
- [ ] Verify transaction behavior compatibility

### Migration Process

1. **Setup Kamatera PostgreSQL** (Stage 2)
   - Install PostgreSQL 16 on Ubuntu 24.04
   - Configure SCRAM-SHA-256 authentication
   - Set up persistent data directory
   - Create separate service accounts (`medveris_runtime`, `medveris_jobs`)
   - Configure TLS certificates for Hyperdrive connections
   - Set conservative memory settings for 8 GB machine

2. **Configure Hyperdrive** (Stage 6)
   - Create Hyperdrive target configuration for Kamatera
   - Verify secure origin connectivity
   - Test connection from Cloudflare Workers
   - Preserve existing Neon Hyperdrive configuration until cutover

3. **Data Export** 
   ```bash
   pg_dump -Fc -h neon-host neondb -U medveris_runtime -d neondb > medveris_backup.dump
   ```

4. **Data Import**
   ```bash
   pg_restore -h kamatera-host -U medveris_runtime -d medveris_prod medveris_backup.dump
   ```

5. **Post-Migration Validation**
   - [ ] Row counts match between Neon and Kamatera
   - [ ] Key constraint validation (PK, FK, unique)
   - [ ] RLS policies active and functional
   - [ ] Extension functionality tested
   - [ ] Application connectivity verified (health-check.sh)
   - [ ] Read/write operations tested
   - [ ] Hyperdrive connection pooling verified

6. **Rollback Strategy**
   - Keep Neon production online during migration
   - Maintain wAL archiving from Neon until validation complete
   - If failures: redirect application back to Neon Hyperdrive
   - Never switch production bindings without explicit cutover approval (Rule #3, Stage 15)

### Point-in-Time Recovery (PITR)

#### WAL Archiving Configuration
```bash
# In postgresql.conf
wal_level = 'replica'
max_wal_size = '4GB'
wal_keep_segments = '600'
archive_mode = on
archive_command = 'cp %p /data/pg_wal/%f'
archive_timeout = '1800'

# In Kamatera filesystem /data/pg_wal/
chmod 700 /data/pg_wal/
```

#### Backup Schedule
- **Full backup:** Daily at 02:00 UTC
- **WAL archiving:** Continuous to Cloudflare R2
- **Retention:** 30 days full backups, 7 days WAL files
- **Verification:** Weekly restore test

#### PITR Recovery Procedure
1. Restore latest full backup
2. Replay WAL files up to failure point
3. Verify database consistency
4. Test application connectivity

### Migration Checklist

- [ ] Schema parity verified
- [ ] Extensions installed and tested
- [ ] Roles and grants created with correct permissions
- [ ] RLS policies preserved and tested
- [ ] Indexes and constraints recreated
- [ ] Sequences recreated with correct values
- [ ] Migration history documented
- [ ] Data consistency verified (row counts, checksums)
- [ ] Application compatibility tested
- [ ] Rollback procedure rehearsed
- [ ] Hyperdrive configuration verified
- [ ] Downtime window scheduled and communicated
- [ ] Rollback criteria defined and approved
