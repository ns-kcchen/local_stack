#!/bin/bash

# Cleanup MongoDB stack (MongoDB + Mongo Express) deployed with Helm
# Usage: ./cleanup-mongodb-stack.sh

set -e

echo "🧹 Cleaning up MongoDB stack from k3d cluster..."
echo

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ k3d cluster is not running or not accessible!"
    echo "💡 Please start the k3d cluster first using: ../k3d/setup-k3d-cluster.sh"
    exit 1
fi

# Remove Mongo Express first (depends on MongoDB)
echo "🗑️  Step 1: Removing Mongo Express..."
if helm list -n local-stack | grep -q mongo-express; then
    helm uninstall mongo-express -n local-stack
    echo "✅ Mongo Express removed successfully"
else
    echo "ℹ️  Mongo Express not found, skipping..."
fi

# Remove MongoDB
echo
echo "🗑️  Step 2: Removing MongoDB..."
if helm list -n local-stack | grep -q mongodb; then
    helm uninstall mongodb -n local-stack
    echo "✅ MongoDB removed successfully"
else
    echo "ℹ️  MongoDB not found, skipping..."
fi

# Wait for cleanup to complete
echo
echo "⏳ Waiting for resources to be fully removed..."
sleep 5

# Final status check
echo "📊 Final cleanup status:"
echo "═════════════════════════"
REMAINING_PODS=$(kubectl get pods -n local-stack | grep -E "(mongo|mongodb)" | wc -l || echo "0")
REMAINING_SVC=$(kubectl get svc -n local-stack | grep -E "(mongo|mongodb)" | wc -l || echo "0")

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_SVC" -eq 0 ]; then
    echo "✅ All MongoDB stack resources have been removed successfully!"
else
    echo "⚠️  Some resources may still be terminating:"
    kubectl get pods -n local-stack | grep -E "(mongo|mongodb)" || echo "   No pods found"
    kubectl get svc -n local-stack | grep -E "(mongo|mongodb)" || echo "   No services found"
fi

echo
echo "🔧 Remaining Helm releases:"
helm list -n local-stack

echo
echo "✅ MongoDB stack cleanup completed!"
echo
echo "💡 To redeploy the stack:"
echo "   ./setup-DB.sh"
