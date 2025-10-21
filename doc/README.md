# Local Stack Development Environment

## Overview

The `local_stack` is a complete GitHub-safe local development environment for the AISecurityService Profile Management API. It provides a fully functional k3d-based Kubernetes cluster with all necessary services including MongoDB, Mock RIS, and Mock Push services.

**Key Features:**
- ✅ **GitHub-Safe**: All secrets externalized to `env/host_info.txt` (not in git)
- ✅ **Complete Environment**: k3d cluster with MongoDB, mgmt-service, and Mock Services
- ✅ **Mock Services**: FastAPI-based Mock RIS and Mock Push services for testing
- ✅ **Health Monitoring**: Comprehensive health check system
- ✅ **Easy Setup**: Simple scripts for deployment and cleanup

## Quick Start

### Prerequisites

- Docker Desktop or Rancher Desktop
- k3d installed
- kubectl installed
- Python 3.10+

### 1. Environment Setup

First, create your machine-specific configuration:

```bash
cd env
cp host_info.txt.template host_info.txt
# Edit host_info.txt with your actual values
```

**Important**: The `env/host_info.txt` file is in `.gitignore` and should never be committed to git.

### 2. Create k3d Cluster

```bash
./setup-k3d.sh
```

This creates a k3d cluster with:
- Cluster name: `local-cluster`
- Local image registry: `k3d-local-img:5555`
- Kubernetes namespace: `local-stack`
- Port mappings for services (30080-30083)

### 3. Deploy Services

```bash
# Deploy all services
./setup-service.sh

# Or deploy individual services
./setup-service.sh -mongodb     # Only MongoDB + Mongo Express
./setup-service.sh -mock-ris    # Only Mock RIS
./setup-service.sh -mock-push   # Only Mock Push
```

Available services in the `local-stack` namespace:
- MongoDB with Replica Set (port 27017)
- Mongo Express web UI (http://localhost:30081)
- Mock RIS Service (http://localhost:30082)
- Mock Push Service (http://localhost:30083)

### 4. Deploy Management Service

```bash
./reload.sh
```

This builds and deploys the AISecurityService Profile Management API to the `local-stack` namespace:
- API: http://localhost:30080
- Health Check: http://localhost:30080/health/liveness
- API Docs: http://localhost:30080/docs

## Service Endpoints

| Service                  | Endpoint                                | Port  |
|--------------------------|----------------------------------------|-------|
| Management API           | http://localhost:30080                 | 30080 |
| Management API (Health)  | http://localhost:30080/health/liveness | 30080 |
| Management API (Docs)    | http://localhost:30080/docs            | 30080 |
| Mongo Express (Web UI)   | http://localhost:30081                 | 30081 |
| Mock RIS Service         | http://localhost:30082                 | 30082 |
| Mock Push Service        | http://localhost:30083                 | 30083 |

## Testing

### Run Mock Service Tests

```bash
cd test

# Test Mock RIS Service
python3 test_mock_ris.py

# Test Mock Push Service
python3 test_mock_push.py
```

### Verify Health Status

```bash
curl http://localhost:30080/health/liveness
```

Expected response:
```json
{
  "overall_status": "ready",
  "services": {
    "mongodb": {"status": "healthy"},
    "ris_api": {"status": "healthy"},
    "pusher_api": {"status": "healthy"}
  }
}
```

## Cleanup

### Quick Cleanup - Remove entire k3d Cluster

```bash
./clean-k3d.sh
```

This will prompt you to:
1. Delete the k3d cluster (including all services)
2. Delete the local registry
3. Remove Docker images

### Manual Cleanup - Remove specific services

```bash
# Remove all services in local-stack namespace
kubectl delete namespace local-stack

# Remove only MongoDB and Mock services
cd mongoDB
./cleanup-DB.sh
```

## Directory Structure

```
local_stack/
├── doc/                      # Documentation
│   ├── README.md             # This file (English)
│   ├── Architecture.md       # Architecture documentation
│   ├── Troubleshooting.md    # Troubleshooting guide
│   └── zh_tw/                # Traditional Chinese documentation
├── env/                      # Environment configuration
│   └── host_info.txt.template
├── k3d/                      # k3d cluster internals
│   ├── setup-k3d-cluster.sh  # Internal: Create k3d cluster
│   ├── setup-Services.sh     # Internal: Deploy all services
│   └── cleanup-k3d.sh        # Internal: Remove cluster
├── mongoDB/                  # MongoDB deployment
│   ├── setup-DB.sh           # Deploy MongoDB stack
│   ├── cleanup-DB.sh         # Remove MongoDB stack
│   └── helm-chart/           # Helm charts for MongoDB
├── mock_services/            # Mock services
│   ├── mock_ris/             # Mock RIS Service (FastAPI)
│   └── mock_push/            # Mock Push Service (FastAPI)
├── test/                     # Test scripts
│   ├── test_mock_ris.py      # Mock RIS integration test
│   └── test_mock_push.py     # Mock Push integration test
├── pkg/                      # Management service Kubernetes manifests
│   ├── deployment.yaml       # Deployment configuration
│   ├── service.yaml          # Service configuration
│   └── rbac.yaml             # RBAC configuration
├── namespace.yaml            # local-stack namespace definition
├── setup-k3d.sh              # Setup k3d cluster (wrapper)
├── setup-service.sh          # Deploy all services (wrapper)
├── reload.sh                 # Deploy/Update Management Service
└── clean-k3d.sh              # Remove k3d cluster (wrapper)
```

## Common Commands

### Check Cluster Status

```bash
# Check all resources in local-stack namespace
kubectl get all -n local-stack

# Check specific resources
kubectl get pods -n local-stack
kubectl get services -n local-stack
kubectl get deployments -n local-stack
```

### View Logs

```bash
# Management Service logs
kubectl logs -l app=aisecurity-mgmt-service -n local-stack

# Mock RIS logs
kubectl logs -l app=mock-ris -n local-stack

# Mock Push logs
kubectl logs -l app=mock-push -n local-stack

# MongoDB logs
kubectl logs -l app.kubernetes.io/name=mongodb -n local-stack
```

### Restart Services

```bash
# Restart Management Service
kubectl rollout restart deployment/aisecurity-mgmt-service -n local-stack

# Restart Mock RIS
kubectl rollout restart deployment/mock-ris-deployment -n local-stack

# Restart Mock Push
kubectl rollout restart deployment/mock-push-deployment -n local-stack
```

## Next Steps

- See [Architecture.md](Architecture.md) for system architecture details
- See [Troubleshooting.md](Troubleshooting.md) for common issues and solutions

## Support

For issues or questions:
1. Check [Troubleshooting.md](Troubleshooting.md)
2. Review service logs using `kubectl logs`
3. Verify health checks are passing
4. Check k3d cluster status

## License

This is an internal development tool for the AISecurityService project.
