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
if curl -s -f http://localhost:30080/health/liveness > /dev/null; then
    echo "✅ Service is responding at http://localhost:30080"
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
echo "📋 Health Liveness:    http://localhost:30080/health/liveness"
echo "📋 Health Readiness:   http://localhost:30080/health/readiness"
echo
echo "🔧 Useful commands:"
echo "   - Check status: kubectl get pods -l \"app=$APP_NAME\" -n local-stack"
echo "   - View logs: kubectl logs -l \"app=$APP_NAME\" -n local-stack"
echo "   - Check all services: kubectl get all -n local-stack"