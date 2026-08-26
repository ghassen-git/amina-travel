#!/usr/bin/env bash
#
# Amina Travel — PostgreSQL Restore Script
#
# DANGER: This script can OVERWRITE production data.
# ALWAYS test restore to a test database first.
#
# Usage:
#   TEST_MODE=1 RESTORE_DATE=2026-08-26_020000 ./restore-postgres.sh
#   RESTORE_DATE=2026-08-26_020000 ./restore-postgres.sh
#
# Environment variables required:
#   R2_ENDPOINT, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
#   BACKUP_ENCRYPTION_KEY, POSTGRES_USER, POSTGRES_DB

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

TEST_MODE="${TEST_MODE:-1}"  # Default to test mode for safety
RESTORE_DATE="${RESTORE_DATE:-}"
CONTAINER_NAME="amina-postgres"
POSTGRES_USER="${POSTGRES_USER:-amina}"
POSTGRES_DB="${POSTGRES_DB:-amina_travel}"
BACKUP_FILENAME="amina_travel_${RESTORE_DATE}.sql.gz.enc"
WORK_DIR="/tmp/restore-$(date +%s)"

# ============================================================================
# Logging
# ============================================================================

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
}

log_error() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ERROR: $*" >&2
}

log_warning() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] WARNING: $*" >&2
}

log_success() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ✓ $*"
}

# ============================================================================
# Safety Checks
# ============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required environment variables
    local missing_vars=()
    [[ -z "${R2_ENDPOINT:-}" ]] && missing_vars+=("R2_ENDPOINT")
    [[ -z "${R2_BUCKET:-}" ]] && missing_vars+=("R2_BUCKET")
    [[ -z "${R2_ACCESS_KEY_ID:-}" ]] && missing_vars+=("R2_ACCESS_KEY_ID")
    [[ -z "${R2_SECRET_ACCESS_KEY:-}" ]] && missing_vars+=("R2_SECRET_ACCESS_KEY")
    [[ -z "${BACKUP_ENCRYPTION_KEY:-}" ]] && missing_vars+=("BACKUP_ENCRYPTION_KEY")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Check RESTORE_DATE provided
    if [[ -z "${RESTORE_DATE}" ]]; then
        log_error "RESTORE_DATE not provided"
        log_error "Usage: RESTORE_DATE=2026-08-26_020000 ./restore-postgres.sh"
        return 1
    fi
    
    # Check tools available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not installed"
        return 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not installed"
        return 1
    fi
    
    # Check container running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container '${CONTAINER_NAME}' is not running"
        return 1
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

# ============================================================================
# Display Warning
# ============================================================================

show_warning() {
    if [[ ${TEST_MODE} -eq 1 ]]; then
        log "=========================================="
        log "TEST MODE: Restoring to test database"
        log "Database: ${POSTGRES_DB}_test"
        log "Production database will NOT be affected"
        log "=========================================="
    else
        log_warning "=========================================="
        log_warning "PRODUCTION RESTORE MODE"
        log_warning "This will OVERWRITE database: ${POSTGRES_DB}"
        log_warning "All current data will be LOST"
        log_warning "=========================================="
        
        read -p "Type 'RESTORE' to confirm: " confirmation
        if [[ "${confirmation}" != "RESTORE" ]]; then
            log "Restore cancelled by user"
            exit 0
        fi
        
        log_warning "Creating final safety backup of current database..."
        local safety_backup="/tmp/final-backup-before-restore-$(date +%Y%m%d-%H%M%S).sql.gz"
        if docker exec "${CONTAINER_NAME}" pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "${safety_backup}"; then
            log_success "Safety backup created: ${safety_backup}"
        else
            log_error "Safety backup failed. Aborting restore."
            exit 1
        fi
    fi
}

# ============================================================================
# Download and Decrypt
# ============================================================================

