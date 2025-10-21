#!/bin/bash

# Deploy MongoDB to the local k3d cluster using Helm
# Usage: ./deploy-mongoDB.sh

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART_DIR="$SCRIPT_DIR/helm-chart/mongodb"
RELEASE_NAME="mongodb"

echo "🍃 Deploying MongoDB to k3d cluster with Helm..."
echo "📋 Configuration:"
echo "   - Helm chart: $HELM_CHART_DIR"
echo "   - Release name: $RELEASE_NAME"
echo

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ k3d cluster is not running or not accessible!"
    echo "💡 Please start the k3d cluster first using: ../local-k3d-env/setup-k3d-cluster.sh"
    exit 1
fi

# Check if Helm chart exists
if [ ! -d "$HELM_CHART_DIR" ]; then
    echo "❌ Error: Helm chart directory not found: $HELM_CHART_DIR"
    exit 1
fi

# Remove existing MongoDB Helm release if it exists
echo "🧹 Removing existing MongoDB Helm release..."
helm uninstall "$RELEASE_NAME" --ignore-not-found 2>/dev/null || true

# Wait a moment for cleanup
sleep 2

# Wait for resources to be fully deleted
echo "⏳ Waiting for MongoDB resources to be deleted..."
kubectl wait --for=delete deployment/mongodb-deployment --timeout=60s || true
kubectl wait --for=delete service/mongodb-service --timeout=60s || true
kubectl wait --for=delete configmap/mongodb-configmap --timeout=60s || true
kubectl wait --for=delete secret/mongodb-secret --timeout=60s || true

# Deploy MongoDB using Helm
echo "🚀 Installing MongoDB with Helm..."
helm install "$RELEASE_NAME" "$HELM_CHART_DIR" --wait --timeout=300s

# Check deployment status
echo "📊 MongoDB deployment status:"
kubectl get pods -l "app.kubernetes.io/name=mongodb"
kubectl get svc -l "app.kubernetes.io/name=mongodb"

# Test MongoDB connection
echo
echo "🧪 Testing MongoDB deployment..."
sleep 5

# Get MongoDB pod name
MONGO_POD=$(kubectl get pods -l "app.kubernetes.io/name=mongodb" -o jsonpath='{.items[0].metadata.name}')

if [ -n "$MONGO_POD" ]; then
    echo "📍 Testing MongoDB connection..."
    if kubectl exec "$MONGO_POD" -- mongosh --eval "db.runCommand('ping').ok" --quiet 2>/dev/null; then
        echo "✅ MongoDB is responding correctly!"
    else
        echo "⚠️  MongoDB connection test failed, but deployment may still be starting..."
    fi
else
    echo "⚠️  MongoDB pod not found, deployment may still be starting..."
fi

echo
echo "✅ MongoDB deployment completed successfully!"
echo
echo "🌐 MongoDB connection details:"
echo "   - Internal service: ${RELEASE_NAME}-service:27017"
echo "   - Database URL: mongodb://username:password@${RELEASE_NAME}-service:27017/"
echo "   - Username: username"
echo "   - Password: password"
echo
echo "🔧 Useful commands:"
echo "   - View MongoDB logs: kubectl logs -l \"app.kubernetes.io/name=mongodb\""
echo "   - Connect to MongoDB: kubectl exec -it $MONGO_POD -- mongosh"
echo "   - Port forward: kubectl port-forward svc/${RELEASE_NAME}-service 27017:27017"
echo "   - Check Helm status: helm status $RELEASE_NAME"
echo "   - Uninstall MongoDB: helm uninstall $RELEASE_NAME"
