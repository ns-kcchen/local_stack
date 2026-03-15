#!/bin/bash

# Reload AISecurity Profile API service in k3d cluster
# This script builds Docker image, pushes to local registry, and redeploys with kubectl
# Usage: ./reload.sh [image-name] [tag]

set -e

# Configuration
IMAGE_NAME=${1:-"aisecurity-mgmt-service"}
TAG=${2:-"local-dev"}
APP_NAME="aisecurity-mgmt-service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_PATH="$SCRIPT_DIR/pkg"
BUILD_SCRIPT="$SCRIPT_DIR/img/buildimg.sh"
RENEW_SCRIPT="$SCRIPT_DIR/img/reloadimg.sh"

echo "🔄 Reloading AISecurity Management Service in k3d cluster..."
echo "📋 Configuration:"
echo "   - Image: $IMAGE_NAME:$TAG"
echo "   - App name: $APP_NAME"
echo "   - Deployment path: $DEPLOYMENT_PATH"
echo

# Check if required scripts exist
if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "❌ Error: Build script not found: $BUILD_SCRIPT"
    exit 1
fi

if [ ! -f "$RENEW_SCRIPT" ]; then
    echo "❌ Error: Renew script not found: $RENEW_SCRIPT"
    exit 1
fi

if [ ! -d "$DEPLOYMENT_PATH" ]; then
    echo "❌ Error: Deployment files not found: $DEPLOYMENT_PATH"
    exit 1
fi

# Ensure kubectl context is pointing to local k3d cluster
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
if [ "$CURRENT_CONTEXT" != "k3d-local-cluster" ]; then
    echo "⚠️  Current context: $CURRENT_CONTEXT"
    echo "🔀 Switching kubectl context to k3d-local-cluster..."
    if ! kubectl config use-context k3d-local-cluster &> /dev/null; then
        echo "❌ Failed to switch to k3d-local-cluster context!"
        echo "💡 Please start the k3d cluster first using: ./setup-k3d.sh"
        exit 1
    fi
    echo "✅ Context switched to k3d-local-cluster"
fi

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ k3d cluster is not running or not accessible!"
    echo "💡 Please start the k3d cluster first using: ./setup-k3d.sh"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Step 1: Build and push Docker image
echo "🔨 Step 1: Building and pushing Docker image..."
"$RENEW_SCRIPT" "$IMAGE_NAME" "$TAG"

# Step 2: Clean up existing deployment
echo
echo "🧹 Step 2: Cleaning up existing deployment..."
if kubectl get deployment "$APP_NAME" -n local-stack &> /dev/null; then
    echo "🗑️  Deleting existing deployment: $APP_NAME"
    kubectl delete -f "$DEPLOYMENT_PATH/" --ignore-not-found=true
    echo "⏳ Waiting for resources to be cleaned up..."
    sleep 10
else
    echo "ℹ️  No existing deployment found: $APP_NAME"
fi

# Step 3: Deploy new version
echo
echo "🚀 Step 3: Deploying new version..."
# Ensure namespace exists
kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
kubectl apply -f "$DEPLOYMENT_PATH/"

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/"$APP_NAME" -n local-stack

# Step 4: Verify deployment
echo
echo "📊 Step 4: Verifying deployment..."
echo "════════════════════════════════"

# Check pods
echo "🔍 Checking pods:"
kubectl get pods -l "app=$APP_NAME" -n local-stack

# Check services
echo
echo "🌐 Checking services:"
kubectl get svc -l "app=$APP_NAME" -n local-stack

# Check if service is responding
echo
echo "🏥 Health check:"
sleep 15  # Wait for service to be ready
# Health probes run on a standalone port (8001) inside the pod, not exposed via NodePort.
# Use kubectl exec to verify, and /healthcheck on API port for external check.
POD_NAME=$(kubectl get pods -l "app=$APP_NAME" -n local-stack -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    if kubectl exec "$POD_NAME" -n local-stack -- curl -s -f http://localhost:8001/health/liveness > /dev/null 2>&1; then
        echo "✅ Health probe server responding (port 8001 inside pod)"
    else
        echo "⚠️  Health probe server not yet responding on port 8001"
    fi
fi
if curl -s -f http://localhost:30080/healthcheck > /dev/null; then
    echo "✅ API server responding at http://localhost:30080"
else
    echo "⚠️  Service may still be starting up. Check logs with:"
    echo "   kubectl logs -l \"app=$APP_NAME\""
fi

# Test FastAPI docs endpoint
echo
echo "📚 Testing FastAPI docs endpoint:"
if curl -s -f http://localhost:30080/docs > /dev/null; then
    echo "✅ FastAPI docs available at http://localhost:30080/docs"
else
    echo "⚠️  FastAPI docs may still be starting up"
fi

echo
echo "🎉 AISecurity Management Service reload completed successfully!"
echo
echo "🌐 Access Information:"
echo "════════════════════════"
echo "📊 Management API:     http://localhost:30080"
echo "📚 FastAPI Docs:       http://localhost:30080/docs"
echo "📋 Health Probes:      port 8001 inside pod (K8s internal only)"
echo "📋 Legacy Healthcheck: http://localhost:30080/healthcheck"
echo
echo "🔧 Useful commands:"
echo "   - Check status: kubectl get pods -l \"app=$APP_NAME\" -n local-stack"
echo "   - View logs: kubectl logs -l \"app=$APP_NAME\" -n local-stack"
echo "   - Check all services: kubectl get all -n local-stack"
echo "   - Test probe: kubectl exec <pod> -n local-stack -- curl http://localhost:8001/health/liveness"