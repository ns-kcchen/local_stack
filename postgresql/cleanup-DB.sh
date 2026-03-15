#!/bin/bash

# Cleanup PostgreSQL stack (PostgreSQL + pgAdmin) deployed with Helm
# Usage: ./cleanup-DB.sh

set -e

echo "Cleaning up PostgreSQL stack from k3d cluster..."
echo

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: k3d cluster is not running or not accessible!"
    echo "Please start the k3d cluster first using: ../k3d/setup-k3d-cluster.sh"
    exit 1
fi

# Remove pgAdmin first
echo "Step 1: Removing pgAdmin..."
if helm list -n local-stack | grep -q pgadmin; then
    helm uninstall pgadmin -n local-stack
    echo "pgAdmin removed successfully"
else
    echo "pgAdmin not found, skipping..."
fi

# Remove PostgreSQL
echo
echo "Step 2: Removing PostgreSQL..."
if helm list -n local-stack | grep -q postgresql; then
    helm uninstall postgresql -n local-stack
    echo "PostgreSQL removed successfully"
else
    echo "PostgreSQL not found, skipping..."
fi

# Wait for cleanup to complete
echo
echo "Waiting for resources to be fully removed..."
sleep 5

# Final status check
echo "Final cleanup status:"
echo "================================"
REMAINING_PODS=$(kubectl get pods -n local-stack 2>/dev/null | grep -E "(postgresql|pgadmin)" | wc -l || echo "0")
REMAINING_SVC=$(kubectl get svc -n local-stack 2>/dev/null | grep -E "(postgresql|pgadmin)" | wc -l || echo "0")

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_SVC" -eq 0 ]; then
    echo "All PostgreSQL stack resources have been removed successfully!"
else
    echo "Some resources may still be terminating:"
    kubectl get pods -n local-stack | grep -E "(postgresql|pgadmin)" || echo "   No pods found"
    kubectl get svc -n local-stack | grep -E "(postgresql|pgadmin)" || echo "   No services found"
fi

echo
echo "Remaining Helm releases:"
helm list -n local-stack

echo
echo "PostgreSQL stack cleanup completed!"
echo
echo "To redeploy the stack:"
echo "   ./setup-DB.sh"
