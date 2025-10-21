#!/bin/bash

# Deploy Mongo Express to the local k3d cluster using Helm
# Usage: ./deploy-mongoExpress.sh

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART_DIR="$SCRIPT_DIR/helm-chart/mongo-express"
RELEASE_NAME="mongo-express"

echo "🖥️  Deploying Mongo Express to k3d cluster with Helm..."
echo "📋 Configuration:"
echo "   - Helm chart: $HELM_CHART_DIR"
echo "   - Release name: $RELEASE_NAME"
echo "   - NodePort: 30081"
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

# Check if MongoDB is already deployed (required for Mongo Express)
if ! kubectl get pods -l "app.kubernetes.io/name=mongodb" &>/dev/null; then
    echo "⚠️  Warning: MongoDB deployment not found."
    echo "   Mongo Express requires MongoDB to be deployed first."
    echo "   Please run './deploy-mongoDB.sh' first."
    exit 1
fi

# Check if MongoDB secret exists
if ! kubectl get secret mongodb-secret &>/dev/null; then
    echo "❌ Error: MongoDB secret not found. Please deploy MongoDB first."
    exit 1
fi

# Remove existing Mongo Express Helm release if it exists
echo "🧹 Removing existing Mongo Express Helm release..."
helm uninstall "$RELEASE_NAME" --ignore-not-found 2>/dev/null || true

# Wait a moment for cleanup
sleep 2

# Deploy Mongo Express using Helm
echo "🚀 Installing Mongo Express with Helm..."
helm install "$RELEASE_NAME" "$HELM_CHART_DIR" --wait --timeout=300s

# Check deployment status
echo "📊 Mongo Express deployment status:"
kubectl get pods -l "app.kubernetes.io/name=mongo-express"
kubectl get svc -l "app.kubernetes.io/name=mongo-express"

# Test Mongo Express accessibility
echo
echo "🧪 Testing Mongo Express deployment..."
sleep 5

# Get Mongo Express pod name
MONGO_EXPRESS_POD=$(kubectl get pods -l "app.kubernetes.io/name=mongo-express" -o jsonpath='{.items[0].metadata.name}')

if [ -n "$MONGO_EXPRESS_POD" ]; then
    echo "📍 Checking Mongo Express pod status..."
    if kubectl get pod "$MONGO_EXPRESS_POD" | grep -q "Running"; then
        echo "✅ Mongo Express is running correctly!"
    else
        echo "⚠️  Mongo Express pod is not running yet, but deployment may still be starting..."
    fi
else
    echo "⚠️  Mongo Express pod not found, deployment may still be starting..."
fi

echo
echo "✅ Mongo Express deployment completed successfully!"
echo
echo "🖥️  Mongo Express (Web UI) access:"
echo "   - NodePort access: http://localhost:30081"
echo "   - Internal service: ${RELEASE_NAME}-service:8081"
echo "   - Port forward command: kubectl port-forward svc/${RELEASE_NAME}-service 8081:8081"
echo "   - Port forward access: http://localhost:8081 (after port-forward)"
echo
echo "🔧 Useful commands:"
echo "   - View Mongo Express logs: kubectl logs -l \"app.kubernetes.io/name=mongo-express\""
echo "   - Port forward Mongo Express: kubectl port-forward svc/${RELEASE_NAME}-service 8081:8081"
echo "   - Check Helm status: helm status $RELEASE_NAME"
echo "   - Uninstall Mongo Express: helm uninstall $RELEASE_NAME"
echo
echo "📖 Usage instructions:"
echo "   Open browser: http://localhost:30081"
echo "   Browse your MongoDB databases and collections"
echo "   "
echo "   Credentials: username/password (from MongoDB secret)"
