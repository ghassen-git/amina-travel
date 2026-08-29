#!/bin/bash
# Health check script for Amina Travel services
# Checks if all containers are running and healthy
# If not, attempts to restart them

set -e

DEPLOY_DIR="/opt/amina-travel/deploy"
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if containers are running
check_containers() {
    cd "$DEPLOY_DIR"
    
    REQUIRED_CONTAINERS=("amina-postgres" "amina-api" "amina-web" "amina-admin" "amina-nginx")
    ALL_HEALTHY=true
    
    for container in "${REQUIRED_CONTAINERS[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            error "Container $container is not running"
            ALL_HEALTHY=false
        else
            log "✓ Container $container is running"
        fi
    done
    
    echo "$ALL_HEALTHY"
}

# Check if services are responding
check_services() {
    log "Checking service health..."
    
    # Check API health endpoint
    if curl -sf -m 10 -H 'Host: api.aminatravel.org' http://localhost/health > /dev/null 2>&1; then
        log "✓ API health check passed"
    else
        error "API health check failed"
        return 1
    fi
    
    # Check website
    if curl -sf -m 10 -H 'Host: aminatravel.org' http://localhost/ > /dev/null 2>&1; then
        log "✓ Website responding"
    else
        error "Website not responding"
        return 1
    fi
    
    # Check admin
    if curl -sf -m 10 -H 'Host: admin.aminatravel.org' http://localhost/ > /dev/null 2>&1; then
        log "✓ Admin panel responding"
    else
        error "Admin panel not responding"
        return 1
    fi
    
    return 0
}

# Restart services
restart_services() {
    warn "Attempting to restart services..."
    cd "$DEPLOY_DIR"
    
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" restart
    
    # Wait for services to start
    sleep 15
    
    # Check if restart was successful
    if check_services; then
        log "Services restarted successfully"
        return 0
    else
        error "Services failed to restart properly"
        return 1
    fi
}

# Main execution
main() {
    log "Starting health check..."
    
    # Check if containers are running
    if [[ "$(check_containers)" == "false" ]]; then
        warn "Some containers are down"
        restart_services
        exit $?
    fi
    
    # Check if services are responding
    if ! check_services; then
        warn "Services are not responding properly"
        restart_services
        exit $?
    fi
    
    log "All checks passed ✓"
    exit 0
}

main
