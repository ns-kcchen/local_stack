#!/bin/bash

# Deploy complete PostgreSQL stack (PostgreSQL + pgAdmin) using Helm
# Usage: ./setup-DB.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PG_CHART_DIR="$SCRIPT_DIR/helm-chart/postgresql"
PGADMIN_CHART_DIR="$SCRIPT_DIR/helm-chart/pgadmin"

echo "Deploying complete PostgreSQL stack to k3d cluster with Helm..."
echo "Configuration:"
echo "   - PostgreSQL chart: $PG_CHART_DIR"
echo "   - pgAdmin chart: $PGADMIN_CHART_DIR"
echo "   - PostgreSQL access: postgresql-service:5432"
echo "   - pgAdmin web UI: http://localhost:30084"
echo

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: k3d cluster is not running or not accessible!"
    echo "Please start the k3d cluster first using: ../k3d/setup-k3d-cluster.sh"
    exit 1
fi

# Check if Helm charts exist
if [ ! -d "$PG_CHART_DIR" ]; then
    echo "ERROR: PostgreSQL Helm chart not found: $PG_CHART_DIR"
    exit 1
fi

if [ ! -d "$PGADMIN_CHART_DIR" ]; then
    echo "ERROR: pgAdmin Helm chart not found: $PGADMIN_CHART_DIR"
    exit 1
fi

# Step 1: Deploy PostgreSQL
echo "Step 1: Deploying PostgreSQL..."
echo "Removing existing PostgreSQL release..."
helm uninstall postgresql --namespace local-stack --ignore-not-found 2>/dev/null || true

echo "Installing PostgreSQL with Helm..."
helm install postgresql "$PG_CHART_DIR" --namespace local-stack --create-namespace --wait --timeout=120s

# Verify PostgreSQL is running
echo "Checking PostgreSQL status..."
kubectl get pods -l "app.kubernetes.io/name=postgresql" -n local-stack

# Get pod name for connection test
PG_POD=$(kubectl get pods -l "app.kubernetes.io/name=postgresql" -n local-stack -o jsonpath='{.items[0].metadata.name}')

if [ -z "$PG_POD" ]; then
    echo "ERROR: PostgreSQL pod not found"
    exit 1
fi

echo "PostgreSQL pod: $PG_POD"

# Step 2: Deploy pgAdmin
echo
echo "Step 2: Deploying pgAdmin..."
echo "Removing existing pgAdmin release..."
helm uninstall pgadmin --namespace local-stack --ignore-not-found 2>/dev/null || true

sleep 2

echo "Installing pgAdmin with Helm..."
helm install pgadmin "$PGADMIN_CHART_DIR" --namespace local-stack --wait --timeout=120s

# Step 3: Test PostgreSQL connection
echo
echo "Step 3: Testing PostgreSQL connection..."
kubectl exec "$PG_POD" -n local-stack -- psql -U admin -d AISecurityMgmtServiceDB -c '\l' \
    || echo "Connection test will be available once pod is fully ready"

# Final status check
echo
echo "Final deployment status:"
echo "================================"
echo "PostgreSQL:"
kubectl get pods -l "app.kubernetes.io/name=postgresql" -n local-stack
kubectl get svc -l "app.kubernetes.io/name=postgresql" -n local-stack

echo
echo "pgAdmin:"
kubectl get pods -l "app.kubernetes.io/name=pgadmin" -n local-stack
kubectl get svc -l "app.kubernetes.io/name=pgadmin" -n local-stack

echo
echo "PostgreSQL stack deployment completed successfully!"
echo
echo "Access Information:"
echo "================================"
echo "PostgreSQL: postgresql-service.local-stack.svc.cluster.local:5432"
echo "pgAdmin:    http://localhost:30084"
echo
echo "pgAdmin Login:"
echo "   Email:    admin@local.dev"
echo "   Password: password"
echo
echo "PostgreSQL Credentials:"
echo "   Username: admin"
echo "   Password: p@ssw0rd"
echo "   Database: AISecurityMgmtServiceDB"
echo
echo "Connect pgAdmin to PostgreSQL:"
echo "   Host:     postgresql-service"
echo "   Port:     5432"
echo "   Database: AISecurityMgmtServiceDB"
echo "   Username: admin"
echo "   Password: p@ssw0rd"
echo
echo "Useful commands:"
echo "   - Check Helm releases: helm list -n local-stack"
echo "   - PostgreSQL logs: kubectl logs -l \"app.kubernetes.io/name=postgresql\" -n local-stack"
echo "   - pgAdmin logs: kubectl logs -l \"app.kubernetes.io/name=pgadmin\" -n local-stack"
echo "   - psql shell: kubectl exec $PG_POD -n local-stack -- psql -U admin -d AISecurityMgmtServiceDB"
echo "   - Uninstall: helm uninstall postgresql pgadmin -n local-stack"
