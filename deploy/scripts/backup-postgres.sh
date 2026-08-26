#!/usr/bin/env bash
#
# Amina Travel — Production PostgreSQL Backup Script
#
# Performs daily encrypted backups of PostgreSQL to Cloudflare R2.
#
# What it does:
#   1. Validates all required environment variables
#   2. Verifies the amina-postgres container is running
#   3. Creates a timestamped pg_dump
#   4. Compresses with gzip
#   5. Encrypts with openssl AES-256-CBC
#   6. Uploads to Cloudflare R2 via AWS CLI
#   7. Verifies the upload succeeded
#   8. Cleans up temporary local files
#   9. Removes R2 backups older than 30 days
#
# Exit codes:
#   0 = success
#   1 = validation failure (missing env vars, container not running)
#   2 = backup creation failure
#   3 = upload failure
#   4 = retention cleanup failure
#
# Usage:
#   DRY_RUN=1 ./backup-postgres.sh    # Test mode (no upload, no cleanup)
#   ./backup-postgres.sh               # Normal execution

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

CONTAINER_NAME="amina-postgres"
POSTGRES_USER="${POSTGRES_USER:-amina}"
POSTGRES_DB="${POSTGRES_DB:-amina_travel}"
BACKUP_DIR="/opt/amina-travel/backups"
TMP_DIR="${BACKUP_DIR}/tmp"
TIMESTAMP=$(date -u +%Y-%m-%d_%H%M%S)
BACKUP_FILENAME="amina_travel_${TIMESTAMP}.sql.gz.enc"
RETENTION_DAYS=30
DRY_RUN="${DRY_RUN:-0}"

# ============================================================================
# Logging
# ============================================================================

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
}

log_error() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ERROR: $*" >&2
}

log_success() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ✓ $*"
}

# ============================================================================
# Validation
# ============================================================================

