# Mongo Express Helm Chart

This Helm chart deploys Mongo Express (MongoDB web interface) to a Kubernetes cluster.

## Prerequisites

- MongoDB must be deployed first (using the MongoDB Helm chart or manually)
- MongoDB secret `mongodb-secret` must exist

## Installation

```bash
# Install Mongo Express (after MongoDB is deployed)
helm install mongo-express ./mongoDB/helm-chart/mongo-express/

# Or install with custom values
helm install mongo-express ./mongoDB/helm-chart/mongo-express/ --set nodePort.port=30082
```

## Configuration

The following table lists the configurable parameters and their default values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of Mongo Express replicas | `1` |
| `image.repository` | Mongo Express image repository | `mongo-express` |
| `image.tag` | Mongo Express image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `mongodb.host` | MongoDB service hostname | `mongodb-service` |
| `mongodb.secretName` | MongoDB secret name | `mongodb-secret` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8081` |
| `nodePort.enabled` | Enable NodePort service | `true` |
| `nodePort.port` | NodePort port | `30081` |

## Accessing Mongo Express

### External Access (NodePort)
```bash
# Open browser: http://localhost:30081
```

### External Access (port forwarding)
```bash
kubectl port-forward svc/mongo-express-service 8081:8081
# Open browser: http://localhost:8081
```

## Authentication

Mongo Express uses the same credentials as MongoDB:
- Username: `username`
- Password: `password`

## Useful Commands

```bash
# Check status
kubectl get pods -l "app.kubernetes.io/name=mongo-express"
kubectl get svc -l "app.kubernetes.io/name=mongo-express"

# View logs
kubectl logs -l "app.kubernetes.io/name=mongo-express"

# Port forward
kubectl port-forward svc/mongo-express-service 8081:8081

# Helm operations
helm status mongo-express
helm upgrade mongo-express ./mongoDB/helm-chart/mongo-express/
helm uninstall mongo-express
```

## Troubleshooting

1. **Mongo Express won't start**: Ensure MongoDB is running and accessible
2. **Can't access web interface**: Check if NodePort service is created and k3d port forwarding is working
3. **Authentication fails**: Verify MongoDB secret exists and contains correct credentials
