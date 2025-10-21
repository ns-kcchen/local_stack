#!/bin/bash

# Cleanup k3d cluster and local registry
# Usage: ./cleanup-k3d.sh [cluster-name]

set -e

# Configuration
CLUSTER_NAME=${1:-"local-cluster"}
REGISTRY_NAME="k3d-local-img"
REGISTRY_PORT="5555"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧹 Cleaning up k3d cluster and registry..."
echo "📋 Configuration:"
echo "   - Cluster name: $CLUSTER_NAME"
echo "   - Registry: $REGISTRY_NAME:$REGISTRY_PORT"
echo

# Delete deployment from cluster (if exists)
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "🗑️  Removing deployment from cluster..."
    kubectl config use-context "k3d-$CLUSTER_NAME" 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/" --ignore-not-found=true 2>/dev/null || true
    echo "✅ Deployment removed"
fi

# Ask user if they want to delete the cluster
echo
read -p "❓ Do you want to delete the k3d cluster '$CLUSTER_NAME'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        echo "🗑️  Deleting k3d cluster..."
        k3d cluster delete "$CLUSTER_NAME"
        echo "✅ k3d cluster deleted"
    else
        echo "ℹ️  Cluster '$CLUSTER_NAME' not found"
    fi
else
    echo "ℹ️  Keeping k3d cluster '$CLUSTER_NAME'"
fi

# Ask user if they want to delete the registry
echo
read -p "❓ Do you want to delete the local registry '$REGISTRY_NAME'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if docker ps -a | grep -q "$REGISTRY_NAME"; then
        echo "🗑️  Deleting local registry..."
        k3d registry delete "$REGISTRY_NAME"
        echo "✅ Local registry deleted"
    else
        echo "ℹ️  Registry '$REGISTRY_NAME' not found"
    fi
else
    echo "ℹ️  Keeping local registry '$REGISTRY_NAME'"
fi

# Clean up Docker images (optional)
echo
read -p "❓ Do you want to remove Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing Docker images..."
    
    # Remove local images
    docker rmi profileapi:latest 2>/dev/null || echo "   profileapi:latest - not found"
    docker rmi "$REGISTRY_NAME:$REGISTRY_PORT/profileapi:latest" 2>/dev/null || echo "   $REGISTRY_NAME:$REGISTRY_PORT/profileapi:latest - not found"
    
    # Clean up dangling images
    docker image prune -f 2>/dev/null || true
    
    echo "✅ Docker images cleanup completed"
else
    echo "ℹ️  Keeping Docker images"
fi

echo
echo "✅ Cleanup completed!"
echo
echo "🔧 To recreate the setup (from local_stack directory):"
echo "   - Setup cluster: ./setup-k3d.sh"
echo "   - Deploy services: ./setup-service.sh"
echo "   - Deploy Profile API: ./reload.sh"
