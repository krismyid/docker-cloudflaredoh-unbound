#!/bin/bash

# Remote DNS Infrastructure Deployment Script
# Configurable deployment to remote servers

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/deploy.config"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    echo "Please copy tools/config/deploy.config.template to tools/config/deploy.config and customize it."
    exit 1
fi

# Validate required configuration
if [[ -z "$REMOTE_HOST" || -z "$REMOTE_USER" || -z "$REMOTE_DIR" ]]; then
    echo "ERROR: Missing required configuration. Please check deploy.config"
    echo "Required: REMOTE_HOST, REMOTE_USER, REMOTE_DIR"
    exit 1
fi

# Default values
DOCKER_COMPOSE_CMD="${DOCKER_COMPOSE_CMD:-docker compose}"
SSH_PORT="${SSH_PORT:-22}"
BACKUP_BEFORE_DEPLOY="${BACKUP_BEFORE_DEPLOY:-true}"
AUTO_START_SERVICES="${AUTO_START_SERVICES:-true}"
CHECK_DEPENDENCIES="${CHECK_DEPENDENCIES:-true}"

# Build SSH command
SSH_CMD="ssh"
if [[ -n "$SSH_KEY" ]]; then
    SSH_CMD="$SSH_CMD -i $SSH_KEY"
fi
if [[ "$SSH_PORT" != "22" ]]; then
    SSH_CMD="$SSH_CMD -p $SSH_PORT"
fi
if [[ -n "$SSH_OPTIONS" ]]; then
    SSH_CMD="$SSH_CMD $SSH_OPTIONS"
fi
SSH_CMD="$SSH_CMD $REMOTE_USER@$REMOTE_HOST"

# Build rsync command  
RSYNC_CMD="rsync -avz --exclude='.git' --exclude='tools'"
if [[ -n "$SSH_KEY" ]]; then
    RSYNC_CMD="$RSYNC_CMD -e 'ssh -i $SSH_KEY'"
fi
if [[ "$SSH_PORT" != "22" ]]; then
    RSYNC_CMD="$RSYNC_CMD -e 'ssh -p $SSH_PORT'"
fi

LOCAL_DIR="$(dirname "$SCRIPT_DIR")"

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
    log "Testing SSH connection to $REMOTE_USER@$REMOTE_HOST..."
    if $SSH_CMD "echo 'SSH connection successful'" > /dev/null 2>&1; then
        log "SSH connection to $REMOTE_HOST successful"
    else
        error "Cannot connect to $REMOTE_HOST via SSH"
        echo "Command used: $SSH_CMD"
        exit 1
    fi
}

# Deploy files to remote server
deploy() {
    log "Deploying DNS infrastructure to $REMOTE_USER@$REMOTE_HOST..."
    
    # Create backup if enabled
    if [[ "$BACKUP_BEFORE_DEPLOY" == "true" ]]; then
        log "Creating backup on remote server..."
        $SSH_CMD "cd $REMOTE_DIR 2>/dev/null && tar -czf dns-backup-\$(date +%Y%m%d-%H%M%S).tar.gz * 2>/dev/null || true" || true
    fi
    
    # Create remote directory
    $SSH_CMD "mkdir -p $REMOTE_DIR"
    
    # Copy files
    log "Copying configuration files..."
    eval "$RSYNC_CMD" \
        "$LOCAL_DIR/" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
    
    # Make scripts executable on remote
    $SSH_CMD "chmod +x $REMOTE_DIR/manage.sh"
    
    log "Files deployed successfully to $REMOTE_HOST:$REMOTE_DIR"
}

# Start services on remote server
start_remote() {
    log "Starting DNS services on $REMOTE_HOST..."
    
    $SSH_CMD "cd $REMOTE_DIR && ./manage.sh start"
    
    log "Services started on $REMOTE_HOST"
}

# Stop services on remote server
stop_remote() {
    log "Stopping DNS services on $REMOTE_HOST..."
    
    $SSH_CMD "cd $REMOTE_DIR && ./manage.sh stop"
    
    log "Services stopped on $REMOTE_HOST"
}

# Check status on remote server
status_remote() {
    log "Checking status on $REMOTE_HOST..."
    
    $SSH_CMD "cd $REMOTE_DIR && ./manage.sh status"
}

# Show logs from remote server
logs_remote() {
    log "Fetching logs from $REMOTE_HOST..."
    
    if [ $# -eq 1 ]; then
        $SSH_CMD "cd $REMOTE_DIR && ./manage.sh logs $1"
    else
        $SSH_CMD "cd $REMOTE_DIR && ./manage.sh logs"
    fi
}

# Test DNS from remote server
test_remote() {
    log "Testing DNS performance on $REMOTE_HOST..."
    
    $SSH_CMD "cd $REMOTE_DIR && ./manage.sh test"
}

# Install Docker on remote server if needed
install_docker_remote() {
    log "Installing Docker on $REMOTE_HOST..."
    
    $SSH_CMD "bash -s" << 'ENDSSH'
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
    
    if $SSH_CMD "command -v docker &> /dev/null && docker compose version &> /dev/null"; then
        log "Docker and Docker Compose are installed on $REMOTE_HOST"
        $SSH_CMD "docker --version && docker compose version"
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
    $SSH_CMD "cd $REMOTE_DIR && ./manage.sh update"
    
    log "Remote deployment updated"
}

# Full deployment (deploy + start)
full_deploy() {
    test_connection
    if [[ "$CHECK_DEPENDENCIES" == "true" ]]; then
        check_docker_remote
    fi
    deploy
    if [[ "$AUTO_START_SERVICES" == "true" ]]; then
        start_remote
        status_remote
    fi
}

# SSH into remote server
ssh_remote() {
    log "Opening SSH session to $REMOTE_HOST..."
    $SSH_CMD -t "cd $REMOTE_DIR && bash"
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
    echo "  Remote Host: $REMOTE_USER@$REMOTE_HOST"
    echo "  Remote Dir:  $REMOTE_DIR"
    echo "  SSH Port:    $SSH_PORT"
    echo "  Config File: $CONFIG_FILE"
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
