#!/bin/bash

# Deploy dependent services to k3d cluster (MongoDB + Mock Services)
# Usage:
#   ./setup-Services.sh              # Deploy all services
#   ./setup-Services.sh -mongodb     # Deploy only MongoDB
#   ./setup-Services.sh -mock-ris    # Deploy only Mock RIS
#   ./setup-Services.sh -mock-push   # Deploy only Mock Push

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGODB_SETUP="$SCRIPT_DIR/../mongoDB/setup-DB.sh"
MOCK_RIS_DIR="$SCRIPT_DIR/../mock_services/mock_ris"
MOCK_PUSH_DIR="$SCRIPT_DIR/../mock_services/mock_push"

# Parse command line options
DEPLOY_MONGODB=false
DEPLOY_MOCK_RIS=false
DEPLOY_MOCK_PUSH=false
DEPLOY_ALL=true

if [[ -n "$1" ]]; then
    DEPLOY_ALL=false
    case "$1" in
        -mongodb)
            DEPLOY_MONGODB=true
            ;;
        -mock-ris)
            DEPLOY_MOCK_RIS=true
            ;;
        -mock-push)
            DEPLOY_MOCK_PUSH=true
            ;;
    esac
else
    # No arguments, deploy all
    DEPLOY_MONGODB=true
    DEPLOY_MOCK_RIS=true
    DEPLOY_MOCK_PUSH=true
fi

# Show deployment plan
if [[ "$DEPLOY_ALL" == true ]]; then
    echo "🚀 Deploying all dependent services to k3d cluster..."
    echo "📋 Services to deploy:"
    echo "   1. MongoDB (with Replica Set)"
    echo "   2. Mongo Express (Web UI)"
    echo "   3. Mock RIS service"
    echo "   4. Mock Push service"
else
    echo "🚀 Deploying selected services to k3d cluster..."
    echo "📋 Services to deploy:"
    if [[ "$DEPLOY_MONGODB" == true ]]; then
        echo "   - MongoDB (with Replica Set)"
        echo "   - Mongo Express (Web UI)"
    fi
    if [[ "$DEPLOY_MOCK_RIS" == true ]]; then
        echo "   - Mock RIS service"
    fi
    if [[ "$DEPLOY_MOCK_PUSH" == true ]]; then
        echo "   - Mock Push service"
    fi
fi
echo

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ k3d cluster is not running or not accessible!"
    echo "💡 Please start the k3d cluster first using: ./setup-k3d-cluster.sh"
    exit 1
fi

# Ensure namespace exists
echo "📦 Step 0: Ensuring namespace exists..."
kubectl apply -f "$SCRIPT_DIR/../namespace.yaml"
echo

# Step 1: Deploy MongoDB stack
if [[ "$DEPLOY_MONGODB" == true ]]; then
    echo "🗄️  Step 1: Deploying MongoDB stack..."
    echo "════════════════════════════════════"
    if [ -f "$MONGODB_SETUP" ]; then
        "$MONGODB_SETUP"
    else
        echo "❌ MongoDB setup script not found: $MONGODB_SETUP"
        exit 1
    fi

    echo
    echo "✅ MongoDB deployment completed"
    echo
fi

# Step 2: Build and deploy Mock RIS service
if [[ "$DEPLOY_MOCK_RIS" == true ]]; then
    echo "🔧 Step 2: Deploying Mock RIS service..."
    echo "════════════════════════════════════"
    if [ -d "$MOCK_RIS_DIR" ]; then
        cd "$MOCK_RIS_DIR"

        # Build Docker image
        echo "🔨 Building Mock RIS Docker image..."
        ./buildimg.sh

        # Deploy to k3d
        echo "🚀 Deploying Mock RIS to k3d..."
        kubectl apply -f deployment.yaml
        kubectl apply -f service.yaml

        echo "✅ Mock RIS service deployed"
    else
        echo "⚠️  Mock RIS directory not found: $MOCK_RIS_DIR"
    fi

    echo
fi

# Step 3: Build and deploy Mock Push service
if [[ "$DEPLOY_MOCK_PUSH" == true ]]; then
    echo "🔧 Step 3: Deploying Mock Push service..."
    echo "════════════════════════════════════"
    if [ -d "$MOCK_PUSH_DIR" ]; then
        cd "$MOCK_PUSH_DIR"

        # Build Docker image
        echo "🔨 Building Mock Push Docker image..."
        ./buildimg.sh

        # Deploy to k3d
        echo "🚀 Deploying Mock Push to k3d..."
        kubectl apply -f deployment.yaml
        kubectl apply -f service.yaml

        echo "✅ Mock Push service deployed"
    else
        echo "⚠️  Mock Push directory not found: $MOCK_PUSH_DIR"
    fi

    echo
