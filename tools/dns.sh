#!/bin/bash

# Wrapper script for DNS infrastructure deployment tools
# This provides easy access to deployment tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "DNS Infrastructure Deployment Tools"
    echo ""
    echo "Usage: $0 [TOOL] [ARGS...]"
    echo ""
    echo "Tools:"
    echo "  setup       Configuration setup and validation"
    echo "  deploy      Deploy to remote server"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup interactive    # Create configuration interactively"
    echo "  $0 setup test          # Test SSH connection"
    echo "  $0 deploy full         # Full deployment"
    echo "  $0 deploy status       # Check service status"
    echo ""
    echo "Direct tool access:"
    echo "  $TOOLS_DIR/setup.sh"
    echo "  $TOOLS_DIR/deploy.sh"
}

case "${1:-help}" in
    setup)
        shift
        exec "$TOOLS_DIR/setup.sh" "$@"
        ;;
    deploy)
        shift
        exec "$TOOLS_DIR/deploy.sh" "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [[ -n "$1" ]]; then
            echo -e "${YELLOW}Unknown tool: $1${NC}"
            echo ""
        fi
        show_help
        exit 1
        ;;
esac
