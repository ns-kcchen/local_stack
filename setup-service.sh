#!/bin/bash

# Deploy necessary services (MongoDB + Mock services)
# This is a wrapper script that calls the actual setup script in k3d/
#
# Usage:
#   ./setup-service.sh              # Deploy all services
#   ./setup-service.sh -mongodb     # Deploy only MongoDB stack
#   ./setup-service.sh -mock-ris    # Deploy only Mock RIS service
#   ./setup-service.sh -mock-push   # Deploy only Mock Push service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show usage if -h or --help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "📋 Usage: ./setup-service.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  -mongodb      Deploy only MongoDB + Mongo Express"
    echo "  -mock-ris     Deploy only Mock RIS service"
    echo "  -mock-push    Deploy only Mock Push service"
    echo "  -pgsql        Deploy only PostgreSQL + pgAdmin (Phase 3)"
    echo "  (no option)   Deploy all services (MongoDB + PostgreSQL + Mock services)"
    echo
    echo "Examples:"
    echo "  ./setup-service.sh              # Deploy all services"
    echo "  ./setup-service.sh -mongodb     # Deploy only MongoDB"
    echo "  ./setup-service.sh -mock-ris    # Deploy only Mock RIS"
    echo "  ./setup-service.sh -pgsql       # Deploy only PostgreSQL"
    exit 0
fi

# Determine what to deploy
if [[ -z "$1" ]]; then
    echo "🚀 Deploying all necessary services..."
else
    case "$1" in
        -mongodb)
            echo "🚀 Deploying MongoDB stack..."
            ;;
        -mock-ris)
            echo "🚀 Deploying Mock RIS service..."
            ;;
        -mock-push)
            echo "🚀 Deploying Mock Push service..."
            ;;
        -pgsql)
            echo "🚀 Deploying PostgreSQL stack..."
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "💡 Use -h or --help to see available options"
            exit 1
            ;;
    esac
fi

echo

# Pass all arguments to the internal script
"$SCRIPT_DIR/k3d/setup-Services.sh" "$@"

echo
echo "✅ Service deployment completed successfully!"
echo
echo "🔧 Next step:"
echo "   - Deploy Profile API: ./reload.sh"
echo