fi

# Wait for services to be ready
if [[ "$DEPLOY_MOCK_RIS" == true || "$DEPLOY_MOCK_PUSH" == true ]]; then
    echo "⏳ Waiting for services to be ready..."
    echo "════════════════════════════════════"

    # Wait for Mock RIS
    if [[ "$DEPLOY_MOCK_RIS" == true ]]; then
        echo "📊 Checking Mock RIS..."
        kubectl wait --for=condition=available --timeout=120s deployment/mock-ris-deployment -n local-stack 2>/dev/null || echo "⚠️  Mock RIS deployment not ready yet"
    fi

    # Wait for Mock Push
    if [[ "$DEPLOY_MOCK_PUSH" == true ]]; then
        echo "📊 Checking Mock Push..."
        kubectl wait --for=condition=available --timeout=120s deployment/mock-push-deployment -n local-stack 2>/dev/null || echo "⚠️  Mock Push deployment not ready yet"
    fi

    echo
fi

# Final status check
echo "📊 Final deployment status:"
echo "════════════════════════════════════"

if [[ "$DEPLOY_MONGODB" == true ]]; then
    echo "🗄️  MongoDB Services:"
    kubectl get pods -l "app.kubernetes.io/name=mongodb" -n local-stack 2>/dev/null || echo "   MongoDB not found"
    kubectl get svc -l "app.kubernetes.io/name=mongodb" -n local-stack 2>/dev/null || echo "   MongoDB service not found"

    echo
    echo "🖥️  Mongo Express:"
    kubectl get pods -l "app.kubernetes.io/name=mongo-express" -n local-stack 2>/dev/null || echo "   Mongo Express not found"
    kubectl get svc -l "app.kubernetes.io/name=mongo-express" -n local-stack 2>/dev/null || echo "   Mongo Express service not found"
    echo
fi

if [[ "$DEPLOY_MOCK_RIS" == true ]]; then
    echo "🔧 Mock RIS Service:"
    kubectl get pods -l "app=mock-ris" -n local-stack 2>/dev/null || echo "   Mock RIS not found"
    kubectl get svc -l "app=mock-ris" -n local-stack 2>/dev/null || echo "   Mock RIS service not found"
    echo
fi

if [[ "$DEPLOY_MOCK_PUSH" == true ]]; then
    echo "🔧 Mock Push Service:"
    kubectl get pods -l "app=mock-push" -n local-stack 2>/dev/null || echo "   Mock Push not found"
    kubectl get svc -l "app=mock-push" -n local-stack 2>/dev/null || echo "   Mock Push service not found"
    echo
fi

echo "✅ Service deployment completed!"
echo
echo "🌐 Access Information:"
echo "════════════════════════════════════"

if [[ "$DEPLOY_MONGODB" == true ]]; then
    echo "🗄️  MongoDB:         mongodb-service.local-stack.svc.cluster.local:27017"
    echo "🖥️  Mongo Express:   http://localhost:30081"
    echo
    echo "🔑 MongoDB Credentials:"
    echo "   - Username: username"
    echo "   - Password: password"
    echo "   - Connection string: mongodb://username:password@mongodb-service.local-stack.svc.cluster.local:27017/?replicaSet=rs0"
    echo
fi

if [[ "$DEPLOY_MOCK_RIS" == true ]]; then
    echo "🔧 Mock RIS:        http://localhost:30082"
fi

if [[ "$DEPLOY_MOCK_PUSH" == true ]]; then
    echo "🔧 Mock Push:       http://localhost:30083"
fi

echo
echo "🔧 Useful commands:"
echo "   - Check all services: kubectl get all -n local-stack"

if [[ "$DEPLOY_MOCK_RIS" == true ]]; then
    echo "   - Mock RIS logs: kubectl logs -l \"app=mock-ris\" -n local-stack"
fi

if [[ "$DEPLOY_MOCK_PUSH" == true ]]; then
    echo "   - Mock Push logs: kubectl logs -l \"app=mock-push\" -n local-stack"
fi

if [[ "$DEPLOY_MONGODB" == true ]]; then
    echo "   - MongoDB logs: kubectl logs -l \"app.kubernetes.io/name=mongodb\" -n local-stack"
fi

echo
echo "📋 Next step (from local_stack directory):"
echo "   - Deploy Profile API: ./reload.sh"
echo
