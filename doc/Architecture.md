# Local Stack Architecture

> **Language**: [English](Architecture.md) | [繁體中文](zh_tw/Architecture.md)

## System Overview

The Local Stack is a complete local development environment built on k3d (lightweight Kubernetes) that provides all necessary services for developing and testing the AISecurityService Profile Management API.

```
┌─────────────────────────────────────────────────────────────────┐
│                        k3d Cluster (local-dev)                   │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  mgmt-service   │  │   Mock RIS      │  │   Mock Push     │ │
│  │   (x2 pods)     │  │   Service       │  │   Service       │ │
│  │  Port: 30080    │  │  Port: 30082    │  │  Port: 30083    │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
│           │                    │                     │           │
│           └────────────────┬───┴─────────────────────┘           │
│                            │                                     │
│                   ┌────────▼────────┐                            │
│                   │    MongoDB      │                            │
│                   │  Port: 27017    │                            │
│                   └─────────────────┘                            │
│                            │                                     │
│                   ┌────────▼────────┐                            │
│                   │ Mongo Express   │                            │
│                   │  Port: 30081    │                            │
│                   └─────────────────┘                            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                             │
                ┌────────────▼────────────┐
                │  k3d Local Registry     │
                │  k3d-local-img:5555     │
                └─────────────────────────┘
```

## Components

### 1. k3d Cluster

**Purpose**: Lightweight Kubernetes cluster for local development

**Configuration**:
- Cluster name: `local-dev`
- Kubernetes version: Latest stable
- Local registry: `k3d-local-img:5555`
- Port mappings:
  - 30080:30080 (Management API)
  - 30081:30081 (Mongo Express)
  - 30082:30082 (Mock RIS)
  - 30083:30083 (Mock Push)

**Key Features**:
- Fast startup/shutdown
- Minimal resource usage
- Automatic port forwarding
- Integrated local image registry

### 2. Management Service (aisecurity-mgmt-service)

**Purpose**: AISecurityService Profile Management API

**Configuration**:
- Replicas: 2
- Image: `k3d-local-img:5555/aisecurity-mgmt-service:local-dev`
- Port: 8000 (internal) → 30080 (NodePort)
- Base path: `/aisecurity/api/v1`

**Key Features**:
- Profile CRUD operations
- Health check endpoints
- Integration with MongoDB
- Integration with RIS and Push services

**Environment Variables**:

| Variable                  | Default | Description                                           |
|--------------------------|---------|-------------------------------------------------------|
| PUSH_SCHEDULER_INTERVAL  | 10      | Push scheduler polling interval in seconds (set to 2 for faster E2E testing) |

**Health Check System**:
```python
{
  "overall_status": "ready",  # ready | degraded | unhealthy
  "services": {
    "mongodb": {
      "status": "healthy",
      "latency_ms": 5.2
    },
    "ris_api": {
      "status": "healthy",
      "latency_ms": 3.8
    },
    "pusher_api": {
      "status": "healthy",
      "latency_ms": 2.1
    }
  }
}
```

**API Endpoints**:
- `GET /health/liveness` - Liveness probe
- `GET /health/readiness` - Readiness probe with dependency checks
- `GET /aisecurity/api/v1/profiles` - List profiles
- `POST /aisecurity/api/v1/profiles` - Create profile
- `PUT /aisecurity/api/v1/profiles/{id}` - Update profile
- `DELETE /aisecurity/api/v1/profiles/{id}` - Delete profile

### 3. MongoDB

**Purpose**: Primary database for profile storage

**Configuration**:
- Image: `mongo:latest`
- Port: 27017 (internal)
- Database: `AISecurityMgmtServiceDB`
- Collections:
  - `AISecurityProfiles_Applied`
  - `AISecurityProfiles_Pending`

**Authentication**:
- Credentials stored in `env/host_info.txt`
- Base64 encoded in Kubernetes secrets
- Environment variables: `DB_ACCOUNT`, `DB_CREDENT`

