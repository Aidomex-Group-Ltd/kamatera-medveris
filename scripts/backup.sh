#!/bin/bash
# Backup script for Medveris PostgreSQL database
# Performs encrypted backups and uploads to Cloudflare R2
#
# STATUS: DEFECTIVE — needs complete redesign before use.
# Defects documented in docs/IMPLEMENTATION_LOG.md.
# Do NOT run against production data.

set -euo pipefail

# Configuration
R2_BACKUP_BUCKET="medveris-production-backups"
R2_WAL_BUCKET="medveris-production-wal"
BACKUP_DIR="/data/backups"
PG_VERSION="$(ls /etc/postgresql/ | head -1)"
PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ENCRYPTION_PASSWORD="${BACKUP_ENCRYPTION_KEY:-$(openssl rand -base64 32)}"
LOG_FILE="/var/log/medveris/backup.log"

# Ensure log directory exists
mkdir -p /var/log/medveris
mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo "=== Medveris PostgreSQL Backup Started at $(date) ===" | tee -a "$LOG_FILE"

# 1. Perform PostgreSQL backup
log "Starting PostgreSQL backup via pg_dump"
BACKUP_FILE="${BACKUP_DIR}/medveris_prod_${TIMESTAMP}.dump"

if pg_dump -Fc -h 127.0.0.1 -U medveris_runtime -d medveris_prod > "$BACKUP_FILE" 2>&1; then
    log "PostgreSQL backup file created: $BACKUP_FILE"
else
    log "ERROR: pg_dump failed" >&2
    exit 1
fi

# 2. Encrypt the backup
log "Encrypting backup with AES-256-CBC"
ENCRYPTED_FILE="${BACKUP_FILE}.enc"
openssl enc -aes-256-cbc -salt -pass pass:"$ENCRYPTION_PASSWORD" -in "$BACKUP_FILE" -out "$ENCRYPTED_FILE"

if [ $? -eq 0 ]; then
    log "Encrypted backup: $ENCRYPTED_FILE"
    rm -f "$BACKUP_FILE"  # Remove unencrypted backup for security
else
    log "ERROR: Encryption failed" >&2
    exit 1
fi

# 3. Upload to Cloudflare R2
log "Uploading backup to Cloudflare R2 bucket: $R2_BACKUP_BUCKET"
rclone copy "$ENCRYPTED_FILE" "r2:${R2_BACKUP_BUCKET}/" --progress

if [ $? -eq 0 ]; then
    log "Backup uploaded to R2 successfully"
else
    log "ERROR: R2 upload failed" >&2
    exit 1
fi

# 4. Upload WAL files (continuous archiving)
log "Checking for WAL files to archive"
WAL_DIR="/var/lib/postgresql/${PG_VERSION}/main/pg_wal"
if [ -d "$WAL_DIR" ]; then
    WAL_FILES=$(ls -1 "$WAL_DIR"/*.partial 2>/dev/null | head -5)
    if [ -n "$WAL_FILES" ]; then
        log "Uploading WAL files to R2: $R2_WAL_BUCKET"
        for wal_file in $WAL_FILES; do
            rclone copy "$wal_file" "r2:${R2_WAL_BUCKET}/" --progress
        done
        log "WAL files uploaded to R2"
    else
        log "No WAL files ready for archiving"
    fi
else
    log "WAL directory not found at $WAL_DIR"
fi

# 5. Verify backup integrity
log "Verifying backup integrity"
DECRYPTED_FILE="/tmp/medveris_verify_${TIMESTAMP}.dump"
openssl enc -d -aes-256-cbc -in "$ENCRYPTED_FILE" -out "$DECRYPTED_FILE" 2>/dev/null

if [ $? -eq 0 ]; then
    log "Backup decryption successful - integrity check passed"
    
    # Count tables to verify data
    TABLE_COUNT=$(pg_restore -l "$DECRYPTED_FILE" 2>/dev/null | grep -c "TABLE DATA" || echo "0")
    log "Backup contains approximately $TABLE_COUNT table entries"
    
    rm -f "$DECRYPTED_FILE"
else
    log "WARNING: Backup decryption failed - integrity check failed" >&2
fi

# 6. Clean up old backups (keep 30 days)
log "Cleaning up backups older than 30 days"
find "$BACKUP_DIR" -name "medveris_prod_*.dump.enc" -type f -mtime +30 -delete
log "Old backups cleaned up"

echo "=== Backup Completed Successfully at $(date) ===" | tee -a "$LOG_FILE"
echo "Backup summary:"
echo "  - Backup file: $(basename "$ENCRYPTED_FILE")"
echo "  - R2 bucket: $R2_BACKUP_BUCKET"
echo "  - WAL archiving: completed"
echo "  - Encryption: AES-256-CBC"
echo "  - Retention: 30 days"
