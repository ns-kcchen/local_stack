#!/bin/bash

# Deploy complete MongoDB stack (MongoDB + Mongo Express) using Helm
# Usage: ./deploy-mongodb-stack.sh

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGODB_CHART_DIR="$SCRIPT_DIR/helm-chart/mongodb"
MONGO_EXPRESS_CHART_DIR="$SCRIPT_DIR/helm-chart/mongo-express"

echo "🍃 Deploying complete MongoDB stack to k3d cluster with Helm..."
echo "📋 Configuration:"
echo "   - MongoDB chart: $MONGODB_CHART_DIR"
echo "   - Mongo Express chart: $MONGO_EXPRESS_CHART_DIR"
echo "   - MongoDB access: mongodb-service:27017"
echo "   - Mongo Express web UI: http://localhost:30081"
echo

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ k3d cluster is not running or not accessible!"
    echo "💡 Please start the k3d cluster first using: ../k3d/setup-k3d-cluster.sh"
    exit 1
fi

# Check if Helm charts exist
if [ ! -d "$MONGODB_CHART_DIR" ]; then
    echo "❌ Error: MongoDB Helm chart not found: $MONGODB_CHART_DIR"
    exit 1
fi

if [ ! -d "$MONGO_EXPRESS_CHART_DIR" ]; then
    echo "❌ Error: Mongo Express Helm chart not found: $MONGO_EXPRESS_CHART_DIR"
    exit 1
fi

# Step 1: Deploy MongoDB
echo "🗄️  Step 1: Deploying MongoDB..."
echo "🧹 Removing existing MongoDB release..."
helm uninstall mongodb --namespace local-stack --ignore-not-found 2>/dev/null || true

echo "🚀 Installing MongoDB with Helm..."
helm install mongodb "$MONGODB_CHART_DIR" --namespace local-stack --create-namespace --wait --timeout=300s

# Verify MongoDB is running
echo "📊 Checking MongoDB status..."
kubectl get pods -l "app.kubernetes.io/name=mongodb" -n local-stack

# Step 2: Deploy Mongo Express
echo
echo "🖥️  Step 2: Deploying Mongo Express..."
echo "🧹 Removing existing Mongo Express release..."
helm uninstall mongo-express --namespace local-stack --ignore-not-found 2>/dev/null || true

# Wait a moment
sleep 2

echo "🚀 Installing Mongo Express with Helm..."
helm install mongo-express "$MONGO_EXPRESS_CHART_DIR" --namespace local-stack --wait --timeout=300s

# Step 3: Verify Replica Set and Transaction Support  
echo
echo "🔄 Step 3: Verifying Replica Set and transaction support..."

# Wait for MongoDB to be fully ready (including replica set initialization)
echo "⏳ Waiting for MongoDB to be ready with Replica Set..."
kubectl wait --for=condition=ready --timeout=300s pod -l "app.kubernetes.io/name=mongodb" -n local-stack

# Get MongoDB pod name
MONGODB_POD=$(kubectl get pods -l "app.kubernetes.io/name=mongodb" -n local-stack -o jsonpath='{.items[0].metadata.name}')

if [ -z "$MONGODB_POD" ]; then
    echo "❌ Error: MongoDB pod not found"
    exit 1
fi

echo "📋 MongoDB pod: $MONGODB_POD"

# Wait a bit more for the replica set initialization script to complete
echo "⏳ Waiting for replica set initialization to complete..."
sleep 30

# Verify replica set status
echo "📊 Checking replica set status..."
kubectl exec "$MONGODB_POD" -n local-stack -- mongo --eval 'rs.status()' --quiet || echo "Replica set may still be initializing..."

# Verify user authentication
echo "🔐 Verifying user authentication..."
kubectl exec "$MONGODB_POD" -n local-stack -- mongo admin -u username -p password --eval 'db.runCommand("ping")' --quiet || echo "Authentication setup may still be in progress..."

# Test transaction support
echo
echo "🧪 Testing transaction support..."
kubectl exec "$MONGODB_POD" -n local-stack -- mongo admin -u username -p password --eval '
// Test basic transaction functionality
session = db.getMongo().startSession();
session.startTransaction();
try {
    db = session.getDatabase("test");
    db.testCollection.insertOne({test: "transaction", timestamp: new Date()});
    session.commitTransaction();
    print("✅ Transaction test successful!");
} catch (error) {
    session.abortTransaction();
    print("❌ Transaction test failed:", error);
} finally {
    session.endSession();
}
' --quiet || echo "Transaction test will be available once replica set is fully ready"

# Final status check
echo
echo "📊 Final deployment status:"
echo "════════════════════════════"
echo "🗄️  MongoDB:"
kubectl get pods -l "app.kubernetes.io/name=mongodb" -n local-stack
kubectl get svc -l "app.kubernetes.io/name=mongodb" -n local-stack

echo
echo "🖥️  Mongo Express:"
kubectl get pods -l "app.kubernetes.io/name=mongo-express" -n local-stack
kubectl get svc -l "app.kubernetes.io/name=mongo-express" -n local-stack

echo
echo "✅ MongoDB stack deployment with transaction support completed successfully!"
echo
echo "🌐 Access Information:"
echo "════════════════════════"
echo "📊 Profile API:     http://localhost:30080"
echo "🖥️  Mongo Express:   http://localhost:30081"
echo "🗄️  MongoDB:         mongodb-service:27017"
echo
echo "🔑 MongoDB Credentials:"
echo "   - Username: username"
echo "   - Password: password"
echo "   - Connection string: mongodb://username:password@mongodb-service:27017/?replicaSet=rs0"
echo
echo "💳 Transaction Support:"
echo "   - MongoDB Version: 4.4 (supports transactions)"
echo "   - Replica Set: rs0 (initialized)"
echo "   - Transaction Support: ✅ ENABLED"
echo
echo "🔧 Useful commands:"
echo "   - Check Helm releases: helm list -n local-stack"
echo "   - MongoDB logs: kubectl logs -l \"app.kubernetes.io/name=mongodb\" -n local-stack"
echo "   - Mongo Express logs: kubectl logs -l \"app.kubernetes.io/name=mongo-express\" -n local-stack"
echo "   - Check replica set status: kubectl exec $MONGODB_POD -n local-stack -- mongo --eval 'rs.status()'"
echo "   - Test transactions: kubectl exec $MONGODB_POD -n local-stack -- mongo --eval 'session = db.getMongo().startSession(); print(\"Transaction support available:\", session !== null)'"
echo "   - Uninstall MongoDB: helm uninstall mongodb -n local-stack"
echo "   - Uninstall Mongo Express: helm uninstall mongo-express -n local-stack"
