#!/bin/bash

# Setup k3d cluster for local development
# This is a wrapper script that calls the actual setup script in k3d/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Setting up k3d cluster..."
echo

"$SCRIPT_DIR/k3d/setup-k3d-cluster.sh"

echo
echo "✅ k3d cluster setup completed!"
echo
echo "🔧 Next steps:"
echo "   - Deploy services: ./setup-service.sh"
echo "   - Deploy Profile API: ./reload.sh"
echo
