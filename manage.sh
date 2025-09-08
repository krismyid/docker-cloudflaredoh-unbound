#!/bin/bash

# DNS Infrastructure Management Script
# For the cloudflared + unbound Docker setup

set -e

COMPOSE_FILE="docker-compose.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Check if docker-compose is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
}

# Start services
start() {
    log "Starting DNS infrastructure..."
    cd "$SCRIPT_DIR"
    
    # Check if port 53 is available
    if netstat -tulpn 2>/dev/null | grep -q ":53 "; then
        warn "Port 53 appears to be in use. This might cause conflicts."
        echo "Consider stopping systemd-resolved: sudo systemctl stop systemd-resolved"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    docker-compose up -d
    log "Services started successfully"
    
    # Wait for services to be healthy
    log "Waiting for services to become healthy..."
    sleep 10
    status
}

# Stop services
stop() {
    log "Stopping DNS infrastructure..."
    cd "$SCRIPT_DIR"
    docker-compose down
    log "Services stopped successfully"
}

# Restart services
restart() {
    log "Restarting DNS infrastructure..."
    stop
    sleep 2
    start
}

# Show status
status() {
    log "Checking service status..."
    cd "$SCRIPT_DIR"
    
    echo -e "\n${BLUE}=== Container Status ===${NC}"
    docker-compose ps
    
    echo -e "\n${BLUE}=== Health Checks ===${NC}"
    docker-compose exec -T cloudflared nslookup google.com 127.0.0.1 2>/dev/null || warn "Cloudflared health check failed"
    docker-compose exec -T unbound drill @127.0.0.1 google.com 2>/dev/null || warn "Unbound health check failed"
    
    echo -e "\n${BLUE}=== Network Test ===${NC}"
    if command -v dig &> /dev/null; then
        dig @127.0.0.1 cloudflare.com +short || warn "External DNS test failed"
    else
        nslookup cloudflare.com 127.0.0.1 || warn "External DNS test failed"
    fi
}

# Show logs
logs() {
    cd "$SCRIPT_DIR"
    if [ $# -eq 1 ]; then
        docker-compose logs -f "$1"
    else
        docker-compose logs -f
    fi
}

# Test DNS performance
test_performance() {
    log "Testing DNS performance..."
    
    if ! command -v dig &> /dev/null; then
        error "dig command not found. Install dnsutils package."
        exit 1
    fi
    
    echo -e "\n${BLUE}=== DNS Performance Test ===${NC}"
    
    domains=("google.com" "cloudflare.com" "github.com" "stackoverflow.com")
    
    for domain in "${domains[@]}"; do
        echo -n "Testing $domain: "
        time_result=$(dig @127.0.0.1 "$domain" | grep "Query time:" | awk '{print $4 " " $5}')
        echo "$time_result"
    done
    
    echo -e "\n${BLUE}=== Cache Performance Test ===${NC}"
    echo "First query (cache miss):"
    time dig @127.0.0.1 example.org +noall +stats | grep "Query time"
    
    echo "Second query (cache hit):"
    time dig @127.0.0.1 example.org +noall +stats | grep "Query time"
}

# Update containers
update() {
    log "Updating containers..."
    cd "$SCRIPT_DIR"
    
    docker-compose pull
    docker-compose up -d
    
    log "Containers updated successfully"
    status
}

# Backup configuration
backup() {
    log "Creating configuration backup..."
    
    backup_file="dns-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$backup_file" docker-compose.yml unbound.conf README.md manage.sh 2>/dev/null
    
    log "Backup created: $backup_file"
}

# Show help
show_help() {
    echo "DNS Infrastructure Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start the DNS infrastructure"
    echo "  stop        Stop the DNS infrastructure"
    echo "  restart     Restart the DNS infrastructure"
    echo "  status      Show service status and health"
    echo "  logs [svc]  Show logs (optionally for specific service)"
    echo "  test        Test DNS performance"
    echo "  update      Update container images"
    echo "  backup      Create configuration backup"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs unbound"
    echo "  $0 test"
}

# Main script logic
main() {
    check_docker
    
    case "${1:-help}" in
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "${2:-}"
            ;;
        test)
            test_performance
            ;;
        update)
            update
            ;;
        backup)
            backup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