download_backup() {
    log "Downloading backup from R2..."
    
    mkdir -p "${WORK_DIR}"
    
    local remote_path="s3://${R2_BUCKET}/backups/${BACKUP_FILENAME}"
    local local_encrypted="${WORK_DIR}/backup.sql.gz.enc"
    
    if ! AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
         AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
         aws s3 cp "${remote_path}" "${local_encrypted}" \
         --endpoint-url "${R2_ENDPOINT}"; then
        log_error "Download failed. Check RESTORE_DATE and R2 credentials."
        return 1
    fi
    
    log_success "Download complete"
    
    log "Decrypting backup..."
    local local_compressed="${WORK_DIR}/backup.sql.gz"
    
    if ! openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
         -in "${local_encrypted}" \
         -out "${local_compressed}" \
         -pass "pass:${BACKUP_ENCRYPTION_KEY}"; then
        log_error "Decryption failed. Check BACKUP_ENCRYPTION_KEY."
        return 1
    fi
    
    rm -f "${local_encrypted}"
    log_success "Decryption complete"
    
    log "Decompressing backup..."
    if ! gunzip "${local_compressed}"; then
        log_error "Decompression failed"
        return 1
    fi
    
    log_success "Decompression complete"
    
    echo "${WORK_DIR}/backup.sql"
    return 0
}

# ============================================================================
# Restore Database
# ============================================================================

restore_database() {
    local sql_file="$1"
    local target_db="${POSTGRES_DB}"
    
    if [[ ${TEST_MODE} -eq 1 ]]; then
        target_db="${POSTGRES_DB}_test"
        
        log "Creating test database: ${target_db}"
        docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -c "DROP DATABASE IF EXISTS ${target_db};" || true
        docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -c "CREATE DATABASE ${target_db};"
    else
        log_warning "Dropping production database: ${target_db}"
        docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -c "DROP DATABASE ${target_db};"
        
        log_warning "Creating fresh database: ${target_db}"
        docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -c "CREATE DATABASE ${target_db};"
    fi
    
    log "Restoring SQL dump to ${target_db}..."
    if ! docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -d "${target_db}" < "${sql_file}"; then
        log_error "Restore failed"
        return 1
    fi
    
    log_success "Restore complete"
    
    log "Verifying restored database..."
    docker exec "${CONTAINER_NAME}" psql -U "${POSTGRES_USER}" -d "${target_db}" -c "
        SELECT schemaname, tablename, COUNT(*) OVER (PARTITION BY schemaname) as schema_table_count
        FROM pg_tables 
        WHERE schemaname IN ('hotels', 'bookings', 'payments', 'auth', 'promos', 'voyages', 'reservations')
        ORDER BY schemaname, tablename
        LIMIT 20;
    "
    
    log_success "Database verification complete"
    return 0
}

# ============================================================================
# Cleanup
# ============================================================================

cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "${WORK_DIR}"
    log_success "Cleanup complete"
}

# ============================================================================
# Main
# ============================================================================

main() {
    log "==================== Restore Started ===================="
    
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    show_warning
    
    local sql_file
    if ! sql_file=$(download_backup); then
        log_error "Download/decrypt failed"
        cleanup
        exit 1
    fi
    
    if ! restore_database "${sql_file}"; then
        log_error "Restore failed"
        cleanup
        exit 1
    fi
    
    cleanup
    
    log_success "==================== Restore Completed Successfully ===================="
    
    if [[ ${TEST_MODE} -eq 1 ]]; then
        log "Test database: ${POSTGRES_DB}_test"
        log "To drop test database: docker exec ${CONTAINER_NAME} psql -U ${POSTGRES_USER} -c 'DROP DATABASE ${POSTGRES_DB}_test;'"
    else
        log_warning "Production database has been restored"
        log_warning "Application containers should be restarted"
        log "Run: cd /opt/amina-travel/deploy && docker compose -f docker-compose.prod.yml restart api web admin"
    fi
    
    exit 0
}

# Run main
main "$@"
