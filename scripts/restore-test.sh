#!/bin/bash
# Restore test script for Medveris PostgreSQL database
# Tests backup restoration and validates data integrity

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

echo -e "${GREEN}=== Medveris PostgreSQL Restore Test ===${NC}"
echo ""

# Configuration
R2_BACKUP_BUCKET="medveris-production-backups"
BACKUP_DIR="/data/backups"
PG_VERSION="$(ls /etc/postgresql/ | head -1)"
RESTORE_DB="medveris_restore_test"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/medveris/restore-test.log"

# Ensure log directory exists
mkdir -p /var/log/medveris

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "${GREEN}=== Starting Backup Restore Test ===${NC}"
echo ""

# 1. Download latest backup from R2
echo -e "${YELLOW}--- Step 1: Download Latest Backup from R2 ---${NC}"
LATEST_BACKUP=$(rclone lsdeath r2:${R2_BACKUP_BUCKET}/ | tail -1 | awk '{print $NF}')
if [ -z "$LATEST_BACKUP" ]; then
    fail "No backups found in R2 bucket: $R2_BACKUP_BUCKET"
    exit 1
fi
log "Latest backup: $LATEST_BACKUP"

rclone copy "r2:${R2_BACKUP_BUCKET}/${LATEST_BACKUP}" "${BACKUP_DIR}/" 2>&1
log "Backup downloaded to ${BACKUP_DIR}/${LATEST_BACKUP}"

# 2. Decrypt the backup
ENCRYPTED_FILE="${BACKUP_DIR}/${LATEST_BACKUP}"
DECRYPTED_FILE="/tmp/restore_test_dump_${TIMESTAMP}.dump"

echo -e "${YELLOW}--- Step 2: Decrypt Backup ---${NC}"
if openssl enc -d -aes-256-cbc -in "$ENCRYPTED_FILE" -out "$DECRYPTED_FILE" 2>/dev/null; then
    pass "Backup decrypted successfully"
    log "Backup decrypted: $DECRYPTED_FILE"
else
    fail "Failed to decrypt backup - wrong encryption key or corrupted file"
    exit 1
fi

# 3. Restore to a test database
echo -e "${YELLOW}--- Step 3: Restore to Test Database ---${NC}"
if pg_restore -d "$RESTORE_DB" "$DECRYPTED_FILE" 2>&1; then
    pass "Database restored to test database: $RESTORE_DB"
    log "Restore completed successfully"
else
    fail "Failed to restore database"
    exit 1
fi

# 4. Validate data integrity
echo -e "${YELLOW}--- Step 4: Validate Data Integrity ---${NC}"

# Check table count
TABLE_COUNT=$(psql -U medveris_runtime -d "$RESTORE_DB" -c "SELECT count(*) FROM tenants;" 2>/dev/null | awk '{print $1}')
if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
    pass "Table 'tenants' exists with $TABLE_COUNT rows"
    log "Table 'tenants' has $TABLE_COUNT rows"
else
    fail "Table 'tenants' not found or empty"
fi

# Check sequences
SEQ_COUNT=$(psql -U medveris_runtime -d "$RESTORE_DB" -c "SELECT count(*) FROM pg_sequences;" 2>/dev/null | awk '{print $1}')
if [ -n "$SEQ_COUNT" ] && [ "$SEQ_COUNT" -gt 0 ]; then
    pass "Sequences found: $SEQ_COUNT"
    log "Found $SEQ_COUNT sequences in restored database"
else
    warn "No sequences found in restored database"
fi

# Check extensions
EXT_COUNT=$(psql -U medveris_runtime -d "$RESTORE_DB" -c "SELECT count(*) FROM pg_extension;" 2>/dev/null | awk '{print $1}')
if [ -n "$EXT_COUNT" ] && [ "$EXT_COUNT" -gt 0 ]; then
    pass "Extensions found: $EXT_COUNT"
    log "Found $EXT_COUNT extensions in restored database"
else
    warn "No extensions found in restored database"
fi

# 5. Verify RLS policies
echo -e "${YELLOW}--- Step 5: Verify Row-Level Security ---${NC}"
RLS_STATUS=$(psql -U medveris_runtime -d "$RESTORE_DB" -c "SELECT relrowsecurity FROM pg_class WHERE relname = 'tenants';" 2>/dev/null | tail -1)
if [ "$RLS_STATUS" = "t" ]; then
    pass "Row-level security is enabled on 'tenants' table"
    log "RLS is enabled on tenants table"
else
    warn "Row-level security status unclear on 'tenants' table"
fi

# 6. Verify constraints and indexes
echo -e "${YELLOW}--- Step 6: Verify Constraints and Indexes ---${NC}"
PK_COUNT=$(psql -U medveris_runtime -d "$RESTORE_DB" -c "SELECT count(*) FROM pg_constraint WHERE contype = 'p';" 2>/dev/null | awk '{print $1}')
if [ -n "$PK_COUNT" ] && [ "$PK_COUNT" -gt 0 ]; then
    pass "Primary key constraints found: $PK_COUNT"
    log "Found $PK_COUNT primary key constraints"
else
    fail "No primary key constraints found"
fi

UIX_COUNT=$(psql -U medveris_runtime -d "$RESTORE_DB" -c "SELECT count(*) FROM pg_index WHERE indisunique = true;" 2>/dev/null | awk '{print $1}')
if [ -n "$UIX_COUNT" ] && [ "$UIX_COUNT" -gt 0 ]; then
    pass "Unique indexes found: $UIX_COUNT"
    log "Found $UIX_COUNT unique indexes"
else
    warn "No unique indexes found"
fi

# 7. Verify PostgreSQL configuration matches expected
echo -e "${YELLOW}--- Step 7: Verify PostgreSQL Configuration ---${NC}"
if psql -U medveris_runtime -d "$RESTORE_DB" -c "SHOW listen_addresses;" 2>/dev/null | grep -q "127.0.0.1"; then
    pass "PostgreSQL listen_addresses is 127.0.0.1"
else
    warn "PostgreSQL listen_addresses is not 127.0.0.1"
fi

# 8. Clean up test database
echo -e "${YELLOW}--- Step 8: Clean Up Test Database ---${NC}"
if psql -U postgres -c "DROP DATABASE \"$RESTORE_DB\"" 2>/dev/null; then
    pass "Test database '$RESTORE_DB' dropped successfully"
    log "Test database cleaned up"
else
    warn "Failed to drop test database '$RESTORE_DB'"
fi

# 9. Verify WAL files are available
echo -e "${YELLOW}--- Step 9: Verify WAL Archiving ---${NC}"
if rclone ls "r2:${R2_BACKUP_BUCKET}/wal/" | grep -q ".partial"; then
    pass "WAL files are available in R2 for PITR"
    log "WAL files available for point-in-time recovery"
else
    warn "No WAL files found in R2 - PITR may not be available"
fi

echo ""
echo -e "=== Restore Test Results ===="
echo -e "  Passed: ${GREEN}${PASS}${NC}"
echo -e "  Failed: ${RED}${FAIL}${NC}"
echo ""

# Return overall status
if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Restore test FAILED - $FAIL issues detected${NC}"
    exit 1
else
    echo -e "${GREEN}Restore test PASSED - backup restoration validated${NC}"
    exit 0
fi
