#!/bin/bash
#
# BarqNet Health Monitoring Script
#
# This script checks the health of BarqNet backend services and logs results.
# Setup as a cron job to run every 5 minutes.
#
# Installation:
#   chmod +x monitor.sh
#   (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/barqnet/ChameleonVpn/barqnet-backend/scripts/monitor.sh") | crontab -
#

# Configuration
API_URL="http://localhost:8080"
LOG_DIR="/var/log/barqnet"
LOG_FILE="${LOG_DIR}/monitor.log"
ALERT_EMAIL="admin@yourdomain.com"  # Configure this
ALERT_ENABLED=false  # Set to true to enable email alerts

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create log directory if it doesn't exist
mkdir -p $LOG_DIR

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Alert function
send_alert() {
    if [ "$ALERT_ENABLED" = true ]; then
        echo "$1" | mail -s "BarqNet Alert" $ALERT_EMAIL
    fi
    log "ALERT: $1"
}

# Health check for management server
check_management_health() {
    response=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health 2>&1)

    if [ "$response" == "200" ]; then
        log "✓ Management Server: HEALTHY"
        return 0
    else
        log "✗ Management Server: UNHEALTHY (HTTP $response)"
        send_alert "Management server health check failed (HTTP $response)"
        return 1
    fi
}

# Check if service is running
check_service() {
    service_name=$1

    if systemctl is-active --quiet $service_name; then
        log "✓ Service $service_name: RUNNING"
        return 0
    else
        log "✗ Service $service_name: NOT RUNNING"
        send_alert "Service $service_name is not running"

        # Attempt to restart
        log "Attempting to restart $service_name..."
        systemctl restart $service_name

        sleep 5

        if systemctl is-active --quiet $service_name; then
            log "✓ Service $service_name: RESTARTED SUCCESSFULLY"
            send_alert "Service $service_name was restarted successfully"
            return 0
        else
            log "✗ Service $service_name: RESTART FAILED"
            send_alert "CRITICAL: Failed to restart $service_name"
            return 1
        fi
    fi
}

# Database connectivity check
check_database() {
    if sudo -u postgres psql -d barqnet -c "SELECT 1" > /dev/null 2>&1; then
        log "✓ PostgreSQL: CONNECTED"
        return 0
    else
        log "✗ PostgreSQL: CONNECTION FAILED"
        send_alert "PostgreSQL connection failed"
        return 1
    fi
}

# Database size check
check_database_size() {
    db_size=$(sudo -u postgres psql -d barqnet -t -c "SELECT pg_size_pretty(pg_database_size('barqnet'));" 2>&1 | xargs)

    if [ $? -eq 0 ]; then
        log "ℹ Database Size: $db_size"
        return 0
    else
        log "✗ Failed to check database size"
        return 1
    fi
}

# Redis connectivity check
check_redis() {
    if redis-cli ping > /dev/null 2>&1; then
        log "✓ Redis: CONNECTED"
        return 0
    else
        log "✗ Redis: CONNECTION FAILED"
        send_alert "Redis connection failed"
        return 1
    fi
}

# Disk space check
check_disk_space() {
    usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ $usage -lt 80 ]; then
        log "✓ Disk Usage: ${usage}%"
        return 0
    elif [ $usage -lt 90 ]; then
        log "⚠ Disk Usage: ${usage}% (WARNING)"
        send_alert "Disk usage is at ${usage}%"
        return 1
    else
        log "✗ Disk Usage: ${usage}% (CRITICAL)"
        send_alert "CRITICAL: Disk usage is at ${usage}%"
        return 1
    fi
}

# Memory check
check_memory() {
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')

    if [ $mem_usage -lt 90 ]; then
        log "✓ Memory Usage: ${mem_usage}%"
        return 0
    else
        log "⚠ Memory Usage: ${mem_usage}% (HIGH)"
        send_alert "Memory usage is high: ${mem_usage}%"
        return 1
    fi
}

# CPU check
check_cpu() {
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    cpu_int=${cpu_usage%.*}

    if [ $cpu_int -lt 80 ]; then
        log "✓ CPU Usage: ${cpu_usage}%"
        return 0
    else
        log "⚠ CPU Usage: ${cpu_usage}% (HIGH)"
        send_alert "CPU usage is high: ${cpu_usage}%"
        return 1
    fi
}

# Log rotation check
check_log_size() {
    log_size=$(du -sh $LOG_DIR 2>/dev/null | cut -f1)
    log "ℹ Log Directory Size: $log_size"
}

# Main monitoring routine
main() {
    log "========================================="
    log "BarqNet Health Check - Starting"
    log "========================================="

    # Service checks
    check_service "barqnet-management"
    check_service "barqnet-endnode"
    check_service "postgresql"
    check_service "redis-server"
    check_service "nginx"

    # Connectivity checks
    check_management_health
    check_database
    check_database_size
    check_redis

    # System resource checks
    check_disk_space
    check_memory
    check_cpu
    check_log_size

    log "========================================="
    log "BarqNet Health Check - Completed"
    log "========================================="
}

# Run main function
main

# Cleanup old logs (keep last 30 days)
find $LOG_DIR -name "*.log" -type f -mtime +30 -delete
