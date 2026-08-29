#!/bin/bash
# Resource monitoring script for Amina Travel server
# Monitors disk space, memory usage, and Docker resource consumption
# Sends alerts when thresholds are exceeded

set -e

# Thresholds
DISK_THRESHOLD=85          # Alert if disk usage > 85%
MEMORY_THRESHOLD=90        # Alert if memory usage > 90%
DOCKER_DISK_THRESHOLD=20   # Alert if Docker has > 20GB of unused data

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ALERT:${NC} $1"
}

# Check disk space
check_disk() {
    log "Checking disk space..."
    
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
        error "Disk usage is ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
        df -h /
        return 1
    else
        log "✓ Disk usage: ${DISK_USAGE}%"
        return 0
    fi
}

# Check memory usage
check_memory() {
    log "Checking memory usage..."
    
    MEMORY_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
    
    if [ "$MEMORY_USAGE" -ge "$MEMORY_THRESHOLD" ]; then
        error "Memory usage is ${MEMORY_USAGE}% (threshold: ${MEMORY_THRESHOLD}%)"
        free -h
        return 1
    else
        log "✓ Memory usage: ${MEMORY_USAGE}%"
        return 0
    fi
}

# Check Docker resource usage
check_docker() {
    log "Checking Docker resource usage..."
    
    # Check for unused Docker data
    DOCKER_RECLAIMABLE=$(docker system df --format '{{.Reclaimable}}' | head -1 | sed 's/GB//' | awk '{print int($1)}')
    
    if [ "$DOCKER_RECLAIMABLE" -ge "$DOCKER_DISK_THRESHOLD" ]; then
        warn "Docker has ${DOCKER_RECLAIMABLE}GB of reclaimable space"
        docker system df
        
        # Optionally clean up (commented out for safety)
        # docker system prune -f --volumes
        
        return 1
    else
        log "✓ Docker disk usage acceptable"
        return 0
    fi
}

# Check for OOM killer events
check_oom() {
    log "Checking for OOM (Out of Memory) events..."
    
    OOM_COUNT=$(dmesg | grep -i "out of memory" | grep -i "kill" | wc -l)
    
    if [ "$OOM_COUNT" -gt 0 ]; then
        error "Found $OOM_COUNT OOM killer events in system logs"
        dmesg | grep -i "out of memory" | tail -10
        return 1
    else
        log "✓ No OOM events detected"
        return 0
    fi
}

# Check container resource usage
check_container_stats() {
    log "Container resource usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Main execution
main() {
    log "=== Resource Monitoring Check ==="
    
    ISSUES=0
    
    check_disk || ((ISSUES++))
    check_memory || ((ISSUES++))
    check_docker || ((ISSUES++))
    check_oom || ((ISSUES++))
    check_container_stats
    
    echo ""
    if [ "$ISSUES" -eq 0 ]; then
        log "✓ All resource checks passed"
        exit 0
    else
        error "Found $ISSUES resource issues"
        exit 1
    fi
}

main