**Connection String**:
```
mongodb://<username>:<password>@mongodb-service:27017/AISecurityMgmtServiceDB
```

### 4. Mongo Express

**Purpose**: Web-based MongoDB administration interface

**Configuration**:
- Image: `mongo-express:latest`
- Port: 8081 (internal) → 30081 (NodePort)
- Access: http://localhost:30081

**Features**:
- Browse collections
- Execute queries
- View/edit documents
- Monitor database status

### 5. Mock RIS Service

**Purpose**: Mock Reference Integrity Service for testing

**Technology**: Python FastAPI

**Configuration**:
- Image: `k3d-local-img:5555/mock-ris:latest`
- Port: 8080 (internal) → 30082 (NodePort)

**API Endpoints**:

| Method | Endpoint                                                | Description              |
|--------|--------------------------------------------------------|--------------------------|
| GET    | `/healthcheck`                                         | Health check             |
| GET    | `/`                                                    | Service info             |
| PUT    | `/internal/v1/objects/aisecurityprofile/{profile_id}` | Create reference         |
| GET    | `/internal/v1/objects/aisecurityprofile/{profile_id}/references` | Check references |
| DELETE | `/internal/v1/objects/aisecurityprofile/{profile_id}` | Delete reference         |
| POST   | `/internal/v1/objects/aisecurityprofile/bulk`         | Bulk operations          |

**Response Format**:
```json
{
  "status": "created",
  "profile_id": "profile-001",
  "timestamp": "2025-10-18T12:34:56Z"
}
```

### 6. Mock Push Service

**Purpose**: Mock Configuration Push Service for testing

**Technology**: Python FastAPI

**Configuration**:
- Image: `k3d-local-img:5555/mock-push:latest`
- Port: 8081 (internal) → 30083 (NodePort)

**API Endpoints**:

| Method | Endpoint                | Description                |
|--------|------------------------|----------------------------|
| GET    | `/healthcheck`         | Health check               |
| GET    | `/`                    | Service info and statistics |
| POST   | `/push`                | Push configuration file     |
| GET    | `/push/status/{id}`    | Get push status            |
| GET    | `/push/history`        | Get push history           |
| DELETE | `/push/clear`          | Clear push history         |

**Push Request**:
```bash
curl -X POST http://localhost:30083/push \
  -F "file=@config.json" \
  -F "tenant_id=tenant-001"
```

**Response Format**:
```json
{
  "status": "success",
  "push_id": "push-12345",
  "message": "Successfully pushed 2 profiles for tenant tenant-001",
  "timestamp": "2025-10-18T12:34:56Z"
}
```

## Data Flow

### Profile Creation Flow

```
┌──────────┐    POST /profiles    ┌──────────────┐
│  Client  │ ───────────────────> │ mgmt-service │
└──────────┘                       └──────┬───────┘
                                          │
                                          │ 1. Validate
                                          ▼
                                   ┌──────────┐
                                   │ MongoDB  │
                                   └──────┬───┘
                                          │ 2. Save to Pending
                                          │
                                          │ 3. Create Reference
                                          ▼
                                   ┌──────────┐
                                   │ Mock RIS │
                                   └──────────┘
```

### Profile Deployment Flow

```
┌──────────────┐   Deploy API    ┌──────────────┐
│ mgmt-service │ ───────────────> │ mgmt-service │
└──────────────┘                  └──────┬───────┘
                                         │
                                         │ 1. Move to Applied
                                         ▼
                                  ┌──────────┐
                                  │ MongoDB  │
                                  └──────┬───┘
                                         │ 2. Push Config
                                         ▼
                                  ┌───────────┐
                                  │ Mock Push │
                                  └───────────┘
```

### Health Check Flow