validate_environment() {
    log "Validating environment..."
    
    local missing_vars=()
    
    # Check required R2 credentials
    [[ -z "${R2_ENDPOINT:-}" ]] && missing_vars+=("R2_ENDPOINT")
    [[ -z "${R2_BUCKET:-}" ]] && missing_vars+=("R2_BUCKET")
    [[ -z "${R2_ACCESS_KEY_ID:-}" ]] && missing_vars+=("R2_ACCESS_KEY_ID")
    [[ -z "${R2_SECRET_ACCESS_KEY:-}" ]] && missing_vars+=("R2_SECRET_ACCESS_KEY")
    [[ -z "${BACKUP_ENCRYPTION_KEY:-}" ]] && missing_vars+=("BACKUP_ENCRYPTION_KEY")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please set these in /opt/amina-travel/deploy/.env"
        return 1
    fi
    
    # Validate encryption key length (should be at least 32 characters)
    if [[ ${#BACKUP_ENCRYPTION_KEY} -lt 32 ]]; then
        log_error "BACKUP_ENCRYPTION_KEY must be at least 32 characters"
        return 1
    fi
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Install with: apt-get install awscli"
        return 1
    fi
    
    # Verify the PostgreSQL container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container '${CONTAINER_NAME}' is not running"
        log_error "Check with: docker ps -a | grep postgres"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
}

# ============================================================================
# Backup Creation
# ============================================================================

create_backup() {
    log "Creating PostgreSQL backup..."
    
    # Create backup directories
    mkdir -p "${TMP_DIR}"
    chmod 700 "${TMP_DIR}"
    
    local dump_file="${TMP_DIR}/dump_${TIMESTAMP}.sql"
    local compressed_file="${TMP_DIR}/dump_${TIMESTAMP}.sql.gz"
    local encrypted_file="${TMP_DIR}/${BACKUP_FILENAME}"
    
    # Step 1: pg_dump
    log "Running pg_dump for database '${POSTGRES_DB}'..."
    if ! docker exec "${CONTAINER_NAME}" pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > "${dump_file}"; then
        log_error "pg_dump failed"
        rm -f "${dump_file}"
        return 2
    fi
    
    # Verify dump is not empty
    local dump_size=$(stat -f%z "${dump_file}" 2>/dev/null || stat -c%s "${dump_file}" 2>/dev/null || echo 0)
    if [[ ${dump_size} -lt 1000 ]]; then
        log_error "Dump file is suspiciously small (${dump_size} bytes). Backup may be incomplete."
        rm -f "${dump_file}"
        return 2
    fi
    log_success "pg_dump completed (${dump_size} bytes)"
    
    # Step 2: Compress
    log "Compressing backup..."
    if ! gzip -9 "${dump_file}"; then
        log_error "Compression failed"
        rm -f "${dump_file}" "${compressed_file}"
        return 2
    fi
    
    local compressed_size=$(stat -f%z "${compressed_file}" 2>/dev/null || stat -c%s "${compressed_file}" 2>/dev/null || echo 0)
    log_success "Compression completed (${compressed_size} bytes)"
    
    # Step 3: Encrypt
    log "Encrypting backup with AES-256-CBC..."
    if ! openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
        -in "${compressed_file}" \
        -out "${encrypted_file}" \
        -pass "pass:${BACKUP_ENCRYPTION_KEY}"; then
        log_error "Encryption failed"
        rm -f "${compressed_file}" "${encrypted_file}"
        return 2
    fi
    
    # Clean up unencrypted files immediately
    rm -f "${compressed_file}"
    
    local encrypted_size=$(stat -f%z "${encrypted_file}" 2>/dev/null || stat -c%s "${encrypted_file}" 2>/dev/null || echo 0)
    if [[ ${encrypted_size} -lt 100 ]]; then
        log_error "Encrypted file is suspiciously small (${encrypted_size} bytes)"
        rm -f "${encrypted_file}"
        return 2
    fi
    log_success "Encryption completed (${encrypted_size} bytes)"
    
    echo "${encrypted_file}"
    return 0
}

# ============================================================================
# Upload to R2
# ============================================================================

upload_to_r2() {
    local local_file="$1"
    local remote_key="backups/${BACKUP_FILENAME}"
    
    if [[ ${DRY_RUN} -eq 1 ]]; then
        log "[DRY RUN] Would upload ${local_file} to s3://${R2_BUCKET}/${remote_key}"
        return 0
    fi
    
    log "Uploading to Cloudflare R2: s3://${R2_BUCKET}/${remote_key}..."
    
    # Upload using AWS CLI with R2 endpoint
    if ! AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
         AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
         aws s3 cp "${local_file}" "s3://${R2_BUCKET}/${remote_key}" \
         --endpoint-url "${R2_ENDPOINT}" \
         --no-progress; then
        log_error "Upload to R2 failed"
        return 3
    fi
    
    # Verify the upload
    log "Verifying upload..."
    if ! AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
         AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
         aws s3 ls "s3://${R2_BUCKET}/${remote_key}" \
         --endpoint-url "${R2_ENDPOINT}" &> /dev/null; then
        log_error "Upload verification failed - file not found in R2"
        return 3
    fi
    
    log_success "Upload verified successfully"
    return 0
}

# ============================================================================
# Retention Management
# ============================================================================

cleanup_old_backups() {
    if [[ ${DRY_RUN} -eq 1 ]]; then
        log "[DRY RUN] Would clean up backups older than ${RETENTION_DAYS} days"
        return 0
    fi
    
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    # Calculate cutoff date
    local cutoff_date=$(date -u -d "${RETENTION_DAYS} days ago" +%Y-%m-%d 2>/dev/null || date -u -v-${RETENTION_DAYS}d +%Y-%m-%d 2>/dev/null)
    
    # List all backups in R2
    local backup_list=$(AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
                        AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
                        aws s3 ls "s3://${R2_BUCKET}/backups/" \
                        --endpoint-url "${R2_ENDPOINT}" \
                        --recursive | awk '{print $4}' || echo "")
    
    if [[ -z "${backup_list}" ]]; then
        log "No backups found in R2 (this is normal for first run)"
        return 0
    fi
    
    local deleted_count=0
    while IFS= read -r backup_key; do
        [[ -z "${backup_key}" ]] && continue
        
        # Extract date from filename: backups/amina_travel_YYYY-MM-DD_HHMMSS.sql.gz.enc
        if [[ ${backup_key} =~ amina_travel_([0-9]{4}-[0-9]{2}-[0-9]{2})_ ]]; then
            local backup_date="${BASH_REMATCH[1]}"
            
            if [[ "${backup_date}" < "${cutoff_date}" ]]; then
                log "Deleting old backup: ${backup_key} (${backup_date})"
                if AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
                   AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
                   aws s3 rm "s3://${R2_BUCKET}/${backup_key}" \
                   --endpoint-url "${R2_ENDPOINT}"; then
                    ((deleted_count++))
                else
                    log_error "Failed to delete ${backup_key}"
                fi
            fi
        fi
    done <<< "${backup_list}"
    
    if [[ ${deleted_count} -gt 0 ]]; then
        log_success "Deleted ${deleted_count} old backup(s)"
    else
        log "No old backups to delete"
    fi
    
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log "==================== Backup Started ===================="
    
    if [[ ${DRY_RUN} -eq 1 ]]; then
        log "** DRY RUN MODE - No actual changes will be made **"
    fi
    
    # Validate environment
    if ! validate_environment; then
        log_error "Backup aborted due to validation failure"
        exit 1
    fi
    
    # Create backup
    local backup_file
    if ! backup_file=$(create_backup); then
        log_error "Backup creation failed"
        exit 2
    fi
    
    # Upload to R2
    if ! upload_to_r2 "${backup_file}"; then
        log_error "Upload failed"
        # Keep the local file for manual upload
        log "Local backup preserved at: ${backup_file}"
        exit 3
    fi
    
    # Clean up local temporary files
    log "Removing temporary local backup..."
    rm -f "${backup_file}"
    log_success "Temporary files cleaned up"
    
    # Clean up old backups in R2
    if ! cleanup_old_backups; then
        log_error "Retention cleanup encountered errors"
        # Don't fail the whole backup for cleanup issues
    fi
    
    log_success "==================== Backup Completed Successfully ===================="
    
    # Summary
    log "Backup: s3://${R2_BUCKET}/backups/${BACKUP_FILENAME}"
    log "Retention: ${RETENTION_DAYS} days"
    log "Next backup: $(date -u -d '1 day' '+%Y-%m-%d 02:00:00 UTC' 2>/dev/null || date -u -v+1d '+%Y-%m-%d 02:00:00 UTC' 2>/dev/null)"
    
    exit 0
}

# Run main function
main "$@"
