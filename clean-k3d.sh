#!/bin/bash

# Cleanup k3d cluster and all resources
# This is a wrapper script that calls the actual cleanup script in k3d/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧹 Cleaning up k3d cluster..."
echo

"$SCRIPT_DIR/k3d/cleanup-k3d.sh"