```
┌──────────┐   GET /health    ┌──────────────┐
│  Client  │ ───────────────> │ mgmt-service │
└──────────┘                  └──────┬───────┘
                                     │
                      ┌──────────────┼──────────────┐
                      │              │              │
                      ▼              ▼              ▼
              ┌──────────┐   ┌──────────┐  ┌───────────┐
              │ MongoDB  │   │ Mock RIS │  │ Mock Push │
              └──────┬───┘   └──────┬───┘  └──────┬────┘
                     │              │             │
                     └──────────────┴─────────────┘
                                    │
                                    ▼
                           ┌─────────────────┐
                           │ Aggregate Status│
                           └────────┬────────┘
                                    │
                                    ▼
                              Response to Client
```

## Security Model

### Secret Management

All sensitive information is externalized to `env/host_info.txt`:

```bash
# env/host_info.txt (NOT in git)
DB_ACCOUNT=<base64_encoded_username>
DB_CREDENT=<base64_encoded_password>
DB_HOST=mongodb-service
DB_PORT=27017
DB_NAME=AISecurityMgmtServiceDB
COLLECTION_APPLIED=AISecurityProfiles_Applied
COLLECTION_PENDING=AISecurityProfiles_Pending
RIS_API_URL=http://mock-ris-service:8080
PUSHER_API_URL=http://mock-push-service:8081
```

### Network Isolation

- All inter-service communication happens within the k3d cluster
- Only NodePort services are exposed to the host machine
- No direct external access to MongoDB

### RBAC (Role-Based Access Control)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aisecurity-mgmt-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: aisecurity-mgmt-pod-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: aisecurity-mgmt-sa
```

## Deployment Architecture

### Image Build and Push Flow

```
┌────────────┐   1. Build    ┌─────────────┐   2. Tag      ┌──────────────────┐
│ Dockerfile │ ────────────> │ Local Image │ ────────────> │ Registry Image   │
└────────────┘               └─────────────┘               │ k3d-local-img:   │
                                                            │ 5555/app:tag     │
                                                            └────────┬─────────┘
                                                                     │ 3. Push
                                                                     ▼
                                                            ┌──────────────────┐
                                                            │ k3d Registry     │
                                                            └────────┬─────────┘
                                                                     │ 4. Pull
                                                                     ▼
                                                            ┌──────────────────┐
                                                            │ k3d Cluster Pods │
                                                            └──────────────────┘
```

### Deployment Process

1. **Build Phase**: `./reload.sh`
   - Copies correct `requirements.txt`
   - Builds Docker image
   - Tags for local registry
   - Pushes to `k3d-local-img:5555`

2. **Deploy Phase**:
   - Deletes existing deployment
   - Applies new Kubernetes manifests
   - Waits for pods to be ready

3. **Verification Phase**:
   - Checks pod status
   - Verifies health endpoints
   - Confirms all dependencies healthy

## Resource Management

### Resource Limits

| Service          | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------------|-------------|-----------|----------------|--------------|
| mgmt-service    | 250m        | 500m      | 256Mi          | 512Mi        |
| Mock RIS        | 50m         | 200m      | 64Mi           | 256Mi        |
| Mock Push       | 50m         | 200m      | 64Mi           | 256Mi        |
| MongoDB         | 200m        | 1000m     | 256Mi          | 1Gi          |
| Mongo Express   | 50m         | 200m      | 64Mi           | 256Mi        |

### Scaling Strategy

- **Management Service**: 2 replicas for high availability
- **Mock Services**: 1 replica (sufficient for local testing)
- **MongoDB**: 1 replica (no replication needed for local dev)

## Monitoring and Observability

### Health Checks

- **Liveness Probe**: Simple ping to verify service is running
- **Readiness Probe**: Comprehensive check including all dependencies

### Logging

All services log to stdout/stderr, accessible via:
```bash
kubectl logs -l app=<service-name>
```

### Metrics

Currently not implemented (future enhancement).

## Next Steps

- See [README.md](README.md) for usage instructions
- See [Troubleshooting.md](Troubleshooting.md) for common issues
- See [繁體中文文檔](zh_tw/Architecture.md) for Traditional Chinese version
