#!/bin/bash

# Create a local k3d cluster with registry k3d-local-img:5555
# Usage: ./setup-k3d-cluster.sh [cluster-name]
# Environment variables:
#   CERT_PATH - Path to certificate file (default: /Users/kcc/wrkspace/certs.crt)

set -e

# ==========================================
# Load Host-Specific Configuration
# ==========================================

# Determine script directory
SCRIPT_DIR_TMP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_INFO_FILE="$SCRIPT_DIR_TMP/../env/host_info.txt"

# Load environment variables from env/host_info.txt
if [ -f "$HOST_INFO_FILE" ]; then
    source "$HOST_INFO_FILE"
    echo "✅ Loaded configuration from env/host_info.txt"
else
    echo "❌ Error: env/host_info.txt not found!"
    echo "💡 Please create env/host_info.txt from env/host_info.txt.example"
    echo "   cp env/host_info.txt.example env/host_info.txt"
    echo "   # Edit env/host_info.txt and fill in your paths"
    exit 1
fi

# ==========================================
# Validate Required Configuration
# ==========================================

# Certificate Path (required)
if [ -z "$CERT_PATH" ]; then
    echo "❌ Error: CERT_PATH not set in env/host_info.txt"
    exit 1
fi

# Verify cert file exists
if [ ! -f "$CERT_PATH" ]; then
    echo "❌ Error: Certificate file not found: $CERT_PATH"
    exit 1
fi

echo "🔧 Configuration loaded:"
echo "   - Certificate: $CERT_PATH"
echo

# ==========================================
# Configuration
# ==========================================

CLUSTER_NAME=${1:-"local-cluster"}
CREATE_REGISTRY_NAME="local-img"
REGISTRY_NAME="k3d-local-img"
REGISTRY_PORT="5555"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# CERT_PATH is now loaded from env/host_info.txt (see above)

echo "🚀 Setting up k3d cluster with local registry..."
echo "📋 Configuration:"
echo "   - Cluster name: $CLUSTER_NAME"
echo "   - Registry: $REGISTRY_NAME:$REGISTRY_PORT"
echo "   - Certificate path: $CERT_PATH"
echo

# Check if k3d is installed
if ! command -v k3d &> /dev/null; then
    echo "❌ k3d is not installed. Please install it first."
    echo "   Visit: https://k3d.io/installation/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create local registry if it doesn't exist
if ! docker ps | grep -q "$REGISTRY_NAME"; then
    echo "🏗️  Creating local registry: $REGISTRY_NAME:$REGISTRY_PORT"
    k3d registry create "$CREATE_REGISTRY_NAME" --port "$REGISTRY_PORT"
else
    echo "✅ Local registry '$REGISTRY_NAME' already exists"
fi

# Create k3d cluster if it doesn't exist
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "🏗️  Creating k3d cluster: $CLUSTER_NAME"
    k3d cluster create "$CLUSTER_NAME" \
        --volume "$CERT_PATH:/etc/ssl/certs/cert.crt" \
        --agents 2 \
        --registry-use "$REGISTRY_NAME:$REGISTRY_PORT" \
        --port "8080:80@loadbalancer" \
        --port "8443:443@loadbalancer" \
        --port "30080:30080@loadbalancer" \
        --port "30081:30081@loadbalancer" \
        --port "30082:30082@loadbalancer" \
        --port "30083:30083@loadbalancer" \
        --wait
else
    echo "✅ k3d cluster '$CLUSTER_NAME' already exists"
fi

# Switch to the cluster context
echo "🔄 Switching to cluster context..."
kubectl config use-context "k3d-$CLUSTER_NAME"

echo
echo "✅ k3d cluster setup completed!"
echo
echo "📋 Cluster Information:"
echo "   - Cluster name: $CLUSTER_NAME"
echo "   - Registry: $REGISTRY_NAME:$REGISTRY_PORT"
echo "   - Context: k3d-$CLUSTER_NAME"
echo
echo "🔧 Next steps (from local_stack directory):"
echo "   - Deploy services: ./setup-service.sh"
echo "   - Deploy Profile API: ./reload.sh"
echo
