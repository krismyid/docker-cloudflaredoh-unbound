#!/bin/bash

# Remote DNS Infrastructure Deployment Script
# Deploys to 'applebun' server via SSH

set -e

# Configuration
REMOTE_HOST="applebun"
REMOTE_USER="krismyid"
REMOTE_DIR="/home/krismyid/docker-cloudflaredoh-unbound"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Test SSH connection
test_connection() {
    log "Testing SSH connection to $REMOTE_HOST..."
    if ssh "$REMOTE_HOST" "echo 'SSH connection successful'" > /dev/null 2>&1; then
        log "SSH connection to $REMOTE_HOST successful"
    else
        error "Cannot connect to $REMOTE_HOST via SSH"
        exit 1
    fi
}

# Deploy files to remote server
deploy() {
    log "Deploying DNS infrastructure to $REMOTE_HOST..."
    
    # Create remote directory
    ssh "$REMOTE_HOST" "mkdir -p $REMOTE_DIR"
    
    # Copy files
    log "Copying configuration files..."
    rsync -avz --exclude='.git' \
        "$LOCAL_DIR/" \
        "$REMOTE_HOST:$REMOTE_DIR/"
    
    # Make scripts executable
    ssh "$REMOTE_HOST" "chmod +x $REMOTE_DIR/manage.sh $REMOTE_DIR/deploy.sh"
    
    log "Files deployed successfully to $REMOTE_HOST:$REMOTE_DIR"
}

# Start services on remote server
start_remote() {
    log "Starting DNS services on $REMOTE_HOST..."
    
    ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh start"
    
    log "Services started on $REMOTE_HOST"
}

# Stop services on remote server
stop_remote() {
    log "Stopping DNS services on $REMOTE_HOST..."
    
    ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh stop"
    
    log "Services stopped on $REMOTE_HOST"
}

# Check status on remote server
status_remote() {
    log "Checking status on $REMOTE_HOST..."
    
    ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh status"
}

# Show logs from remote server
logs_remote() {
    log "Fetching logs from $REMOTE_HOST..."
    
    if [ $# -eq 1 ]; then
        ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh logs $1"
    else
        ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh logs"
    fi
}

# Test DNS from remote server
test_remote() {
    log "Testing DNS performance on $REMOTE_HOST..."
    
    ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh test"
}

# Install Docker on remote server if needed
install_docker_remote() {
    log "Installing Docker on $REMOTE_HOST..."
    
    ssh "$REMOTE_HOST" "bash -s" << 'ENDSSH'
# Update package index
sudo apt update

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt update

# Install Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

echo "Docker installation completed. Please log out and back in for group changes to take effect."
ENDSSH

    log "Docker installation completed on $REMOTE_HOST"
}

# Check if Docker is installed on remote
check_docker_remote() {
    log "Checking Docker installation on $REMOTE_HOST..."
    
    if ssh "$REMOTE_HOST" "command -v docker &> /dev/null && command -v docker-compose &> /dev/null"; then
        log "Docker and Docker Compose are installed on $REMOTE_HOST"
        ssh "$REMOTE_HOST" "docker --version && docker-compose --version"
    else
        warn "Docker or Docker Compose not found on $REMOTE_HOST"
        read -p "Install Docker on remote server? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker_remote
        else
            error "Docker is required for this setup"
            exit 1
        fi
    fi
}

# Update remote deployment
update_remote() {
    log "Updating deployment on $REMOTE_HOST..."
    
    deploy
    ssh "$REMOTE_HOST" "cd $REMOTE_DIR && ./manage.sh update"
    
    log "Remote deployment updated"
}

# Full deployment (deploy + start)
full_deploy() {
    test_connection
    check_docker_remote
    deploy
    start_remote
    status_remote
}

# SSH into remote server
ssh_remote() {
    log "Opening SSH session to $REMOTE_HOST..."
    ssh "$REMOTE_HOST" -t "cd $REMOTE_DIR && bash"
}

# Show help
show_help() {
    echo "Remote DNS Infrastructure Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy       Deploy files to remote server"
    echo "  start        Start services on remote server"
    echo "  stop         Stop services on remote server" 
    echo "  restart      Restart services on remote server"
    echo "  status       Check status on remote server"
    echo "  logs [svc]   Show logs from remote server"
    echo "  test         Test DNS performance on remote server"
    echo "  update       Update deployment on remote server"
    echo "  full         Full deployment (deploy + start)"
    echo "  ssh          SSH into remote server"
    echo "  install      Install Docker on remote server"
    echo "  check        Check Docker installation on remote"
    echo "  help         Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Remote Host: $REMOTE_HOST"
    echo "  Remote Dir:  $REMOTE_DIR"
    echo ""
    echo "Examples:"
    echo "  $0 full         # Complete deployment"
    echo "  $0 deploy       # Just copy files"
    echo "  $0 status       # Check service status"
    echo "  $0 logs unbound # Show unbound logs"
    echo "  $0 ssh          # Open SSH session"
}

# Main script logic
main() {
    case "${1:-help}" in
        deploy)
            test_connection
            deploy
            ;;
        start)
            test_connection
            start_remote
            ;;
        stop)
            test_connection
            stop_remote
            ;;
        restart)
            test_connection
            stop_remote
            sleep 2
            start_remote
            ;;
        status)
            test_connection
            status_remote
            ;;
        logs)
            test_connection
            logs_remote "${2:-}"
            ;;
        test)
            test_connection
            test_remote
            ;;
        update)
            test_connection
            update_remote
            ;;
        full)
            full_deploy
            ;;
        ssh)
            ssh_remote
            ;;
        install)
            test_connection
            install_docker_remote
            ;;
        check)
            test_connection
            check_docker_remote
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
