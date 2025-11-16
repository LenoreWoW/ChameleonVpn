#!/bin/bash
#
# BarqNet Backup Script
#
# This script backs up the BarqNet database, configuration files, and logs.
# Setup as a cron job to run daily.
#
# Installation:
#   chmod +x backup.sh
#   (crontab -l 2>/dev/null; echo "0 2 * * * /opt/barqnet/ChameleonVpn/barqnet-backend/scripts/backup.sh") | crontab -
#

# Configuration
BACKUP_ROOT="/opt/barqnet/backups"
APP_DIR="/opt/barqnet/ChameleonVpn/barqnet-backend"
DB_NAME="barqnet"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Backup directories
DB_BACKUP_DIR="${BACKUP_ROOT}/database"
CONFIG_BACKUP_DIR="${BACKUP_ROOT}/config"
LOG_BACKUP_DIR="${BACKUP_ROOT}/logs"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Create backup directories
create_backup_dirs() {
    log "Creating backup directories..."
    mkdir -p "$DB_BACKUP_DIR"
    mkdir -p "$CONFIG_BACKUP_DIR"
    mkdir -p "$LOG_BACKUP_DIR"
}

# Backup database
backup_database() {
    log "Backing up PostgreSQL database: $DB_NAME..."

    backup_file="${DB_BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"

    if sudo -u postgres pg_dump $DB_NAME | gzip > "$backup_file"; then
        size=$(du -h "$backup_file" | cut -f1)
        log "✓ Database backup completed: $backup_file ($size)"
        return 0
    else
        error "Database backup failed!"
        return 1
    fi
}

# Backup configuration files
backup_config() {
    log "Backing up configuration files..."

    backup_file="${CONFIG_BACKUP_DIR}/config_${DATE}.tar.gz"

    tar -czf "$backup_file" \
        -C / \
        opt/barqnet/ChameleonVpn/barqnet-backend/.env \
        etc/systemd/system/barqnet-management.service \
        etc/systemd/system/barqnet-endnode.service \
        etc/nginx/sites-available/barqnet \
        etc/letsencrypt/live 2>/dev/null

    if [ $? -eq 0 ]; then
        size=$(du -h "$backup_file" | cut -f1)
        log "✓ Configuration backup completed: $backup_file ($size)"
        return 0
    else
        warn "Configuration backup completed with some warnings"
        return 1
    fi
}

# Backup application logs
backup_logs() {
    log "Backing up application logs..."

    backup_file="${LOG_BACKUP_DIR}/logs_${DATE}.tar.gz"

    tar -czf "$backup_file" \
        -C / \
        var/log/barqnet \
        var/log/nginx 2>/dev/null

    if [ $? -eq 0 ]; then
        size=$(du -h "$backup_file" | cut -f1)
        log "✓ Logs backup completed: $backup_file ($size)"
        return 0
    else
        warn "Logs backup completed with some warnings"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."

    # Database backups
    deleted_count=$(find "$DB_BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
    log "Deleted $deleted_count old database backup(s)"

    # Config backups
    deleted_count=$(find "$CONFIG_BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
    log "Deleted $deleted_count old config backup(s)"

    # Log backups
    deleted_count=$(find "$LOG_BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
    log "Deleted $deleted_count old log backup(s)"
}

# Verify backups
verify_backups() {
    log "Verifying backups..."

    # Check database backup
    latest_db_backup=$(ls -t "$DB_BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
    if [ -f "$latest_db_backup" ]; then
        if gunzip -t "$latest_db_backup" 2>/dev/null; then
            log "✓ Database backup integrity: OK"
        else
            error "Database backup is corrupted!"
            return 1
        fi
    else
        error "No database backup found!"
        return 1
    fi

    # Check config backup
    latest_config_backup=$(ls -t "$CONFIG_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -f "$latest_config_backup" ]; then
        if tar -tzf "$latest_config_backup" > /dev/null 2>&1; then
            log "✓ Config backup integrity: OK"
        else
            error "Config backup is corrupted!"
            return 1
        fi
    fi

    return 0
}

# Generate backup report
generate_report() {
    log "Generating backup report..."

    report_file="${BACKUP_ROOT}/backup_report_${DATE}.txt"

    cat > "$report_file" <<EOF
BarqNet Backup Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

========================================
Backup Summary
========================================

Database Backups:
$(ls -lh "$DB_BACKUP_DIR" | tail -5)

Configuration Backups:
$(ls -lh "$CONFIG_BACKUP_DIR" | tail -5)

Log Backups:
$(ls -lh "$LOG_BACKUP_DIR" | tail -5)

========================================
Disk Usage
========================================

Total Backup Size: $(du -sh "$BACKUP_ROOT" | cut -f1)

Database Backups: $(du -sh "$DB_BACKUP_DIR" | cut -f1)
Config Backups: $(du -sh "$CONFIG_BACKUP_DIR" | cut -f1)
Log Backups: $(du -sh "$LOG_BACKUP_DIR" | cut -f1)

========================================
Latest Backups
========================================

Database: $(ls -t "$DB_BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
Config: $(ls -t "$CONFIG_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
Logs: $(ls -t "$LOG_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)

========================================
Retention Policy
========================================

Retention Period: $RETENTION_DAYS days
Old backups are automatically cleaned up.

EOF

    log "Report generated: $report_file"
}

# Main backup routine
main() {
    log "========================================="
    log "BarqNet Backup - Starting"
    log "========================================="

    # Create directories
    create_backup_dirs

    # Perform backups
    backup_database
    backup_config
    backup_logs

    # Cleanup old backups
    cleanup_old_backups

    # Verify backups
    verify_backups

    # Generate report
    generate_report

    log "========================================="
    log "BarqNet Backup - Completed"
    log "========================================="

    # Display summary
    log ""
    log "Backup Summary:"
    log "  Total Size: $(du -sh "$BACKUP_ROOT" | cut -f1)"
    log "  Location: $BACKUP_ROOT"
    log "  Retention: $RETENTION_DAYS days"
}

# Run main function
main
