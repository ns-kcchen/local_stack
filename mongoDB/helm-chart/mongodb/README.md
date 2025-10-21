# MongoDB Helm Chart

This Helm chart deploys MongoDB to a Kubernetes cluster.

## Installation

```bash
# Install MongoDB
helm install mongodb ./mongoDB/helm-chart/mongodb/

# Or install with custom values
helm install mongodb ./mongoDB/helm-chart/mongodb/ --set replicaCount=1
```

## Configuration

The following table lists the configurable parameters and their default values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of MongoDB replicas | `1` |
| `image.repository` | MongoDB image repository | `mongo` |
| `image.tag` | MongoDB image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `auth.rootUsername` | MongoDB root username | `username` |
| `auth.rootPassword` | MongoDB root password | `password` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `27017` |

## Accessing MongoDB

### Internal Access (from within cluster)
```bash
# Service name: mongodb-service
# Port: 27017
# Connection string: mongodb://username:password@mongodb-service:27017/
```

### External Access (port forwarding)
```bash
kubectl port-forward svc/mongodb-service 27017:27017
mongosh mongodb://username:password@localhost:27017/
```

## Useful Commands

```bash
# Check status
kubectl get pods -l "app.kubernetes.io/name=mongodb"
kubectl get svc -l "app.kubernetes.io/name=mongodb"

# View logs
kubectl logs -l "app.kubernetes.io/name=mongodb"

# Connect to MongoDB
kubectl exec -it <mongodb-pod-name> -- mongosh

# Helm operations
helm status mongodb
helm upgrade mongodb ./mongoDB/helm-chart/mongodb/
helm uninstall mongodb
```
