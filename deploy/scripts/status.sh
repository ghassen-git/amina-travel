#!/bin/bash
# Comprehensive status dashboard for Amina Travel production server
# Shows container status, resource usage, recent logs, and health checks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

header() {
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

section() {
    echo -e "\n${BOLD}${BLUE}▶ $1${NC}"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Main dashboard
header "AMINA TRAVEL - PRODUCTION STATUS"
echo -e "${CYAN}Server:${NC} aminatravel.org (162.35.185.169)"
echo -e "${CYAN}Time:${NC}   $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${CYAN}Uptime:${NC} $(uptime -p)"

# System Resources
section "System Resources"
echo "Memory:"
free -h | awk 'NR==1 {print "  " $0} NR==2 {printf "  Total: %s | Used: %s (%.0f%%) | Free: %s | Available: %s\n", $2, $3, ($3/$2)*100, $4, $7}'

echo ""
echo "Disk:"
df -h / | awk 'NR==1 {print "  " $0} NR==2 {printf "  %s: %s/%s used (%s) | %s free\n", $1, $3, $2, $5, $4}'

echo ""
echo "Swap:"
free -h | awk 'NR==3 {printf "  Total: %s | Used: %s | Free: %s\n", $2, $3, $4}'

echo ""
echo "Load Average:"
uptime | awk -F'load average:' '{print "  " $2}'

# Docker Containers
section "Docker Containers"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | sed 's/^/  /'

# Container Resource Usage
section "Container Resource Usage"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | sed 's/^/  /'

# Service Health Checks
section "Service Health Checks"

# API Health
if curl -sf -m 5 -H 'Host: api.aminatravel.org' http://localhost/health > /dev/null 2>&1; then
    success "API (api.aminatravel.org/health)"
else
    error "API (api.aminatravel.org/health)"
fi

# Website
if curl -sf -m 5 -H 'Host: aminatravel.org' http://localhost/ > /dev/null 2>&1; then
    success "Website (aminatravel.org)"
else
    error "Website (aminatravel.org)"
fi

# Admin
if curl -sf -m 5 -H 'Host: admin.aminatravel.org' http://localhost/ > /dev/null 2>&1; then
    success "Admin Panel (admin.aminatravel.org)"
else
    error "Admin Panel (admin.aminatravel.org)"
fi

# Public Endpoints (via Cloudflare)
section "Public Access (via Cloudflare)"

PUBLIC_WEBSITE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 https://aminatravel.org 2>/dev/null || echo "timeout")
PUBLIC_API=$(curl -s -o /dev/null -w "%{http_code}" -m 5 https://api.aminatravel.org/health 2>/dev/null || echo "timeout")

if [ "$PUBLIC_WEBSITE" == "200" ]; then
    success "Website returns HTTP $PUBLIC_WEBSITE"
else
    error "Website returns HTTP $PUBLIC_WEBSITE"
fi

if [ "$PUBLIC_API" == "200" ]; then
    success "API returns HTTP $PUBLIC_API"
else
    error "API returns HTTP $PUBLIC_API"
fi

# Recent Logs (Last 5 lines from each container)
section "Recent Logs (Last 5 lines)"

for container in amina-nginx amina-api amina-web amina-admin amina-postgres; do
    echo ""
    echo -e "${MAGENTA}[$container]${NC}"
    docker logs "$container" --tail 5 2>&1 | sed 's/^/  /'
done

# Docker System Info
section "Docker System Resources"
docker system df | sed 's/^/  /'

# Network Info
section "Network Connections"
echo "Active connections to port 80:"
netstat -an | grep ':80 ' | grep ESTABLISHED | wc -l | awk '{print "  " $1 " connections"}'

echo ""
echo "Active connections to port 443:"
netstat -an | grep ':443 ' | grep ESTABLISHED | wc -l | awk '{print "  " $1 " connections"}'

# Check for issues
section "System Warnings"

# Check disk usage
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    warning "Disk usage is ${DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
if [ "$MEMORY_USAGE" -gt 85 ]; then
    warning "Memory usage is ${MEMORY_USAGE}%"
fi

# Check for OOM events
OOM_COUNT=$(dmesg | grep -i "out of memory" | grep -i "kill" | wc -l)
if [ "$OOM_COUNT" -gt 0 ]; then
    warning "Found $OOM_COUNT OOM killer events in system logs"
fi

# Check Docker reclaimable space
DOCKER_RECLAIMABLE=$(docker system df --format '{{.Reclaimable}}' | head -1 | sed 's/GB//' | awk '{print int($1)}')
if [ "$DOCKER_RECLAIMABLE" -gt 15 ]; then
    warning "Docker has ${DOCKER_RECLAIMABLE}GB of reclaimable space. Run: docker system prune -f"
fi

# Footer
echo ""
header "End of Status Report"
echo ""
info "To view real-time container logs: docker compose -f /opt/amina-travel/deploy/docker-compose.prod.yml logs -f [service]"
info "To restart a service: docker compose -f /opt/amina-travel/deploy/docker-compose.prod.yml restart [service]"
info "To restart all: docker compose -f /opt/amina-travel/deploy/docker-compose.prod.yml restart"
echo ""
